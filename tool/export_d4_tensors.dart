import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hoyaid/features/classification/services/image_preprocess_service.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln(
      'Usage: dart run tool/export_d4_tensors.dart '
      '<manifest.csv> <images-root> <output.bin> [sample-ids]',
    );
    exitCode = 64;
    return;
  }

  final manifestFile = File(args[0]);
  final imagesRoot = Directory(args[1]);
  final outputFile = File(args[2]);
  final requestedIds = args.length > 3 && args[3].trim().isNotEmpty
      ? args[3].split(',').map((value) => int.parse(value.trim())).toSet()
      : <int>{};

  final lines = await manifestFile.readAsLines();
  if (lines.isEmpty) throw StateError('Manifest kosong.');
  final headers = lines.first.split(',');
  final sampleIndex = headers.indexOf('sample_id');
  final pathIndex = headers.indexOf('relative_path');
  if (sampleIndex < 0 || pathIndex < 0) {
    throw StateError('Manifest wajib memuat sample_id dan relative_path.');
  }

  await outputFile.parent.create(recursive: true);
  final sink = outputFile.openWrite();
  final service = ImagePreprocessService();
  final exported = <Map<String, Object>>[];
  try {
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final columns = line.split(',');
      final sampleId = int.parse(columns[sampleIndex]);
      if (requestedIds.isNotEmpty && !requestedIds.contains(sampleId)) continue;
      final relativePath =
          columns[pathIndex].replaceAll('/', Platform.pathSeparator);
      final imagePath =
          '${imagesRoot.path}${Platform.pathSeparator}$relativePath';
      final input = await service.processEvaluationModelInput(
        imagePath: imagePath,
        modelSize: 224,
        floatInput: true,
      ) as List;
      final values = Float32List(224 * 224 * 3);
      var offset = 0;
      for (final batch in input) {
        for (final row in batch as List) {
          for (final pixel in row as List) {
            for (final channel in pixel as List) {
              values[offset++] = (channel as num).toDouble();
            }
          }
        }
      }
      if (offset != values.length) {
        throw StateError(
            'Ukuran tensor sample $sampleId tidak valid: $offset.');
      }
      sink.add(values.buffer.asUint8List());
      exported.add({
        'sample_id': sampleId,
        'relative_path': columns[pathIndex],
      });
      stdout.writeln('exported $sampleId (${exported.length})');
    }
  } finally {
    await sink.close();
  }

  final metadata = {
    'dtype': 'float32',
    'shape_per_sample': [1, 224, 224, 3],
    'endianness': Endian.host == Endian.little ? 'little' : 'big',
    'samples': exported,
  };
  await File('${outputFile.path}.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(metadata),
  );
  stdout.writeln('done ${exported.length} -> ${outputFile.path}');
}
