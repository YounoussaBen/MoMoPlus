import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/ui/theme/app_theme.dart';

class PhotoPickerTile extends StatelessWidget {
  final String label;
  final String? filePath;
  final VoidCallback onTap;
  final IconData icon;
  final bool isUploading;
  final String? uploadError;

  const PhotoPickerTile({
    super.key,
    required this.label,
    required this.filePath,
    required this.onTap,
    this.icon = Icons.add_photo_alternate_outlined,
    this.isUploading = false,
    this.uploadError,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: uploadError != null
              ? AppColors.error.withAlpha(15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: uploadError != null
              ? Border.all(color: AppColors.error.withAlpha(80), width: 1.5)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: filePath != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  filePath!.startsWith('http')
                      ? Image.network(filePath!, fit: BoxFit.cover)
                      : Image.file(File(filePath!), fit: BoxFit.cover),
                  if (isUploading)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isUploading)
                    const CircularProgressIndicator(strokeWidth: 2)
                  else
                    Icon(
                      uploadError != null ? Icons.refresh : icon,
                      size: 28,
                      color: uploadError != null
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    isUploading
                        ? 'Uploading…'
                        : uploadError != null
                        ? 'Tap to retry'
                        : label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: uploadError != null
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
