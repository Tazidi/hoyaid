const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const serverTimestamp = admin.firestore.FieldValue.serverTimestamp;
const increment = admin.firestore.FieldValue.increment;
const appCheckedCallableOptions = { enforceAppCheck: true };
const pendingClassificationTtlHours = 6;
const orphanCleanupBatchLimit = 200;

function appCheckedCallable(functionName, handler) {
  return functions
    .runWith(appCheckedCallableOptions)
    .https.onCall(async (data, context) => {
      assertAppCheck(context, functionName);
      return handler(data, context);
    });
}

function storageBucket() {
  return admin.storage().bucket();
}

exports.onUserCreated = functions.auth.user().onCreate(async (user) => {
  try {
    const config = await readGeneralConfig();
    const userRef = db.collection('users').doc(user.uid);

    const name = user.displayName || 'Pengguna HoyaID';
    const userData = {
      uid: user.uid,
      name,
      displayName: name,
      email: user.email || '',
      photoUrl: user.photoURL || null,
      role: 'user',
      authProvider: providerFromUser(user),
      uploadLimit: config.defaultUploadLimit,
      uploadUsed: 0,
      trusted: false,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      lastLoginAt: serverTimestamp(),
      isActive: true,
    };

    await userRef.set(userData, { merge: true });
    await db.collection('stats').doc('global').set(
      {
        totalUsers: increment(1),
        activeUsers: increment(1),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
    functions.logger.info(`Created user document for UID: ${user.uid}`);
  } catch (error) {
    functions.logger.error(
      `Error creating user document for UID: ${user.uid}`,
      error,
    );
  }
});

exports.createClassification = appCheckedCallable(
  'createClassification',
  async (data, context) => {
    const uid = assertSignedNonGuest(context);

    const payload = normalizeCreatePayload(data);
    const userRef = db.collection('users').doc(uid);
    const classificationRef = db.collection('classifications').doc();
    const classificationId = classificationRef.id;
    const imageStoragePath =
      `classification_images/${uid}/${classificationId}/display_640.jpg`;

    const config = await readGeneralConfig();
    const speciesSnap =
      await db.collection('species').doc(payload.speciesId).get();
    const isRare = speciesSnap.exists && speciesSnap.data().isRare === true;
    const precision = isRare
      ? config.rareCoordPrecision
      : config.publicCoordPrecision;
    const publicLocation = toPublicLocation(payload.location, precision);
    const now = new Date();

    await db.runTransaction(async (transaction) => {
      const userSnap = await transaction.get(userRef);
      if (!userSnap.exists) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Profil pengguna belum tersedia.',
        );
      }

      const userData = userSnap.data();
      const uploadUsed = Number(userData.uploadUsed || 0);
      const uploadLimit =
        Number(userData.uploadLimit || config.defaultUploadLimit);
      if (uploadUsed >= uploadLimit) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'Kuota unggah sudah penuh.',
        );
      }

      transaction.set(classificationRef, {
        classificationId,
        userId: uid,
        speciesId: payload.speciesId,
        modelPredictedSpeciesId: payload.modelPredictedSpeciesId,
        correctedSpeciesId: null,
        confidence: payload.confidence,
        confidenceBucket: confidenceBucket(payload.confidence),
        oodScore: payload.oodScore,
        topPredictions: payload.topPredictions,
        imageUrl: null,
        imageStoragePath,
        status: 'pending',
        verificationStatus: 'unverified',
        hasLocation: Boolean(payload.location),
        locationSource: payload.location ? payload.location.source : null,
        latitudePublic: publicLocation ? publicLocation.latitude : null,
        longitudePublic: publicLocation ? publicLocation.longitude : null,
        geoPoint: publicLocation
          ? new admin.firestore.GeoPoint(
            publicLocation.latitude,
            publicLocation.longitude,
          )
          : null,
        locationAccuracy: payload.location ? payload.location.accuracy : null,
        modelVersion: payload.modelVersion,
        imageSizeForModel: payload.imageSizeForModel,
        imageSizeForDisplay: payload.imageSizeForDisplay,
        dateBucket: dateBucket(now),
        correctedBy: null,
        correctedAt: null,
        verifiedBy: null,
        verifiedAt: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });

      if (payload.location) {
        transaction.set(
          classificationRef.collection('private').doc('location'),
          {
            latitude: payload.location.latitude,
            longitude: payload.location.longitude,
            geoPoint: new admin.firestore.GeoPoint(
              payload.location.latitude,
              payload.location.longitude,
            ),
            accuracy: payload.location.accuracy,
            source: payload.location.source,
            createdAt: serverTimestamp(),
            updatedAt: serverTimestamp(),
          },
        );
      }
    });

    return { classificationId, imageStoragePath };
  },
);

