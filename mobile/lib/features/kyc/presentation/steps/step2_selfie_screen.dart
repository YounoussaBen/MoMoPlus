import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/ui/widgets/app_button.dart';
import '../kyc_view_model.dart';
import '../widgets/photo_picker_tile.dart';
import 'selfie_camera_screen.dart';

class Step2SelfieScreen extends StatelessWidget {
  const Step2SelfieScreen({super.key});

  Future<void> _openCamera(BuildContext context) async {
    final imageFile = await SelfieCameraScreen.open(context);
    if (!context.mounted || imageFile == null) return;
    await context.read<KycViewModel>().uploadSelfieFile(imageFile);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KycViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Take a selfie',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Look directly at the camera in a well-lit area. Your face must be clearly visible.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        Center(
          child: SizedBox(
            width: 200,
            child: PhotoPickerTile(
              label: 'Take selfie',
              filePath: vm.selfie?.displayPath,
              icon: Icons.camera_alt_outlined,
              isUploading: vm.selfie?.uploading ?? false,
              uploadError: vm.selfie?.error,
              onTap: () => _openCamera(context),
            ),
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Back',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.read<KycViewModel>().prevStep(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: 'Continue',
                onPressed: vm.canAdvanceStep2
                    ? () => context.read<KycViewModel>().nextStep()
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
