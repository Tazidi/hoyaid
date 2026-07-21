# Firebase Seed

Folder ini berisi data awal untuk Batch 3.

## Isi
- `species_seed.json`: seed koleksi `species/{speciesId}`.
- `label_map_hoya_model_v1.json`: seed dokumen `label_map/hoya_model_v1`.
- `seed_firestore.js`: script opsional untuk menulis dua seed di atas ke Firestore.
- `generate_species_seed_from_xlsx.py`: generator seed dari workbook sumber terverifikasi.

## Jalankan Import

Dari folder `draft_app`:

```bash
# Buat/perbarui seed dari workbook sumber terverifikasi.
# Script memvalidasi semua label dan mempertahankan metadata gambar yang ada.
python firebase_seed/generate_species_seed_from_xlsx.py

# Opsional: hanya validasi tanpa menulis.
python firebase_seed/generate_species_seed_from_xlsx.py --dry-run

# Setelah seed diperbarui, tulis data ke Firestore.
node firebase_seed/seed_firestore.js
```

Script ini membutuhkan credential Firebase Admin, misalnya lewat login/ADC Firebase CLI atau environment variable `GOOGLE_APPLICATION_CREDENTIALS`.

## Data dari workbook

Generator membaca worksheet `Data_Aplikasi` pada `../data_spesies_hoya_dengan_sumber_terverifikasi.xlsx`. Field `description`, `distribution`, dan data medis yang telah dikonfirmasi diperbarui pada seed. Kolom bukti, peringatan keamanan, status medis, serta URL dan kode sumber juga disimpan sebagai metadata Firestore untuk setiap spesies. Status `Potensial` tetap disimpan sebagai metadata, tetapi tidak ditampilkan sebagai klaim pemanfaatan medis pada aplikasi.

## Pemulihan URL gambar

Jika seed pernah mengosongkan `referenceImageUrl`, pulihkan URL ke file yang sudah ada di Firebase Storage tanpa mengganti berkas gambarnya:

```bash
node firebase_seed/seed_firestore.js --restore-image-urls
```

Jika log menyatakan ada objek Storage yang hilang, gunakan `--upload-images` sebagai cadangan. Opsi itu mengunggah ulang gambar lokal dan dapat mengganti berkas gambar pada Storage.

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
