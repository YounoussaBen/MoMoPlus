import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/theme/app_spacing.dart';
import '../../../../core/ui/theme/app_theme_extension.dart';
import '../../../../core/ui/widgets/app_button.dart';
import '../../../../core/ui/widgets/app_text_field.dart';
import '../kyc_view_model.dart';
import '../widgets/photo_picker_tile.dart';

String _formatGhanaCardDigits(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final limited = digits.length > 10 ? digits.substring(0, 10) : digits;
  if (limited.length <= 9) return limited;
  return '${limited.substring(0, 9)}-${limited.substring(9)}';
}

TextEditingValue _formatGhanaCardInput(
  TextEditingValue _,
  TextEditingValue newValue,
) {
  final formatted = _formatGhanaCardDigits(newValue.text);
  final cursorOffset = newValue.selection.extentOffset < 0
      ? 0
      : newValue.selection.extentOffset > newValue.text.length
      ? newValue.text.length
      : newValue.selection.extentOffset;
  final digitsBeforeCursor = newValue.text
      .substring(0, cursorOffset)
      .replaceAll(RegExp(r'\D'), '')
      .length;
  final limitedDigitsBeforeCursor = min(
    digitsBeforeCursor,
    formatted.replaceAll(RegExp(r'\D'), '').length,
  );
  final formattedCursorOffset = limitedDigitsBeforeCursor > 9
      ? limitedDigitsBeforeCursor + 1
      : limitedDigitsBeforeCursor;

  return newValue.copyWith(
    text: formatted,
    selection: TextSelection.collapsed(offset: formattedCursorOffset),
    composing: TextRange.empty,
  );
}

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

  void _syncCardNumberController(String value) {
    final formattedValue = _formatGhanaCardDigits(value);
    if (_cardNumberController.text == formattedValue) return;

    _cardNumberController.value = TextEditingValue(
      text: formattedValue,
      selection: TextSelection.collapsed(offset: formattedValue.length),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncCardNumberController(context.read<KycViewModel>().ghanaCardNumber);
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KycViewModel>();
    _syncCardNumberController(vm.ghanaCardNumber);
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
          hint: '728430143-4',
          prefixText: 'GHA-',
          controller: _cardNumberController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 11,
          inputFormatters: [
            TextInputFormatter.withFunction(_formatGhanaCardInput),
          ],
          helperText: 'Use the number printed on your Ghana Card.',
          onChanged: (value) {
            final formattedValue = _formatGhanaCardDigits(value);
            context.read<KycViewModel>().setGhanaCardNumber(
              formattedValue.isEmpty ? '' : 'GHA-$formattedValue',
            );
          },
          validator: (value) {
            if (value == null || value.trim().isEmpty) return null;
            return vm.isGhanaCardNumberValid
                ? null
                : 'Enter the 10 digits after GHA-, for example 728430143-4.';
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
