import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/classification/services/crop_suggestion_service.dart';
import 'package:image_picker/image_picker.dart';

class ClassificationCropScreen extends StatefulWidget {
  final XFile image;

  const ClassificationCropScreen({super.key, required this.image});

  @override
  State<ClassificationCropScreen> createState() =>
      _ClassificationCropScreenState();
}

class _ClassificationCropScreenState extends State<ClassificationCropScreen> {
  final CropSuggestionService _cropService = CropSuggestionService();
  late final Future<CropEditorData> _editorData;
  CropSelection? _selection;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _editorData = _cropService.prepareEditor(widget.image);
  }

  Future<void> _applyCrop(CropEditorData data) async {
    final selection = _selection ?? data.suggestedSelection;
    setState(() => _isSaving = true);
    try {
      final cropped = await _cropService.createCroppedImage(
        source: widget.image,
        selection: selection,
      );
      if (mounted) Navigator.of(context).pop<XFile>(cropped);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              readableErrorMessage(
                error,
                fallback: 'Gagal menyiapkan area scan. Coba ulangi.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atur Area Scan'),
        actions: [
          IconButton(
            tooltip: 'Gunakan saran otomatis',
            icon: const Icon(Icons.auto_fix_high_outlined),
            onPressed:
                _isSaving ? null : () => setState(() => _selection = null),
          ),
        ],
      ),
      body: FutureBuilder<CropEditorData>(
        future: _editorData,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _CropErrorState(
              message: snapshot.hasError
                  ? readableErrorMessage(
                      snapshot.error!,
                      fallback:
                          'Foto tidak dapat disiapkan untuk pengaturan area scan.',
                    )
                  : 'Foto tidak dapat disiapkan untuk pengaturan area scan.',
            );
          }

          final data = snapshot.requireData;
          final selection = _selection ?? data.suggestedSelection;
          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final imageSize = _fittedSize(
                        Size(data.previewWidth.toDouble(),
                            data.previewHeight.toDouble()),
                        constraints.biggest,
                      );
                      return Center(
                        child: SizedBox(
                          width: imageSize.width,
                          height: imageSize.height,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                data.previewJpegBytes,
                                fit: BoxFit.fill,
                                gaplessPlayback: true,
                              ),
                              _CropOverlay(
                                selection: selection,
                                onChanged: (value) {
                                  setState(() => _selection = value);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Saran otomatis memakai warna dan kontras foto. Geser kotak atau tarik sudutnya agar Hoya berada di dalam area scan.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : () => _applyCrop(data),
                        icon: _isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.crop),
                        label: Text(
                          _isSaving ? 'Menyiapkan foto...' : 'Gunakan Area Ini',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Size _fittedSize(Size image, Size bounds) {
    final scale =
        math.min(bounds.width / image.width, bounds.height / image.height);
    return Size(image.width * scale, image.height * scale);
  }
}

class _CropErrorState extends StatelessWidget {
  final String message;

  const _CropErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

enum _CropDragMode { none, move, topLeft, topRight, bottomLeft, bottomRight }

class _CropOverlay extends StatefulWidget {
  final CropSelection selection;
  final ValueChanged<CropSelection> onChanged;

  const _CropOverlay({required this.selection, required this.onChanged});

  @override
  State<_CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<_CropOverlay> {
  static const _handleRadius = 26.0;
  _CropDragMode _dragMode = _CropDragMode.none;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final cropRect = _toRect(widget.selection, size);
        return Semantics(
          label: 'Area scan. Geser kotak atau tarik salah satu sudutnya.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              setState(() {
                _dragMode = _dragModeAt(details.localPosition, cropRect);
              });
            },
            onPanUpdate: (details) {
              if (_dragMode == _CropDragMode.none) return;
              final updated = _updateRect(cropRect, details.delta, size);
              widget.onChanged(_toSelection(updated, size));
            },
            onPanEnd: (_) => setState(() => _dragMode = _CropDragMode.none),
            onPanCancel: () => setState(() => _dragMode = _CropDragMode.none),
            child: CustomPaint(
              painter: _CropOverlayPainter(cropRect),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }

  Rect _toRect(CropSelection selection, Size size) {
    return Rect.fromLTWH(
      selection.left * size.width,
      selection.top * size.height,
      selection.width * size.width,
      selection.height * size.height,
    );
  }

  CropSelection _toSelection(Rect rect, Size size) {
    return CropSelection(
      left: rect.left / size.width,
      top: rect.top / size.height,
      width: rect.width / size.width,
      height: rect.height / size.height,
    );
  }

  _CropDragMode _dragModeAt(Offset point, Rect rect) {
    if ((point - rect.topLeft).distance <= _handleRadius) {
      return _CropDragMode.topLeft;
    }
    if ((point - rect.topRight).distance <= _handleRadius) {
      return _CropDragMode.topRight;
    }
    if ((point - rect.bottomLeft).distance <= _handleRadius) {
      return _CropDragMode.bottomLeft;
    }
    if ((point - rect.bottomRight).distance <= _handleRadius) {
      return _CropDragMode.bottomRight;
    }
    return rect.contains(point) ? _CropDragMode.move : _CropDragMode.none;
  }

  Rect _updateRect(Rect rect, Offset delta, Size size) {
    final minSide = math.min(80.0, size.shortestSide * 0.32);
    switch (_dragMode) {
      case _CropDragMode.move:
        final left = (rect.left + delta.dx)
            .clamp(0.0, size.width - rect.width)
            .toDouble();
        final top = (rect.top + delta.dy)
            .clamp(0.0, size.height - rect.height)
            .toDouble();
        return Rect.fromLTWH(left, top, rect.width, rect.height);
      case _CropDragMode.topLeft:
        return _resizeFromBottomRight(rect, delta, minSide);
      case _CropDragMode.topRight:
        return _resizeFromBottomLeft(rect, delta, minSide, size);
      case _CropDragMode.bottomLeft:
        return _resizeFromTopRight(rect, delta, minSide, size);
      case _CropDragMode.bottomRight:
        return _resizeFromTopLeft(rect, delta, minSide, size);
      case _CropDragMode.none:
        return rect;
    }
  }

  Rect _resizeFromBottomRight(Rect rect, Offset delta, double minSide) {
    final anchor = rect.bottomRight;
    final side = math
        .max(anchor.dx - (rect.left + delta.dx),
            anchor.dy - (rect.top + delta.dy))
        .clamp(minSide, math.min(anchor.dx, anchor.dy))
        .toDouble();
    return Rect.fromLTWH(anchor.dx - side, anchor.dy - side, side, side);
  }

  Rect _resizeFromBottomLeft(
    Rect rect,
    Offset delta,
    double minSide,
    Size size,
  ) {
    final anchor = rect.bottomLeft;
    final side = math
        .max((rect.right + delta.dx) - anchor.dx,
            anchor.dy - (rect.top + delta.dy))
        .clamp(minSide, math.min(size.width - anchor.dx, anchor.dy))
        .toDouble();
    return Rect.fromLTWH(anchor.dx, anchor.dy - side, side, side);
  }

  Rect _resizeFromTopRight(
    Rect rect,
    Offset delta,
    double minSide,
    Size size,
  ) {
    final anchor = rect.topRight;
    final side = math
        .max(anchor.dx - (rect.left + delta.dx),
            (rect.bottom + delta.dy) - anchor.dy)
        .clamp(minSide, math.min(anchor.dx, size.height - anchor.dy))
        .toDouble();
    return Rect.fromLTWH(anchor.dx - side, anchor.dy, side, side);
  }

  Rect _resizeFromTopLeft(
    Rect rect,
    Offset delta,
    double minSide,
    Size size,
  ) {
    final anchor = rect.topLeft;
    final side = math
        .max((rect.right + delta.dx) - anchor.dx,
            (rect.bottom + delta.dy) - anchor.dy)
        .clamp(
            minSide, math.min(size.width - anchor.dx, size.height - anchor.dy))
        .toDouble();
    return Rect.fromLTWH(anchor.dx, anchor.dy, side, side);
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  const _CropOverlayPainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Paint()..color = Colors.black.withValues(alpha: 0.58);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, cropRect.top), shade);
    canvas.drawRect(
      Rect.fromLTWH(
          0, cropRect.bottom, size.width, size.height - cropRect.bottom),
      shade,
    );
    canvas.drawRect(
        Rect.fromLTWH(0, cropRect.top, cropRect.left, cropRect.height), shade);
    canvas.drawRect(
      Rect.fromLTWH(cropRect.right, cropRect.top, size.width - cropRect.right,
          cropRect.height),
      shade,
    );

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRect(cropRect, border);
    final handle = Paint()..color = Colors.white;
    for (final point in [
      cropRect.topLeft,
      cropRect.topRight,
      cropRect.bottomLeft,
      cropRect.bottomRight,
    ]) {
      canvas.drawCircle(point, 7, handle);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}