exports.finalizeClassification = appCheckedCallable(
  'finalizeClassification',
  async (data, context) => {
    const uid = assertSignedNonGuest(context);
    const classificationId = readString(data, 'classificationId', true);

    const classificationRef =
      db.collection('classifications').doc(classificationId);
    const classificationSnap = await classificationRef.get();
    if (!classificationSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Dokumen klasifikasi tidak ditemukan.',
      );
    }

    const classificationData = classificationSnap.data();
    if (classificationData.userId !== uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Anda tidak memiliki klasifikasi ini.',
      );
    }

    const imageStoragePath = classificationData.imageStoragePath;
    const bucket = storageBucket();
    const file = bucket.file(imageStoragePath);
    const [exists] = await file.exists();
    if (!exists) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Gambar belum terunggah.',
      );
    }

    const imageUrl =
      `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
      `${encodeURIComponent(imageStoragePath)}?alt=media`;
    const userRef = db.collection('users').doc(uid);
    const statsRef = db.collection('stats').doc('global');
    let response = { classificationId, imageStoragePath, imageUrl };

    await db.runTransaction(async (transaction) => {
      const freshSnap = await transaction.get(classificationRef);
      if (!freshSnap.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Dokumen klasifikasi tidak ditemukan.',
        );
      }

      const freshData = freshSnap.data();
      if (freshData.userId !== uid) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Anda tidak memiliki klasifikasi ini.',
        );
      }

      if (freshData.status === 'active') {
        response = {
          classificationId,
          imageStoragePath,
          imageUrl: freshData.imageUrl || imageUrl,
        };
        return;
      }

      if (freshData.status !== 'pending') {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Status klasifikasi tidak dapat difinalisasi.',
        );
      }

      transaction.update(classificationRef, {
        status: 'active',
        imageUrl,
        updatedAt: serverTimestamp(),
      });
      transaction.update(userRef, {
        uploadUsed: increment(1),
        updatedAt: serverTimestamp(),
      });
      transaction.set(
        statsRef,
        {
          activeClassifications: increment(1),
          unverifiedClassifications: increment(1),
          lowConfidenceClassifications:
            freshData.confidenceBucket === 'low' ? increment(1) : increment(0),
          pendingFinalized: increment(1),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
    });

    return response;
  },
);

exports.correctClassificationLabel = appCheckedCallable(
  'correctClassificationLabel',
  async (data, context) => {
    const uid = assertSignedNonGuest(context);
    const classificationId = readString(data, 'classificationId', true);
    const speciesId = readString(data, 'speciesId', true);

    const classificationRef =
      db.collection('classifications').doc(classificationId);
    const speciesSnap = await db.collection('species').doc(speciesId).get();
    const isAdmin = await isAdminUid(uid);
    if (!speciesSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Spesies koreksi tidak ditemukan.',
      );
    }

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(classificationRef);
      if (!snapshot.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Klasifikasi tidak ditemukan.',
        );
      }

      const record = snapshot.data();
      if (!isAdmin && record.userId !== uid) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Anda tidak memiliki izin mengoreksi data ini.',
        );
      }
      if (record.status !== 'active') {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Hanya klasifikasi aktif yang dapat dikoreksi.',
        );
      }

      const beforeStatus = record.verificationStatus || 'unverified';
      transaction.update(classificationRef, {
        speciesId,
        correctedSpeciesId: speciesId,
        verificationStatus: 'unverified',
        correctedBy: uid,
        correctedAt: serverTimestamp(),
        verifiedBy: null,
        verifiedAt: null,
        updatedAt: serverTimestamp(),
      });
      updateVerificationCounters(transaction, beforeStatus, 'unverified');
    });

    return { classificationId, speciesId };
  },
);

exports.archiveAndDeleteClassification = appCheckedCallable(
  'archiveAndDeleteClassification',
  async (data, context) => {
    const uid = assertSignedNonGuest(context);
    const classificationId = readString(data, 'classificationId', true);
    const reason = readString(data, 'reason', false);

    const classificationRef =
      db.collection('classifications').doc(classificationId);
    const classificationSnap = await classificationRef.get();
    if (!classificationSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Klasifikasi tidak ditemukan.',
      );
    }

    const record = classificationSnap.data();
    const isAdmin = await isAdminUid(uid);
    if (!isAdmin && record.userId !== uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Anda tidak memiliki izin menghapus data ini.',
      );
    }
    if (record.status !== 'active') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Hanya klasifikasi aktif yang dapat diarsipkan.',
      );
    }

    const privateLocationSnap = await classificationRef
      .collection('private')
      .doc('location')
      .get();
    const privateLocation = privateLocationSnap.exists
      ? privateLocationSnap.data()
      : null;
    const imageStoragePath = record.imageStoragePath || null;
    let imageDeleted = false;

    if (imageStoragePath) {
      try {
        await storageBucket()
          .file(imageStoragePath)
          .delete({ ignoreNotFound: true });
        imageDeleted = true;
      } catch (error) {
        functions.logger.error('Failed deleting classification image.', {
          classificationId,
          imageStoragePath,
          error: error.message,
        });
        throw new functions.https.HttpsError(
          'internal',
          'Gagal menghapus gambar klasifikasi.',
        );
      }
    }

    await db.runTransaction(async (transaction) => {
      const freshSnap = await transaction.get(classificationRef);
      if (!freshSnap.exists) return;
      const fresh = freshSnap.data();
      const archiveRef =
        db.collection('classification_archives').doc(classificationId);
      const userRef = db.collection('users').doc(fresh.userId);
      const statsRef = db.collection('stats').doc('global');

      transaction.set(archiveRef, {
        archiveId: classificationId,
        originalClassificationId: classificationId,
        userId: fresh.userId,
        speciesId: fresh.speciesId || null,
        modelPredictedSpeciesId: fresh.modelPredictedSpeciesId || null,
        correctedSpeciesId: fresh.correctedSpeciesId || null,
        confidence: fresh.confidence || 0,
        topPredictions: fresh.topPredictions || [],
        verificationStatus: fresh.verificationStatus || 'unverified',
        hasLocation: fresh.hasLocation === true,
        latitude: privateLocation ? privateLocation.latitude : null,
        longitude: privateLocation ? privateLocation.longitude : null,
        geoPoint: privateLocation ? privateLocation.geoPoint : null,
        locationAccuracy: privateLocation ? privateLocation.accuracy : null,
        latitudePublic: fresh.latitudePublic || null,
        longitudePublic: fresh.longitudePublic || null,
        modelVersion: fresh.modelVersion || null,
        originalCreatedAt: fresh.createdAt || null,
        archivedAt: serverTimestamp(),
        deletedBy: uid,
        deleteReason: reason || null,
        imageDeleted,
        imageStoragePath,
      });

      transaction.delete(classificationRef.collection('private').doc('location'));
      transaction.delete(classificationRef);
      transaction.update(userRef, {
        uploadUsed: increment(-1),
        updatedAt: serverTimestamp(),
      });
      transaction.set(
        statsRef,
        {
          activeClassifications: increment(-1),
          archivedClassifications: increment(1),
          lowConfidenceClassifications:
            fresh.confidenceBucket === 'low' ? increment(-1) : increment(0),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
      updateVerificationCounters(
        transaction,
        fresh.verificationStatus || 'unverified',
        null,
      );
    });

    await clampUploadUsed(record.userId);
    return { classificationId, archived: true };
  },
);

exports.updateUserUploadLimit = appCheckedCallable(
  'updateUserUploadLimit',
  async (data, context) => {
    const adminUid = assertSignedNonGuest(context);
    await assertAdmin(adminUid);
    const uid = readString(data, 'uid', true);
    const uploadLimit = readInteger(data, 'uploadLimit', true);
    const trusted = Boolean(data.trusted);

    if (uploadLimit < 0 || uploadLimit > 10000) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Upload limit tidak valid.',
      );
    }

    await db.collection('users').doc(uid).update({
      uploadLimit,
      trusted,
      updatedAt: serverTimestamp(),
    });

    return { uid, uploadLimit, trusted };
  },
);

exports.recalculateUserUploadUsed = appCheckedCallable(
  'recalculateUserUploadUsed',
  async (data, context) => {
    const adminUid = assertSignedNonGuest(context);
    await assertAdmin(adminUid);
    const uid = readString(data, 'uid', true);
    const uploadUsed = await countActiveClassificationsForUser(uid);

    await db.collection('users').doc(uid).update({
      uploadUsed,
      updatedAt: serverTimestamp(),
    });

    return { uid, uploadUsed };
  },
);

exports.setVerificationStatus = appCheckedCallable(
  'setVerificationStatus',
  async (data, context) => {
    const adminUid = assertSignedNonGuest(context);
    await assertAdmin(adminUid);
    const classificationId = readString(data, 'classificationId', true);
    const status = readString(data, 'status', true);
    if (!['unverified', 'verified', 'rejected'].includes(status)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Status verifikasi tidak valid.',
      );
    }

    const classificationRef =
      db.collection('classifications').doc(classificationId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(classificationRef);
      if (!snapshot.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Klasifikasi tidak ditemukan.',
        );
      }

      const record = snapshot.data();
      const beforeStatus = record.verificationStatus || 'unverified';
      transaction.update(classificationRef, {
        verificationStatus: status,
        verifiedBy: status === 'unverified' ? null : adminUid,
        verifiedAt: status === 'unverified' ? null : serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      updateVerificationCounters(transaction, beforeStatus, status);
    });

    return { classificationId, status };
  },
);

exports.exportDataset = appCheckedCallable(
  'exportDataset',
  async (data, context) => {
    const adminUid = assertSignedNonGuest(context);
    await assertAdmin(adminUid);
    const verifiedOnly = data.verifiedOnly !== false;

    let query = db
      .collection('classifications')
      .where('status', '==', 'active')
      .orderBy('createdAt', 'desc')
      .limit(1000);
    if (verifiedOnly) {
      query = db
        .collection('classifications')
        .where('status', '==', 'active')
        .where('verificationStatus', '==', 'verified')
        .orderBy('createdAt', 'desc')
        .limit(1000);
    }

    const snapshot = await query.get();
    const rows = snapshot.docs.map((doc) => {
      const item = doc.data();
      const label = item.correctedSpeciesId || item.speciesId;
      return {
        classificationId: doc.id,
        imageStoragePath: item.imageStoragePath || null,
        imageUrl: item.imageUrl || null,
        label,
        speciesId: item.speciesId || null,
        modelPredictedSpeciesId: item.modelPredictedSpeciesId || null,
        correctedSpeciesId: item.correctedSpeciesId || null,
        confidence: item.confidence || 0,
        confidenceBucket: item.confidenceBucket || null,
        verificationStatus: item.verificationStatus || null,
        modelVersion: item.modelVersion || null,
        dateBucket: item.dateBucket || null,
        hasLocation: item.hasLocation === true,
        latitudePublic: item.latitudePublic || null,
        longitudePublic: item.longitudePublic || null,
        createdAt: timestampToIso(item.createdAt),
      };
    });

    const generatedAt = new Date();
    const storagePath =
      `dataset_exports/${generatedAt.toISOString().replace(/[:.]/g, '-')}` +
      `${verifiedOnly ? '_verified' : '_active'}.json`;
    const manifest = {
      generatedAt: generatedAt.toISOString(),
      generatedBy: adminUid,
      verifiedOnly,
      rowCount: rows.length,
      rows,
    };

    const bucket = storageBucket();
    const file = bucket.file(storagePath);
    await file.save(JSON.stringify(manifest, null, 2), {
      metadata: {
        contentType: 'application/json',
        cacheControl: 'private, max-age=0',
      },
    });

    return {
      storagePath,
      rowCount: rows.length,
      generatedAt: generatedAt.toISOString(),
      downloadUrl:
        `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
        `${encodeURIComponent(storagePath)}?alt=media`,
    };
  },
);

