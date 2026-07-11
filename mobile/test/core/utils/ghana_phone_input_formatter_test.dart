import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/utils/ghana_phone_input_formatter.dart';

void main() {
  const formatter = GhanaNationalPhoneInputFormatter();
  const empty = TextEditingValue.empty;

  test('drops the Ghana trunk zero and groups the national number', () {
    final formatted = formatter.formatEditUpdate(
      empty,
      const TextEditingValue(text: '0241234567'),
    );

    expect(formatted.text, '24 123 4567');
    expect(formatted.selection.baseOffset, formatted.text.length);
  });

  test('a leading zero is not displayed while typing', () {
    final zero = formatter.formatEditUpdate(
      empty,
      const TextEditingValue(text: '0'),
    );
    final nextDigit = formatter.formatEditUpdate(
      zero,
      const TextEditingValue(text: '02'),
    );

    expect(zero.text, isEmpty);
    expect(nextDigit.text, '2');
  });

  test('formats pasted E.164 input and limits it to nine national digits', () {
    final formatted = formatter.formatEditUpdate(
      empty,
      const TextEditingValue(text: '+23324123456799'),
    );

    expect(formatted.text, '24 123 4567');
  });
}
