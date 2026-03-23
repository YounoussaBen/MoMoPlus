import 'package:flutter/material.dart';

/// Returns the asset path for a given network code.
String networkLogoAsset(String network) => switch (network) {
  'mtn' => 'assets/images/MTN.jpeg',
  'vodafone' => 'assets/images/telecel.png',
  'airteltigo' => 'assets/images/airteltigo.png',
  _ => 'assets/images/MTN.jpeg',
};

/// A small, flat network logo image widget.
class NetworkLogo extends StatelessWidget {
  final String network;
  final double size;

  const NetworkLogo({super.key, required this.network, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(
        networkLogoAsset(network),
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
