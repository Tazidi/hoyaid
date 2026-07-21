const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

let admin;
try {
  admin = require('firebase-admin');
} catch (_) {
  admin = require('../functions/node_modules/firebase-admin');
}

const projectId =
  process.env.FIREBASE_PROJECT_ID || process.env.GCLOUD_PROJECT || 'hoyaid-app-b2f66';
const storageBucket =
  process.env.FIREBASE_STORAGE_BUCKET || `${projectId}.firebasestorage.app`;

if (!admin.apps.length) {
  admin.initializeApp({ projectId, storageBucket });
}

const db = admin.firestore();
const bucket = admin.storage().bucket();
const uploadImages = process.argv.includes('--upload-images');
const restoreImageUrls = process.argv.includes('--restore-image-urls');

function readJson(fileName) {
  const filePath = path.join(__dirname, fileName);
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function contentTypeFor(filePath) {
  const extension = path.extname(filePath).toLowerCase();
  switch (extension) {
    case '.png':
      return 'image/png';
    case '.webp':
      return 'image/webp';
    case '.jpeg':
    case '.jpg':
    default:
      return 'image/jpeg';
  }
}

function resolveSourcePath(sourcePath) {
  const candidates = [
    path.resolve(process.cwd(), sourcePath),
    path.resolve(__dirname, '..', sourcePath),
  ];

  return candidates.find((candidate) => fs.existsSync(candidate));
}

function downloadUrlFor(storagePath, token) {
  const encodedPath = encodeURIComponent(storagePath);
  return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media&token=${token}`;
}

async function uploadReferenceImages(seed) {
  let uploaded = 0;

  for (const item of seed.items) {
    if (!item.referenceImageSourcePath) continue;

    const sourcePath = resolveSourcePath(item.referenceImageSourcePath);
    if (!sourcePath) {
      console.warn(`Skip image for ${item.speciesId}: source file not found.`);
      continue;
    }

    const storagePath =
      item.referenceStoragePath ||
      `species_images/${item.speciesId}/reference${path.extname(sourcePath)}`;
    const token = crypto.randomUUID();

    await bucket.upload(sourcePath, {
      destination: storagePath,
      metadata: {
        contentType: contentTypeFor(sourcePath),
        metadata: {
          firebaseStorageDownloadTokens: token,
        },
      },
    });

    item.referenceStoragePath = storagePath;
    item.referenceImageUrl = downloadUrlFor(storagePath, token);
    uploaded += 1;
  }

  return uploaded;
}

async function restoreReferenceImageUrls(seed) {
  let restored = 0;
  let missing = 0;

  for (const item of seed.items) {
    if (!item.referenceStoragePath) continue;

    const file = bucket.file(item.referenceStoragePath);
    const [exists] = await file.exists();
    if (!exists) {
      console.warn(`Skip image for ${item.speciesId}: object Storage not found.`);
      missing += 1;
      continue;
    }

    const [metadata] = await file.getMetadata();
    const existingTokens = metadata.metadata?.firebaseStorageDownloadTokens;
    const token = existingTokens?.split(',').map((value) => value.trim()).find(Boolean) || crypto.randomUUID();

    if (!existingTokens) {
      await file.setMetadata({
        metadata: {
          ...(metadata.metadata || {}),
          firebaseStorageDownloadTokens: token,
        },
      });
    }

    item.referenceImageUrl = downloadUrlFor(item.referenceStoragePath, token);
    restored += 1;
  }

  return { restored, missing };
}

async function seedSpecies(batch, seed) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const collectionName = seed.collection || 'species';

  for (const item of seed.items) {
    const ref = db.collection(collectionName).doc(item.speciesId);
    const data = { ...item };

    // A null/empty URL in the local seed must not erase an image already
    // stored in Firestore. `--upload-images` supplies a fresh URL explicitly.
    if (
      typeof data.referenceImageUrl !== 'string' ||
      data.referenceImageUrl.trim().length === 0
    ) {
      delete data.referenceImageUrl;
    }

    batch.set(
      ref,
      {
        ...data,
        updatedAt: now,
        createdAt: now,
      },
      { merge: true },
    );
  }

  return seed.items.length;
}

async function seedLabelMap(batch, seed) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const collectionName = seed.collection || 'label_map';
  const documentId = seed.documentId || seed.modelVersion;
  const { collection, documentId: _documentId, ...data } = seed;

  batch.set(
    db.collection(collectionName).doc(documentId),
    {
      ...data,
      updatedAt: now,
      createdAt: now,
    },
    { merge: true },
  );
}

async function main() {
  if (uploadImages && restoreImageUrls) {
    throw new Error('Use only one image mode: --upload-images or --restore-image-urls.');
  }
  const speciesSeed = readJson('species_seed.json');
  const labelMapSeed = readJson('label_map_hoya_model_v1.json');

  let uploadedImages = 0;
  let restoredImages = 0;
  let missingStorageImages = 0;
  if (uploadImages) {
    uploadedImages = await uploadReferenceImages(speciesSeed);
  } else if (restoreImageUrls) {
    ({ restored: restoredImages, missing: missingStorageImages } =
      await restoreReferenceImageUrls(speciesSeed));
  }

  const batch = db.batch();
  const speciesCount = await seedSpecies(batch, speciesSeed);
  await seedLabelMap(batch, labelMapSeed);
  await batch.commit();

  console.log(`Seed complete for project ${projectId}.`);
  console.log(`- species: ${speciesCount} documents`);
  console.log(`- label_map/${labelMapSeed.documentId}: 1 document`);
  if (uploadImages) {
    console.log(`- reference images uploaded: ${uploadedImages}`);
  }
  if (restoreImageUrls) {
    console.log(`- reference image URLs restored: ${restoredImages}`);
    console.log(`- reference images missing from Storage: ${missingStorageImages}`);
  }
}

main().catch((error) => {
  console.error('Seed failed:', error);
  process.exitCode = 1;
});
