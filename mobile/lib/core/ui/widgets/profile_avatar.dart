import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
      onBackgroundImageError: imageUrl != null ? (_, _) {} : null,
      child: imageUrl == null
          ? Text(
              fallbackLetter.toUpperCase(),
              style: TextStyle(
                fontSize: radius * 0.78,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }
}
