# Firebase Seed

Folder ini berisi data awal untuk Batch 3.

## Isi
- `species_seed.json`: seed koleksi `species/{speciesId}`.
- `label_map_hoya_model_v1.json`: seed dokumen `label_map/hoya_model_v1`.
- `seed_firestore.js`: script opsional untuk menulis dua seed di atas ke Firestore.

## Jalankan Import

Dari folder `draft_app`:

```bash
node firebase_seed/seed_firestore.js
```

Script ini membutuhkan credential Firebase Admin, misalnya lewat login/ADC Firebase CLI atau environment variable `GOOGLE_APPLICATION_CREDENTIALS`.

## Catatan Gambar Referensi

File seed sudah menyimpan:
- `referenceImageSourcePath`: lokasi gambar lokal di `../species_reference`.
- `referenceStoragePath`: target upload di Firebase Storage.

Untuk sekaligus upload gambar referensi ke Firebase Storage dan mengisi `referenceImageUrl` di Firestore:

```bash
node firebase_seed/seed_firestore.js --upload-images
```

Pastikan Firebase Storage sudah dibuat/aktif di project sebelum menjalankan opsi `--upload-images`.

Jika bucket Storage berbeda dari default `hoyaid-app.firebasestorage.app`, set environment variable:

```bash
FIREBASE_STORAGE_BUCKET=nama-bucket node firebase_seed/seed_firestore.js --upload-images
```
