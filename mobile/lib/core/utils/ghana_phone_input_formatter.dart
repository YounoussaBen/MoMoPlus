import 'package:flutter/services.dart';

/// Formats the national portion shown beside the fixed Ghana +233 prefix.
///
/// A leading trunk zero is intentionally omitted, so both `0241234567` and
/// `241234567` render as `24 123 4567`.
class GhanaNationalPhoneInputFormatter extends TextInputFormatter {
  const GhanaNationalPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.startsWith('233') && digits.length > 9) {
      digits = digits.substring(3);
    }
    if (digits.length > 9) {
      digits = digits.substring(0, 9);
    }

    final formatted = _formatDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatDigits(String digits) {
    if (digits.length <= 2) return digits;

    final first = digits.substring(0, 2);
    if (digits.length <= 5) {
      return '$first ${digits.substring(2)}';
    }

    return '$first ${digits.substring(2, 5)} ${digits.substring(5)}';
  }
}
