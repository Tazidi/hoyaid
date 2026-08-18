import 'package:flutter_test/flutter_test.dart';
import 'package:hoyaid/features/history/models/classification_record.dart';

void main() {
  group('ClassificationRecord display status', () {
    test('shows high confidence at the 75 percent threshold', () {
      final record = _record(confidence: 0.75);

      expect(record.isHighConfidence, isTrue);
      expect(record.displayStatusLabel, 'Keyakinan Tinggi');
    });

    test('shows review requirement below the threshold', () {
      final record = _record(confidence: 0.749);

      expect(record.isHighConfidence, isFalse);
      expect(record.displayStatusLabel, 'Perlu Ditinjau');
    });

    test('expert verification takes precedence over confidence', () {
      final record = _record(
        confidence: 0.40,
        verificationStatus: 'verified',
      );

      expect(record.displayStatusLabel, 'Terverifikasi Ahli');
    });

    test('expert rejection takes precedence over confidence', () {
      final record = _record(
        confidence: 0.95,
        verificationStatus: 'rejected',
      );

      expect(record.displayStatusLabel, 'Ditolak Ahli');
    });
  });
}

ClassificationRecord _record({
  required double confidence,
  String verificationStatus = 'unverified',
}) {
  return ClassificationRecord.fromMap(
    {
      'confidence': confidence,
      'verificationStatus': verificationStatus,
    },
    documentId: 'classification-test',
  );
}
