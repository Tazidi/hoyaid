import 'package:flutter/material.dart';

/// Wordmark resmi aplikasi iHoya.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    required this.height,
    this.semanticLabel = 'iHoya',
  });

  final double height;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/iHoya.png',
      height: height,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
    );
  }
}
