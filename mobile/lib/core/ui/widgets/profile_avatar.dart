import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackLetter;
  final double radius;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    required this.fallbackLetter,
    this.radius = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Profile photo',
      child: CircleAvatar(
        radius: radius,
        backgroundColor: context.appColors.brandSoft,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
        onBackgroundImageError: imageUrl != null ? (_, _) {} : null,
        child: imageUrl == null
            ? Text(
                fallbackLetter.toUpperCase(),
                style: TextStyle(
                  fontSize: radius * 0.78,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.brandStrong,
                ),
              )
            : null,
      ),
    );
  }
}
