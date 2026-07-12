import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/utils/ghana_phone.dart';

void main() {
  test('normalizes supported Ghana formats to E.164', () {
    expect(normalizeGhanaPhone('0241234567'), '+233241234567');
    expect(normalizeGhanaPhone('241234567'), '+233241234567');
    expect(normalizeGhanaPhone('+233 24 123 4567'), '+233241234567');
  });

  test('rejects invalid and fixed-line input', () {
    expect(() => normalizeGhanaPhone(''), throwsA(isA<GhanaPhoneException>()));
    expect(
      () => normalizeGhanaPhone('+233301234567'),
      throwsA(isA<GhanaPhoneException>()),
    );
    expect(
      () => normalizeGhanaPhone('phone'),
      throwsA(isA<GhanaPhoneException>()),
    );
  });

  test('formats and masks without changing identity', () {
    expect(formatGhanaPhone('+233241234567'), '+233 24 123 4567');
    expect(maskGhanaPhone('+233241234567'), '+233 24 ••• 4567');
  });
}
