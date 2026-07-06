import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/classification/providers/classification_provider.dart';
import 'package:hoyaid/features/classification/services/camera_permission_service.dart';
import 'package:image_picker/image_picker.dart';

class ClassificationCameraScreen extends ConsumerStatefulWidget {
  const ClassificationCameraScreen({super.key});

  @override
  ConsumerState<ClassificationCameraScreen> createState() =>
      _ClassificationCameraScreenState();
}

class _ClassificationCameraScreenState
    extends ConsumerState<ClassificationCameraScreen> {
  final _imagePicker = ImagePicker();
  CameraController? _controller;
  Future<void>? _initializeFuture;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _isTakingPicture = false;
  CameraPermissionResult? _permissionResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prepareCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _prepareCamera() async {
    setState(() {
      _errorMessage = null;
      _permissionResult = null;
    });

    final permission =
        await ref.read(cameraPermissionServiceProvider).requestCamera();
    if (!mounted) return;
    if (permission != CameraPermissionResult.granted) {
      setState(() => _permissionResult = permission);
      return;
    }

    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(
            () => _errorMessage = 'Kamera tidak tersedia di perangkat ini.');
        return;
      }

      _cameras = cameras;
      await _openCamera(_cameraIndex);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = readableErrorMessage(
          error,
          fallback: 'Gagal membuka kamera. Coba lagi atau pilih dari galeri.',
        ),
      );
    }
  }

  Future<void> _openCamera(int index) async {
    final oldController = _controller;
    _controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await oldController?.dispose();

    final future = _controller!.initialize();
    setState(() {
      _cameraIndex = index;
      _initializeFuture = future;
    });
    await future;
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    if (_cameras.length <= 1) return;
    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    await _openCamera(nextIndex);
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    final future = _initializeFuture;
    if (controller == null || future == null || _isTakingPicture) return;

    setState(() => _isTakingPicture = true);
    try {
      await future;
      final image = await controller.takePicture();
      if (mounted) context.pop<XFile>(image);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              readableErrorMessage(
                error,
                fallback: 'Gagal mengambil foto. Coba lagi.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
        maxWidth: 2400,
      );
      if (image != null && mounted) context.pop<XFile>(image);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              readableErrorMessage(
                error,
                fallback: 'Gagal memilih gambar dari galeri.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final future = _initializeFuture;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ambil Foto Hoya'),
        actions: [
          IconButton(
            tooltip: 'Pilih dari galeri',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: _pickFromGallery,
          ),
          if (_cameras.length > 1)
            IconButton(
              tooltip: 'Ganti kamera',
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: _switchCamera,
            ),
        ],
      ),
      body: _permissionResult != null
          ? _PermissionMessage(
              result: _permissionResult!,
              onRetry: _prepareCamera,
              onOpenSettings:
                  ref.read(cameraPermissionServiceProvider).openSettings,
              onPickGallery: _pickFromGallery,
            )
          : _errorMessage != null
              ? _CameraErrorMessage(
                  message: _errorMessage!,
                  onRetry: _prepareCamera,
                  onPickGallery: _pickFromGallery,
                )
              : controller == null || future == null
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<void>(
                      future: future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: Colors.black,
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: controller.value.aspectRatio,
                                  child: CameraPreview(controller),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _RoundCameraButton(
                                        tooltip: 'Galeri',
                                        icon: Icons.photo_library_outlined,
                                        onPressed: _pickFromGallery,
                                      ),
                                      _CaptureButton(
                                        isLoading: _isTakingPicture,
                                        onPressed: _takePicture,
                                      ),
                                      _RoundCameraButton(
                                        tooltip: 'Ganti kamera',
                                        icon: Icons.cameraswitch_outlined,
                                        onPressed: _cameras.length > 1
                                            ? _switchCamera
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
    );
  }
}

class _PermissionMessage extends StatelessWidget {
  final CameraPermissionResult result;
  final VoidCallback onRetry;
  final Future<void> Function() onOpenSettings;
  final VoidCallback onPickGallery;

  const _PermissionMessage({
    required this.result,
    required this.onRetry,
    required this.onOpenSettings,
    required this.onPickGallery,
  });

  @override
  Widget build(BuildContext context) {
    final permanentlyDenied =
        result == CameraPermissionResult.permanentlyDenied;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 56),
            const SizedBox(height: 16),
            Text(
              'Izin kamera diperlukan untuk mengambil foto Hoya.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              permanentlyDenied
                  ? 'Izin sudah ditolak permanen. Buka pengaturan aplikasi untuk mengaktifkannya.'
                  : 'Anda masih bisa mencoba lagi atau memakai gambar dari galeri.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Pengaturan'),
                ),
                TextButton.icon(
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeri'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraErrorMessage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onPickGallery;

  const _CameraErrorMessage({
    required this.message,
    required this.onRetry,
    required this.onPickGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
                OutlinedButton.icon(
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeri'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _CaptureButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 72,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        child: isLoading
            ? const SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : const Icon(Icons.camera_alt, size: 32),
      ),
    );
  }
}

class _RoundCameraButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _RoundCameraButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}