exports.recalculateGlobalStats = appCheckedCallable(
  'recalculateGlobalStats',
  async (data, context) => {
    const adminUid = assertSignedNonGuest(context);
    await assertAdmin(adminUid);
    const stats = await calculateGlobalStats();
    await db.collection('stats').doc('global').set(
      {
        ...stats,
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
    return stats;
  },
);

exports.cleanupOrphans = functions.pubsub
  .schedule('every 6 hours')
  .timeZone('Asia/Jakarta')
  .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - pendingClassificationTtlHours * 60 * 60 * 1000,
    );
    const snapshot = await db
      .collection('classifications')
      .where('status', '==', 'pending')
      .where('createdAt', '<', cutoff)
      .limit(orphanCleanupBatchLimit)
      .get();

    if (snapshot.empty) {
      await db.collection('stats').doc('global').set(
        {
          cleanupOrphansLastRunAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
      functions.logger.info('cleanupOrphans finished with no pending docs.');
      return {
        scanned: 0,
        cleanedDocs: 0,
        imageDeleteFailures: 0,
      };
    }

    const bucket = storageBucket();
    const batch = db.batch();
    let cleanedDocs = 0;
    let deletedImages = 0;
    let imageDeleteFailures = 0;

    for (const doc of snapshot.docs) {
      const record = doc.data();
      const imageStoragePath = record.imageStoragePath || null;
      let canDeleteMetadata = true;

      if (imageStoragePath) {
        try {
          await bucket
            .file(imageStoragePath)
            .delete({ ignoreNotFound: true });
          deletedImages += 1;
        } catch (error) {
          canDeleteMetadata = false;
          imageDeleteFailures += 1;
          functions.logger.warn('cleanupOrphans failed deleting image.', {
            classificationId: doc.id,
            imageStoragePath,
            error: error.message,
          });
        }
      }

      if (!canDeleteMetadata) continue;
      batch.delete(doc.ref.collection('private').doc('location'));
      batch.delete(doc.ref);
      cleanedDocs += 1;
    }

    batch.set(
      db.collection('stats').doc('global'),
      {
        orphanPendingClassificationsCleaned: increment(cleanedDocs),
        orphanImagesDeleted: increment(deletedImages),
        orphanImageDeleteFailures: increment(imageDeleteFailures),
        cleanupOrphansLastRunAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );
    await batch.commit();

    functions.logger.info('cleanupOrphans finished.', {
      scanned: snapshot.size,
      cleanedDocs,
      deletedImages,
      imageDeleteFailures,
    });
    return {
      scanned: snapshot.size,
      cleanedDocs,
      deletedImages,
      imageDeleteFailures,
    };
  });

async function readGeneralConfig() {
  const fallback = {
    defaultUploadLimit: 5,
    publicCoordPrecision: 2,
    rareCoordPrecision: 1,
  };

  try {
    const snapshot = await db.collection('app_config').doc('general').get();
    if (!snapshot.exists) return fallback;
    const data = snapshot.data();
    return {
      defaultUploadLimit:
        Number(data.defaultUploadLimit || fallback.defaultUploadLimit),
      publicCoordPrecision:
        Number(data.publicCoordPrecision ?? fallback.publicCoordPrecision),
      rareCoordPrecision:
        Number(data.rareCoordPrecision ?? fallback.rareCoordPrecision),
    };
  } catch (error) {
    functions.logger.warn('Using fallback config because app_config failed.', {
      error: error.message,
    });
    return fallback;
  }
}

function providerFromUser(user) {
  const providers = user.providerData || [];
  if (providers.some((provider) => provider.providerId === 'google.com')) {
    return 'google';
  }
  if (providers.some((provider) => provider.providerId === 'password')) {
    return 'email';
  }
  return 'email';
}

function assertAppCheck(context, functionName) {
  if (process.env.FUNCTIONS_EMULATOR === 'true') return;
  if (context.app) return;

  functions.logger.warn(`${functionName} rejected without App Check context.`);
  throw new functions.https.HttpsError(
    'failed-precondition',
    'Permintaan ditolak karena App Check tidak valid.',
  );
}

function assertSignedNonGuest(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Login diperlukan.',
    );
  }

  const provider = context.auth.token.firebase
    ? context.auth.token.firebase.sign_in_provider
    : null;
  if (provider === 'anonymous') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Mode tamu tidak dapat menyimpan klasifikasi.',
    );
  }

  return context.auth.uid;
}

