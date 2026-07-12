import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      isDark ? 'assets/logo-light.png' : 'assets/logo.png',
      width: size,
      height: size,
      semanticLabel: 'MoMo Plus',
    );
  }
}
