import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/qr/qris_payload.dart';

/// Builds one tag-length-value field.
///
/// The lengths are computed rather than written out because counting bytes by
/// eye is how the first draft of these fixtures went wrong: every one of them
/// was rejected as malformed before it reached the field under test.
String _tlv(String tag, String value) =>
    '$tag${utf8.encode(value).length.toString().padLeft(2, '0')}$value';

/// The merchant account template: which bank, which account.
String _merchant(String bank, String account) =>
    _tlv('26', _tlv('00', bank) + _tlv('01', account));

/// Recomputes the trailer so a hand-built payload is well-formed, letting a
/// test isolate one broken field instead of failing on the checksum first.
String _signed(String body) {
  final toCheck = '${body}6304';
  var crc = 0xFFFF;
  for (final byte in utf8.encode(toCheck)) {
    crc ^= byte << 8;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xFFFF;
    }
  }
  return '$toCheck${crc.toRadixString(16).toUpperCase().padLeft(4, '0')}';
}

QrisPayload _decoded(String raw) {
  final result = QrisPayload.decode(raw);
  expect(result, isA<QrisDecoded>(), reason: switch (result) {
    QrisRejected(:final message) => message,
    _ => 'decoded',
  });
  return (result as QrisDecoded).payload;
}

QrisFailure _rejected(String raw) {
  final result = QrisPayload.decode(raw);
  expect(result, isA<QrisRejected>());
  return (result as QrisRejected).failure;
}