async function isAdminUid(uid) {
  if (!uid) return false;
  const snapshot = await db.collection('users').doc(uid).get();
  return snapshot.exists && snapshot.data().role === 'admin';
}

async function assertAdmin(uid) {
  if (await isAdminUid(uid)) return;
  throw new functions.https.HttpsError(
    'permission-denied',
    'Akses admin diperlukan.',
  );
}

function updateVerificationCounters(transaction, beforeStatus, afterStatus) {
  if (beforeStatus === afterStatus) return;
  const statsRef = db.collection('stats').doc('global');
  const updates = { updatedAt: serverTimestamp() };

  const beforeField = verificationCounterField(beforeStatus);
  const afterField = verificationCounterField(afterStatus);
  if (beforeField) updates[beforeField] = increment(-1);
  if (afterField) updates[afterField] = increment(1);

  transaction.set(statsRef, updates, { merge: true });
}

function verificationCounterField(status) {
  switch (status) {
    case 'unverified':
      return 'unverifiedClassifications';
    case 'verified':
      return 'verifiedClassifications';
    case 'rejected':
      return 'rejectedClassifications';
    default:
      return null;
  }
}

async function countActiveClassificationsForUser(uid) {
  const snapshot = await db
    .collection('classifications')
    .where('userId', '==', uid)
    .where('status', '==', 'active')
    .count()
    .get();
  return snapshot.data().count;
}

