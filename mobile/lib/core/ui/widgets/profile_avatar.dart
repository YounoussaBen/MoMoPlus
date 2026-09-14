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
    final normalizedImageUrl = imageUrl?.trim();
    final hasImage =
        normalizedImageUrl != null && normalizedImageUrl.isNotEmpty;

    return Semantics(
      image: true,
      label: 'Profile photo',
      child: CircleAvatar(
        radius: radius,
        backgroundColor: context.appColors.brandSoft,
        child: hasImage
            ? ClipOval(
                child: Image.network(
                  normalizedImageUrl,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallback(context),
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          return child;
                        }
                        return _fallback(context);
                      },
                ),
              )
            : _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Text(
      fallbackLetter.toUpperCase(),
      style: TextStyle(
        fontSize: radius * 0.78,
        fontWeight: FontWeight.w600,
        color: context.appColors.brandStrong,
      ),
    );
  }
}
