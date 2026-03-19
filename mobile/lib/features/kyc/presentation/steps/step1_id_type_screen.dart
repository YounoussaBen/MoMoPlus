import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/ui/theme/app_theme.dart';
import '../../../../core/ui/widgets/app_button.dart';
import '../kyc_view_model.dart';
import '../widgets/photo_picker_tile.dart';

class Step1IdTypeScreen extends StatelessWidget {
  const Step1IdTypeScreen({super.key});

  static const _options = [
    ('national_id', 'Ghana Card'),
    ('passport', 'Passport'),
    ('drivers_license', "Driver's License"),
  ];

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KycViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verify your identity',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Select an ID type and upload photos of both sides.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        _IdTypeDropdown(selectedType: vm.idType, options: _options),
        const SizedBox(height: 28),
        Text(
          'Document photos',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        PhotoPickerTile(
          label: 'Front',
          filePath: vm.idFront?.displayPath,
          isUploading: vm.idFront?.uploading ?? false,
          uploadError: vm.idFront?.error,
          onTap: () => context.read<KycViewModel>().pickIdFront(),
        ),
        const SizedBox(height: 12),
        PhotoPickerTile(
          label: 'Back',
          filePath: vm.idBack?.displayPath,
          isUploading: vm.idBack?.uploading ?? false,
          uploadError: vm.idBack?.error,
          onTap: () => context.read<KycViewModel>().pickIdBack(),
        ),
        const Spacer(),
        AppButton(
          label: 'Continue',
          onPressed: vm.canAdvanceStep1
              ? () => context.read<KycViewModel>().nextStep()
              : null,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _IdTypeDropdown extends StatelessWidget {
  final String? selectedType;
  final List<(String, String)> options;

  const _IdTypeDropdown({required this.selectedType, required this.options});

  @override
  Widget build(BuildContext context) {
    final selectedLabel = options
        .firstWhere((o) => o.$1 == selectedType, orElse: () => ('', ''))
        .$2;

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedType != null
                ? AppColors.primary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedLabel.isEmpty ? 'Select ID type' : selectedLabel,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: selectedType != null
                      ? FontWeight.w500
                      : FontWeight.w400,
                  color: selectedType != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: selectedType != null
                  ? AppColors.primary
                  : AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ...options.map(
                (opt) => ListTile(
                  title: Text(
                    opt.$2,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: selectedType == opt.$1
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selectedType == opt.$1
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  trailing: selectedType == opt.$1
                      ? const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    context.read<KycViewModel>().selectIdType(opt.$1);
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