async function clampUploadUsed(uid) {
  const userRef = db.collection('users').doc(uid);
  const snapshot = await userRef.get();
  if (!snapshot.exists) return;
  const uploadUsed = Number(snapshot.data().uploadUsed || 0);
  if (uploadUsed >= 0) return;
  await userRef.update({
    uploadUsed: 0,
    updatedAt: serverTimestamp(),
  });
}

async function calculateGlobalStats() {
  const [
    usersTotal,
    usersActive,
    activeClassifications,
    archives,
    species,
    unverified,
    verified,
    rejected,
    lowConfidence,
  ] = await Promise.all([
    countQuery(db.collection('users')),
    countQuery(db.collection('users').where('isActive', '==', true)),
    countQuery(db.collection('classifications').where('status', '==', 'active')),
    countQuery(db.collection('classification_archives')),
    countQuery(db.collection('species').where('isActive', '==', true)),
    countQuery(
      db
        .collection('classifications')
        .where('status', '==', 'active')
        .where('verificationStatus', '==', 'unverified'),
    ),
    countQuery(
      db
        .collection('classifications')
        .where('status', '==', 'active')
        .where('verificationStatus', '==', 'verified'),
    ),
    countQuery(
      db
        .collection('classifications')
        .where('status', '==', 'active')
        .where('verificationStatus', '==', 'rejected'),
    ),
    countQuery(
      db
        .collection('classifications')
        .where('status', '==', 'active')
        .where('confidenceBucket', '==', 'low'),
    ),
  ]);

  return {
    totalUsers: usersTotal,
    activeUsers: usersActive,
    activeClassifications,
    archivedClassifications: archives,
    speciesCount: species,
    unverifiedClassifications: unverified,
    verifiedClassifications: verified,
    rejectedClassifications: rejected,
    lowConfidenceClassifications: lowConfidence,
  };
}

