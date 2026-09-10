import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('formattedBankNumber', () {
    test('groups a multiple-of-four length into blocks', () {
      expect(formattedBankNumber('1234567890123456'), '1234 5678 9012 3456');
    });

    test('does not throw when the length is not a multiple of four', () {
      // Previously `substring(i, i + 4)` walked past the end and threw a
      // RangeError for any of these.
      expect(formattedBankNumber('1'), '1');
      expect(formattedBankNumber('12345'), '1234 5');
      expect(formattedBankNumber('1234567'), '1234 567');
      expect(formattedBankNumber('123456789'), '1234 5678 9');
    });

    test('strips non-digits before grouping', () {
      expect(formattedBankNumber('12-34 56/78'), '1234 5678');
    });

    test('returns an empty string when there are no digits', () {
      expect(formattedBankNumber('abc'), '');
      expect(formattedBankNumber(''), '');
    });
  });

  group('maskedBankNumber', () {
    test('masks the middle of a full account number', () {
      expect(maskedBankNumber('123456789012'), '1234 **** 9012');
    });

    test('falls back to grouping when too short to mask', () {
      expect(maskedBankNumber('1234'), '1234');
      expect(maskedBankNumber('1234567'), '1234 567');
      expect(maskedBankNumber(''), '');
    });
  });

  group('rupiah formatting', () {
    test('formats whole rupiah with Indonesian grouping', () {
      expect(formatRupiah(2500), '2.500');
      expect(formatRupiah(5000000), '5.000.000');
      expect(formatRupiahWithSymbol(2500), 'Rp 2.500');
    });

    test('parses formatted and raw input back to an int', () {
      expect(parseRupiah('5.000.000'), 5000000);
      expect(parseRupiah('5,000,000 '), 5000000);
      expect(parseRupiah('2500'), 2500);
    });

    test('returns null when the input holds no digits', () {
      expect(parseRupiah(''), isNull);
      expect(parseRupiah('Rp'), isNull);
    });
  });

  group('formattedTransactionDate', () {
    test('formats in the Indonesian locale', () {
      expect(
        formattedTransactionDate(DateTime(2023, 9, 1)),
        '01 September 2023',
      );
    });
  });
}
