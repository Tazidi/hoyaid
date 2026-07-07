import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Hasil dari filter tanaman ML Kit.
class PlantFilterResult {
  /// True jika foto kemungkinan mengandung tanaman / bagian tanaman.
  final bool likelyPlant;

  /// Label teratas dari ML Kit (untuk debugging / logging).
  final List<String> topLabels;

  /// Confidence label tanaman tertinggi yang ditemukan (0.0 jika tidak ada).
  final double plantConfidence;

  const PlantFilterResult({
    required this.likelyPlant,
    required this.topLabels,
    required this.plantConfidence,
  });
}

/// Service yang menggunakan Google ML Kit Image Labeling untuk
/// mendeteksi apakah foto mengandung tanaman sebelum diproses model Hoya.
///
/// Ini adalah gerbang pertama (Stage 1) dalam pipeline klasifikasi.
/// Jika [PlantFilterResult.likelyPlant] = false, foto langsung ditolak
/// tanpa perlu memanggil model TFLite Hoya.
class PlantFilterService {
  /// Label-label yang dikenali ML Kit sebagai tanaman / bagian tanaman.
  /// Semua huruf kecil untuk perbandingan case-insensitive.
  static const _plantKeywords = <String>{
    'plant',
    'flower',
    'leaf',
    'leaves',
    'tree',
    'shrub',
    'herb',
    'vegetation',
    'botany',
    'flora',
    'petal',
    'blossom',
    'foliage',
    'branch',
    'twig',
    'stem',
    'vine',
    'weed',
    'grass',
    'fern',
    'moss',
    'succulent',
    'cactus',
    'orchid',
    'rose',
    'tropical plant',
    'houseplant',
    'garden',
    'natural environment',
  };

  /// Confidence minimum yang diterima ML Kit agar sebuah label dianggap valid.
  static const double _minLabelConfidence = 0.55;

  /// Confidence minimum label tanaman agar foto dianggap "likelyPlant = true".
  static const double _minPlantConfidence = 0.50;

  ImageLabeler? _labeler;

  /// Inisialisasi ML Kit labeler (lazy — hanya dibuat saat pertama digunakan).
  ImageLabeler _getLabeler() {
    _labeler ??= ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: _minLabelConfidence),
    );
    return _labeler!;
  }

  /// Periksa apakah gambar di [imagePath] kemungkinan mengandung tanaman.
  ///
  /// Returns [PlantFilterResult]:
  /// - [PlantFilterResult.likelyPlant] = true → lanjut ke model Hoya
  /// - [PlantFilterResult.likelyPlant] = false → tolak, tampilkan pesan bukan tanaman
  Future<PlantFilterResult> checkIsPlant(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final labeler = _getLabeler();

    final List<ImageLabel> labels;
    try {
      labels = await labeler.processImage(inputImage);
    } catch (_) {
      // Kalau ML Kit gagal (misal platform tidak support), anggap sebagai tanaman
      // agar tidak memblokir alur klasifikasi utama.
      return const PlantFilterResult(
        likelyPlant: true,
        topLabels: ['ML Kit error — skipped'],
        plantConfidence: 0.0,
      );
    }

    // Ambil top 10 label sebagai string untuk debugging
    final topLabels = labels
        .take(10)
        .map((l) => '${l.label} (${(l.confidence * 100).toStringAsFixed(0)}%)')
        .toList();

    // Cari label tanaman dengan confidence tertinggi
    double bestPlantConfidence = 0.0;
    for (final label in labels) {
      final lowerLabel = label.label.toLowerCase();
      final isPlantLabel = _plantKeywords.any(
        (keyword) => lowerLabel.contains(keyword),
      );
      if (isPlantLabel && label.confidence > bestPlantConfidence) {
        bestPlantConfidence = label.confidence;
      }
    }

    return PlantFilterResult(
      likelyPlant: bestPlantConfidence >= _minPlantConfidence,
      topLabels: topLabels,
      plantConfidence: bestPlantConfidence,
    );
  }

  /// Tutup labeler dan bebaskan resource saat tidak lagi digunakan.
  Future<void> dispose() async {
    await _labeler?.close();
    _labeler = null;
  }
}

/// Exception yang dilempar saat foto dideteksi bukan tanaman oleh ML Kit.
class NotAPlantException implements Exception {
  final PlantFilterResult filterResult;

  const NotAPlantException({required this.filterResult});

  @override
  String toString() =>
      'NotAPlantException: foto tidak mengandung tanaman (plantConfidence=${filterResult.plantConfidence.toStringAsFixed(2)})';
}