async function countQuery(query) {
  const snapshot = await query.count().get();
  return snapshot.data().count;
}

function timestampToIso(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return null;
}

function normalizeCreatePayload(data) {
  const speciesId = readString(data, 'speciesId', true);
  const modelPredictedSpeciesId =
    readString(data, 'modelPredictedSpeciesId', false) || speciesId;
  const confidence = readNumber(data, 'confidence', true);
  const oodScore = readNumber(data, 'oodScore', false);
  const modelVersion = readString(data, 'modelVersion', true);
  const imageSizeForModel =
    readString(data, 'imageSizeForModel', false) || '224x224';
  const imageSizeForDisplay =
    readString(data, 'imageSizeForDisplay', false) || '640x640';
  const topPredictions = normalizeTopPredictions(data.topPredictions);
  const location = normalizeLocation(data.location);

  if (confidence < 0 || confidence > 1) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Confidence harus berada di rentang 0..1.',
    );
  }

  return {
    speciesId,
    modelPredictedSpeciesId,
    confidence,
    oodScore,
    modelVersion,
    imageSizeForModel,
    imageSizeForDisplay,
    topPredictions,
    location,
  };
}

function normalizeTopPredictions(value) {
  if (!Array.isArray(value) || value.length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'topPredictions wajib berisi minimal satu prediksi.',
    );
  }

  return value.slice(0, 5).map((item, index) => {
    const speciesId = readString(item, 'speciesId', true);
    const confidence = readNumber(item, 'confidence', true);
    const labelIndex = Number(item.labelIndex ?? index);
    if (confidence < 0 || confidence > 1) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Confidence topPredictions harus berada di rentang 0..1.',
      );
    }
    return { labelIndex, speciesId, confidence };
  });
}

