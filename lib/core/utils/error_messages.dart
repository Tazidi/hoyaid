import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

String readableErrorMessage(
  Object error, {
  String fallback = 'Terjadi kendala. Coba lagi nanti.',
}) {
  if (error is FirebaseException) {
    return _firebaseErrorMessage(error, fallback: fallback);
  }

  if (error is TimeoutException) {
    return 'Koneksi terlalu lama merespons. Periksa jaringan lalu coba lagi.';
  }

  if (error is StateError) {
    return error.message;
  }

  final raw = error.toString();
  if (_looksLikeNetworkError(raw)) {
    return 'Koneksi bermasalah. Hasil belum tersimpan dan bisa dicoba lagi saat online.';
  }

  return _cleanRawMessage(raw, fallback);
}

bool isLikelyNetworkError(Object error) {
  if (error is FirebaseException) {
    return {
      'unavailable',
      'deadline-exceeded',
      'network-request-failed',
    }.contains(error.code);
  }
  return _looksLikeNetworkError(error.toString());
}

String _firebaseErrorMessage(
  FirebaseException error, {
  required String fallback,
}) {
  switch (error.code) {
    case 'unavailable':
    case 'deadline-exceeded':
    case 'network-request-failed':
      return 'Koneksi bermasalah. Hasil belum tersimpan dan bisa dicoba lagi saat online.';
    case 'resource-exhausted':
      return 'Kuota unggah penuh. Buka riwayat atau minta admin menaikkan batas unggah.';
    case 'permission-denied':
      return 'Akses ditolak. Pastikan akun dan hak akses sudah sesuai.';
    case 'unauthenticated':
      return 'Sesi login berakhir. Silakan masuk lagi.';
    case 'admin-restricted-operation':
      return 'Login sebagai tamu belum aktif. Admin perlu mengaktifkan Anonymous sign-in di Firebase Authentication.';
    case 'failed-precondition':
      return error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'Data belum siap diproses. Coba ulangi beberapa saat lagi.';
    case 'not-found':
      return 'Data yang diminta tidak ditemukan atau sudah dihapus.';
    case 'invalid-argument':
      return error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'Data yang dikirim belum valid.';
    case 'app-check-token-required':
      return 'App Check belum valid. Jalankan aplikasi resmi atau aktifkan debug token pengembangan.';
    default:
      return _cleanRawMessage(error.message ?? error.toString(), fallback);
  }
}

bool _looksLikeNetworkError(String raw) {
  final lower = raw.toLowerCase();
  return lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('timed out') ||
      lower.contains('unavailable');
}

String _cleanRawMessage(String raw, String fallback) {
  final message = raw
      .replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '')
      .replaceFirst(RegExp(r'^\[.*?\]\s*'), '')
      .trim();
  if (message.isEmpty) return fallback;
  if (message.length > 220) {
    return '${message.substring(0, 217)}...';
  }
  return message;
}