void main() {
  const static = QrisPayload(
    bankName: 'Bank Danamon',
    accountNumber: '123456789012',
    recipientName: 'Siti Rahayu',
  );

  group('round trip', () {
    test('a static code carries the payee and no amount', () {
      final payload = _decoded(static.encode());

      expect(payload.bankName, 'Bank Danamon');
      expect(payload.accountNumber, '123456789012');
      expect(payload.recipientName, 'Siti Rahayu');
      expect(payload.amount, isNull);
      expect(payload.isDynamic, isFalse);
      expect(payload.note, isNull);
    });

    test('a dynamic code carries the amount and the note', () {
      final payload = _decoded(const QrisPayload(
        bankName: 'Bank Mandiri',
        accountNumber: '9876543210987654',
        recipientName: 'Warung Bu Tini',
        amount: Money(47500),
        note: 'Table 4',
      ).encode());

      expect(payload.amount, const Money(47500));
      expect(payload.isDynamic, isTrue);
      expect(payload.note, 'Table 4');
      expect(payload.accountNumber, '9876543210987654');
    });

    test('a non-Latin name survives, because lengths count bytes', () {
      // Each of these characters is three bytes in UTF-8. Counting the length
      // in Dart's UTF-16 code units instead would shift every field after the
      // name and the decode would fail or return garbage.
      final payload = _decoded(const QrisPayload(
        bankName: 'Bank Permata',
        accountNumber: '1122334455',
        recipientName: 'サトウ ハナコ',
      ).encode());

      expect(payload.recipientName, 'サトウ ハナコ');
    });

    test('an over-long name is cut to the spec limit, not mid-character', () {
      final payload = _decoded(const QrisPayload(
        bankName: 'Bank Mega',
        accountNumber: '1122334455',
        recipientName: 'サトウハナコサトウハナコサトウハナコ',
      ).encode());

      // 25 bytes holds 8 three-byte characters; a ninth would need 27.
      expect(payload.recipientName, 'サトウハナコサト');
      expect(payload.recipientName.runes.length, 8);
    });
  });

  group('the encoded string is EMVCo-shaped', () {
    test('it opens with the format indicator and closes with a CRC', () {
      final code = static.encode();

      expect(code, startsWith('000201'));
      expect(code.substring(code.length - 8, code.length - 4), '6304');
      expect(code.substring(code.length - 4), matches(RegExp(r'^[0-9A-F]{4}$')));
    });

    test('it states Rupiah, Indonesia, and whether the amount is fixed', () {
      expect(static.encode(), contains('5303360'));
      expect(static.encode(), contains('5802ID'));
      // 11 is a static code, 12 one that names the amount.
      expect(static.encode(), contains('010211'));
      expect(
        const QrisPayload(
          bankName: 'Bank Mega',
          accountNumber: '1122334455',
          recipientName: 'Budi',
          amount: Money(1000),
        ).encode(),
        contains('010212'),
      );
    });

    test('the checksum matches one computed independently', () {
      final code = static.encode();
      expect(code, _signed(code.substring(0, code.length - 8)));
    });
  });

  group('rejection', () {
    test('nothing to read', () {
      expect(_rejected('   '), QrisFailure.empty);
    });

    test('not a payment code at all', () {
      expect(_rejected('https://example.com/pay/123'), QrisFailure.notTlv);
      expect(_rejected('hello'), QrisFailure.notTlv);
    });

    test('a field that claims more bytes than are there', () {
      // Tag 00 says its value is 99 bytes long; only two follow.
      expect(_rejected(_signed('009901')), QrisFailure.notTlv);
    });

    test('a single altered character fails the checksum', () {
      final code = static.encode();
      final tampered = code.replaceFirst('123456789012', '123456789013');

      expect(tampered, isNot(code));
      expect(_rejected(tampered), QrisFailure.badChecksum);
    });

    test('a truncated code fails rather than decoding a prefix', () {
      final code = static.encode();
      expect(_rejected(code.substring(0, code.length - 6)),
          isIn([QrisFailure.notTlv, QrisFailure.badChecksum]));
    });

    test('an unknown payload format', () {
      expect(
        _rejected(_signed(_tlv('00', '09') +
            _merchant('Bank Danamon', '123456789012') +
            _tlv('53', '360') +
            _tlv('59', 'Siti Rahayu'))),
        QrisFailure.unsupportedFormat,
      );
    });

    test('a currency that is not Rupiah', () {
      expect(
        _rejected(_signed(_tlv('00', '01') +
            _merchant('Bank Danamon', '123456789012') +
            _tlv('53', '840') +
            _tlv('59', 'Siti Rahayu'))),
        QrisFailure.wrongCurrency,
      );
    });

    test('no bank named', () {
      expect(
        _rejected(_signed(_tlv('00', '01') +
            _tlv('53', '360') +
            _tlv('59', 'Siti Rahayu'))),
        QrisFailure.missingBank,
      );
    });

    test('an account number of the wrong length', () {
      for (final digits in ['123456789', '12345678901234567']) {
        expect(
          _rejected(_signed(_tlv('00', '01') +
              _merchant('Bank Danamon', digits) +
              _tlv('53', '360') +
              _tlv('59', 'Siti Rahayu'))),
          QrisFailure.badAccountNumber,
          reason: 'a $digits-digit number should be refused',
        );
      }
    });

    test('nobody named to pay', () {
      expect(
        _rejected(_signed(_tlv('00', '01') +
            _merchant('Bank Danamon', '123456789012') +
            _tlv('53', '360'))),
        QrisFailure.missingName,
      );
    });

    test('an amount that cannot be paid in whole rupiah', () {
      for (final written in ['0', '-500', '12.50', 'lots']) {
        expect(
          _rejected(_signed(_tlv('00', '01') +
              _merchant('Bank Danamon', '123456789012') +
              _tlv('53', '360') +
              _tlv('54', written) +
              _tlv('59', 'Siti Rahayu'))),
          QrisFailure.badAmount,
          reason: 'an amount of "$written" should be refused',
        );
      }
    });

    test('a second amount appended after the first is ignored', () {
      // Keeping the last occurrence would let a code show one amount to a
      // reader and hand a different one to the app.
      final payload = _decoded(_signed(_tlv('00', '01') +
          _merchant('Bank Danamon', '123456789012') +
          _tlv('53', '360') +
          _tlv('54', '250000') +
          _tlv('59', 'Siti Rahayu') +
          _tlv('54', '9999999')));

      expect(payload.amount, const Money(250000));
    });
  });

  group('account number plausibility', () {
    test('accepts the 10 to 16 digits real accounts use', () {
      expect(QrisPayload.isPlausibleAccountNumber('1234567890'), isTrue);
      expect(QrisPayload.isPlausibleAccountNumber('1234567890123456'), isTrue);
    });

    test('refuses anything shorter, longer or not a digit', () {
      expect(QrisPayload.isPlausibleAccountNumber('123456789'), isFalse);
      expect(
          QrisPayload.isPlausibleAccountNumber('12345678901234567'), isFalse);
      expect(QrisPayload.isPlausibleAccountNumber('12345678ab'), isFalse);
      expect(QrisPayload.isPlausibleAccountNumber(''), isFalse);
    });
  });
}
