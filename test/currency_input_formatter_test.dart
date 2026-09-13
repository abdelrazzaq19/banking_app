import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/data/utils/currency_input_formatter.dart';

/// Applies the formatter the way a text field would.
TextEditingValue _type(String next, {String previous = ''}) {
  const formatter = ThousandsSeparatorInputFormatter();
  return formatter.formatEditUpdate(
    TextEditingValue(text: previous),
    TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    ),
  );
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('ThousandsSeparatorInputFormatter', () {
    test('groups digits as they are entered', () {
      expect(_type('1').text, '1');
      expect(_type('15').text, '15');
      expect(_type('150').text, '150');
      expect(_type('1500').text, '1.500');
      expect(_type('1500000').text, '1.500.000');
    });

    test('strips anything that is not a digit', () {
      expect(_type('1a5b0c0').text, '1.500');
      expect(_type('Rp 250.000').text, '250.000');
    });

    test('clearing the field yields an empty value', () {
      expect(_type('', previous: '1.500').text, '');
      expect(_type('abc').text, '');
    });

    test('keeps the caret at the end', () {
      final value = _type('1500000');
      expect(value.selection.baseOffset, value.text.length);
      expect(value.selection.isCollapsed, isTrue);
    });

    test('refuses an edit that would exceed the digit cap', () {
      // Thirteen digits, one past the twelve-digit limit.
      final rejected = _type('1234567890123', previous: '99.999');
      expect(rejected.text, '99.999');
    });

    test('truncates rather than overflowing when there is nothing to keep', () {
      final value = _type('1234567890123');
      expect(value.text.replaceAll('.', '').length, 12);
    });

    test('round-trips through the parser', () {
      const cases = ['1500', '250000', '5000000'];
      for (final raw in cases) {
        final formatted = _type(raw).text;
        expect(
          formatted.replaceAll('.', ''),
          raw,
          reason: 'formatting "$raw" must not change its digits',
        );
      }
    });
  });
}
