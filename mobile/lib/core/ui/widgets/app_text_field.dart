import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatelessWidget {
  final String hint;
  final String? label;
  final String? helperText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  const AppTextField({
    super.key,
    required this.hint,
    this.label,
    this.helperText,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.suffixIcon,
    this.prefixIcon,
    this.autofocus = false,
    this.focusNode,
    this.enabled = true,
    this.autofillHints,
    this.maxLines = 1,
    this.maxLength,
    this.onFieldSubmitted,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onChanged: onChanged,
      autofocus: autofocus,
      focusNode: focusNode,
      enabled: enabled,
      autofillHints: autofillHints,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: inputFormatters,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
