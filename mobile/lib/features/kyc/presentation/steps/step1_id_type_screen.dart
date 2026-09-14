import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/theme/app_spacing.dart';
import '../../../../core/ui/theme/app_theme_extension.dart';
import '../../../../core/ui/widgets/app_button.dart';
import '../../../../core/ui/widgets/app_text_field.dart';
import '../kyc_view_model.dart';
import '../widgets/photo_picker_tile.dart';

class Step1GhanaCardScreen extends StatefulWidget {
  const Step1GhanaCardScreen({super.key});

  @override
  State<Step1GhanaCardScreen> createState() => _Step1GhanaCardScreenState();
}

class _Step1GhanaCardScreenState extends State<Step1GhanaCardScreen> {
  late final TextEditingController _cardNumberController;

  @override
  void initState() {
    super.initState();
    _cardNumberController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final value = context.read<KycViewModel>().ghanaCardNumber;
    if (_cardNumberController.text != value) {
      _cardNumberController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KycViewModel>();
    if (_cardNumberController.text != vm.ghanaCardNumber) {
      _cardNumberController.value = TextEditingValue(
        text: vm.ghanaCardNumber,
        selection: TextSelection.collapsed(offset: vm.ghanaCardNumber.length),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verify your identity',
          style: context.appTextTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.space1),
        Text(
          'Enter your Ghana Card number and upload clear photos of the front and back.',
          style: context.appTextTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.space5),
        AppTextField(
          label: 'Ghana Card number',
          hint: 'GHA-728430143-4',
          controller: _cardNumberController,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          maxLength: 15,
          helperText: 'Use the number printed on your Ghana Card.',
          onChanged: context.read<KycViewModel>().setGhanaCardNumber,
          validator: (value) {
            if (value == null || value.trim().isEmpty) return null;
            return vm.isGhanaCardNumberValid
                ? null
                : 'Enter a valid Ghana Card number, for example GHA-728430143-4.';
          },
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: AppSpacing.space4),
        Text('Ghana Card photos', style: context.appTextTheme.titleSmall),
        const SizedBox(height: AppSpacing.space2),
        PhotoPickerTile(
          label: 'Front of Ghana Card',
          filePath: vm.idFront?.displayPath,
          isUploading: vm.idFront?.uploading ?? false,
          uploadError: vm.idFront?.error,
          onTap: () => context.read<KycViewModel>().pickIdFront(),
        ),
        const SizedBox(height: AppSpacing.space3),
        PhotoPickerTile(
          label: 'Back of Ghana Card',
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
        const SizedBox(height: AppSpacing.space1),
      ],
    );
  }
}
