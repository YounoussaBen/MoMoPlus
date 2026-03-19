import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/ui/theme/app_theme.dart';
import '../../../../core/ui/widgets/app_button.dart';
import '../kyc_view_model.dart';
import '../widgets/photo_picker_tile.dart';

class Step3AddressScreen extends StatelessWidget {
  const Step3AddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KycViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Proof of address',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Upload a utility bill, bank statement, or government letter dated within the last 3 months.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        PhotoPickerTile(
          label: 'Upload document',
          filePath: vm.proofOfAddress?.displayPath,
          isUploading: vm.proofOfAddress?.uploading ?? false,
          uploadError: vm.proofOfAddress?.error,
          onTap: () => context.read<KycViewModel>().pickProofOfAddress(),
        ),
        if (vm.errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vm.errorMessage!,
                    style: TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.read<KycViewModel>().clearError(),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.error,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Back',
                variant: AppButtonVariant.secondary,
                onPressed: vm.isSubmitting
                    ? null
                    : () => context.read<KycViewModel>().prevStep(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: 'Submit',
                isLoading: vm.isSubmitting,
                onPressed: (vm.canSubmit && !vm.isSubmitting)
                    ? () => context.read<KycViewModel>().submit()
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
