import 'dart:io';

import 'package:hoyaid/features/benchmark/models/d4_accuracy_evaluation_models.dart';
import 'package:path_provider/path_provider.dart';

class D4AccuracyLogFiles {
  final File predictionsCsv;
  final File summaryJson;

  const D4AccuracyLogFiles({
    required this.predictionsCsv,
    required this.summaryJson,
  });
}

class D4AccuracyLogStorage {
  static const _headers = [
    'sample_id',
    'relative_path',
    'true_index',
    'true_label',
    'predicted_index',
    'predicted_species_id',
    'confidence',
    'top3_indices',
    'top3_species_ids',
    'correct_top1',
    'correct_top3',
    'preprocessing_ms',
    'inference_ms',
    'error',
  ];

  Future<D4AccuracyLogFiles> save(D4AccuracyEvaluationResult result) async {
    final external = await getExternalStorageDirectory();
    final base = external ?? await getApplicationDocumentsDirectory();
    final directory = Directory('${base.path}${Platform.pathSeparator}ihoya_evaluation');
    await directory.create(recursive: true);
    final timestamp = result.finishedAt
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final predictions = File(
      '${directory.path}${Platform.pathSeparator}d4_on_device_predictions_$timestamp.csv',
    );
    final summary = File(
      '${directory.path}${Platform.pathSeparator}d4_on_device_summary_$timestamp.json',
    );
    final csv = <String>[_csvLine(_headers)];
    for (final prediction in result.predictions) {
      final row = prediction.toCsvRow();
      csv.add(_csvLine(_headers.map((header) => row[header] ?? '').toList()));
    }
    await predictions.writeAsString('${csv.join('\n')}\n', flush: true);
    await summary.writeAsString('${result.toPrettyJson()}\n', flush: true);
    return D4AccuracyLogFiles(predictionsCsv: predictions, summaryJson: summary);
  }

  String _csvLine(List<String> values) => values
      .map((value) => '"${value.replaceAll('"', '""')}"')
      .join(',');
}
