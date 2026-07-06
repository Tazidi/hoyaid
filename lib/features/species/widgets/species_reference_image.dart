import 'package:flutter/material.dart';

class SpeciesReferenceImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const SpeciesReferenceImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget child;
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      child = ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.local_florist_outlined,
            color: colorScheme.onSurfaceVariant,
            size: 36,
          ),
        ),
      );
    } else {
      child = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return ColoredBox(
            color: colorScheme.surfaceContainerHighest,
            child: const Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return ColoredBox(
            color: colorScheme.errorContainer,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: colorScheme.onErrorContainer,
              ),
            ),
          );
        },
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: child,
      ),
    );
  }
}
