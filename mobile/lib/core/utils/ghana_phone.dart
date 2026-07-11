class GhanaPhoneException implements Exception {
  const GhanaPhoneException([
    this.message = 'Enter a valid Ghana mobile number.',
  ]);

  final String message;

  @override
  String toString() => message;
}

String normalizeGhanaPhone(String raw) {
  final value = raw.trim();
  if (value.isEmpty || RegExp(r'[A-Za-z]').hasMatch(value)) {
    throw const GhanaPhoneException();
  }

  final digits = value.replaceAll(RegExp(r'\D'), '');
  late final String national;
  if (digits.startsWith('233') && digits.length == 12) {
    national = digits.substring(3);
  } else if (digits.startsWith('0') && digits.length == 10) {
    national = digits.substring(1);
  } else if (digits.length == 9) {
    national = digits;
  } else {
    throw const GhanaPhoneException();
  }

  if (!national.startsWith('2') && !national.startsWith('5')) {
    throw const GhanaPhoneException();
  }
  return '+233$national';
}

String formatGhanaPhone(String e164) {
  final normalized = normalizeGhanaPhone(e164);
  final national = normalized.substring(4);
  return '+233 ${national.substring(0, 2)} ${national.substring(2, 5)} ${national.substring(5)}';
}

String maskGhanaPhone(String e164) {
  final formatted = formatGhanaPhone(e164);
  return '${formatted.substring(0, 7)} ••• ${formatted.substring(formatted.length - 4)}';
}
