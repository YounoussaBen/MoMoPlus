import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool useWhite;

  const AppLogo({super.key, this.size = 80, this.useWhite = false});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      useWhite ? 'assets/logo-white.png' : 'assets/logo.png',
      width: size,
      height: size,
      semanticLabel: 'MoMo Plus',
    );
  }
}