function normalizeLocation(value) {
  if (!value) return null;

  const latitude = readNumber(value, 'latitude', true);
  const longitude = readNumber(value, 'longitude', true);
  const accuracy = readNumber(value, 'accuracy', false);
  const source = readString(value, 'source', false) || 'gps';

  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Koordinat lokasi tidak valid.',
    );
  }
  if (!['gps', 'manual'].includes(source)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Sumber lokasi tidak valid.',
    );
  }

  return {
    latitude,
    longitude,
    accuracy,
    source,
  };
}

function toPublicLocation(location, precision) {
  if (!location) return null;
  return {
    latitude: roundCoord(location.latitude, precision),
    longitude: roundCoord(location.longitude, precision),
  };
}

function roundCoord(value, precision) {
  const factor = Math.pow(10, precision);
  return Math.round(value * factor) / factor;
}

function confidenceBucket(confidence) {
  if (confidence >= 0.80) return 'high';
  if (confidence >= 0.60) return 'medium';
  return 'low';
}

function dateBucket(date) {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  return `${year}-${month}`;
}

function readString(source, key, required) {
  const value = source ? source[key] : null;
  if (typeof value === 'string' && value.trim().length > 0) {
    return value.trim();
  }
  if (required) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${key} wajib diisi.`,
    );
  }
  return null;
}

function readNumber(source, key, required) {
  const value = source ? source[key] : null;
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (required) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${key} wajib berupa angka.`,
    );
  }
  return null;
}

function readInteger(source, key, required) {
  const value = source ? source[key] : null;
  if (typeof value === 'number' && Number.isInteger(value)) {
    return value;
  }
  if (typeof value === 'string' && /^-?\d+$/.test(value)) {
    return Number(value);
  }
  if (required) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${key} wajib berupa bilangan bulat.`,
    );
  }
  return null;
}
