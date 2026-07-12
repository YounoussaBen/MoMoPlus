import 'package:flutter/material.dart';

import '../../utils/ghana_phone.dart';
import '../../utils/ghana_phone_input_formatter.dart';
import '../theme/app_theme_extension.dart';
import 'app_text_field.dart';

/// Ghana mobile-number input shared by authentication and guarantor forms.
///
/// The field owns the national portion only. It displays a fixed +233 prefix,
/// removes a pasted or typed trunk zero, formats nine digits, and validates
/// that the number starts with a supported Ghana mobile prefix.
class GhanaPhoneField extends StatelessWidget {
  const GhanaPhoneField({
    super.key,
    required this.controller,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction = TextInputAction.next,
    this.autovalidateMode,
    this.autofillHints = const [AutofillHints.telephoneNumber],
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction textInputAction;
  final AutovalidateMode? autovalidateMode;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      hint: '24 123 4567',
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      autovalidateMode: autovalidateMode,
      inputFormatters: const [GhanaNationalPhoneInputFormatter()],
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🇬🇭', style: context.appTextTheme.titleMedium),
            const SizedBox(width: 8),
            Text('+233', style: context.appTextTheme.titleSmall),
          ],
        ),
      ),
      validator: (value) {
        try {
          normalizeGhanaPhone(value ?? '');
          return null;
        } on GhanaPhoneException catch (error) {
          return error.message;
        }
      },
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
