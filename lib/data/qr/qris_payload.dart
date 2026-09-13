import 'dart:convert';
import 'dart:typed_data';

import 'package:newtronic_banking/data/model/money.dart';

/// Why a scanned or pasted code could not be used.
///
/// Each case says what is wrong with the code rather than "invalid QR": a
/// person holding a phone at a printed code needs to know whether to try
/// again, ask for a different code, or stop.
enum QrisFailure {
  empty,
  notTlv,
  unsupportedFormat,
  wrongCurrency,
  missingBank,
  badAccountNumber,
  missingName,
  badAmount,
  badChecksum;

  String get message => switch (this) {
        empty => 'There is no code here to read.',
        notTlv => 'This is not a payment code.',
        unsupportedFormat => 'This payment code uses a format we cannot read.',
        wrongCurrency => 'This code asks for a currency other than Rupiah.',
        missingBank => 'The code does not say which bank to pay.',
        badAccountNumber =>
          'The account number in this code is not between 10 and 16 digits.',
        missingName => 'The code does not say who is being paid.',
        badAmount => 'The amount in this code is not a value we can pay.',
        badChecksum =>
          'This code is damaged — its checksum does not match. Ask for a '
              'fresh one rather than paying from it.',
      };
}

/// The outcome of reading a code: either a payload or a reason it is unusable.
sealed class QrisDecodeResult {
  const QrisDecodeResult();
}

final class QrisDecoded extends QrisDecodeResult {
  const QrisDecoded(this.payload);

  final QrisPayload payload;
}

final class QrisRejected extends QrisDecodeResult {
  const QrisRejected(this.failure);

  final QrisFailure failure;

  String get message => failure.message;
}

/// A payment request carried in a QR code.
///
/// The wire format is EMVCo's tag-length-value, the same shape Indonesian
/// QRIS codes use, including the CRC-16 trailer. It is written properly rather
/// than as a private format so that a code this app produces is structurally
/// what a real reader expects, and a real code is structurally readable here.
/// The account identifiers are still this app's own, so payments only work
/// between its own users.
///
/// [amount] is optional by design. A static code printed and stuck to a wall
/// names the payee and nothing else; the payer types what they owe.
class QrisPayload {
  const QrisPayload({
    required this.bankName,
    required this.accountNumber,
    required this.recipientName,
    this.amount,
    this.note,
  });

  final String bankName;
  final String accountNumber;
  final String recipientName;
  final Money? amount;
  final String? note;

  /// True when the code names the amount, so the payer is not asked for one.
  bool get isDynamic => amount != null;

  // --------------------------------------------------------------- encoding

  /// The string to put inside a QR image.
  String encode() {
    final merchantAccount = _tlv('00', bankName) + _tlv('01', accountNumber);
    final additional = note == null ? '' : _tlv('01', note!);

    final body = _tlv('00', '01') // payload format indicator
        +
        _tlv('01', amount == null ? '11' : '12') // static or dynamic
        +
        _tlv('26', merchantAccount) // merchant account information
        +
        _tlv('52', '0000') // merchant category: unspecified
        +
        _tlv('53', '360') // currency: IDR
        +
        (amount == null ? '' : _tlv('54', amount!.rupiah.toString())) +
        _tlv('58', 'ID') // country
        +
        _tlv('59', _truncateToBytes(recipientName, 25)) +
        (additional.isEmpty ? '' : _tlv('62', additional));

    // The CRC covers everything up to and including its own tag and length,
    // which is why '6304' is appended before it is computed.
    final toCheck = '${body}6304';
    return '$toCheck${_crc16(toCheck)}';
  }

  static String _tlv(String tag, String value) {
    final length = utf8.encode(value).length;
    return '$tag${length.toString().padLeft(2, '0')}$value';
  }

  // --------------------------------------------------------------- decoding

  /// Reads a code, saying why if it cannot be used.
  static QrisDecodeResult decode(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const QrisRejected(QrisFailure.empty);

    // Sliced as bytes, not characters: EMVCo lengths count bytes, so a
    // non-Latin payee name would shift every field after it if the offsets
    // were counted in Dart's UTF-16 code units.
    final fields = _parse(utf8.encode(text));
    if (fields == null) return const QrisRejected(QrisFailure.notTlv);

    final checksum = fields['63'];
    if (checksum == null || checksum.length != 4) {
      return const QrisRejected(QrisFailure.notTlv);
    }

    // Everything before the four checksum characters is what was signed.
    final expected = _crc16(text.substring(0, text.length - 4));
    if (checksum.toUpperCase() != expected) {
      return const QrisRejected(QrisFailure.badChecksum);
    }

    if (fields['00'] != '01') {
      return const QrisRejected(QrisFailure.unsupportedFormat);
    }
    // An absent currency is tolerated — some writers omit it — but one that is
    // present and not Rupiah is refused rather than paid in the wrong money.
    if (fields['53'] != null && fields['53'] != '360') {
      return const QrisRejected(QrisFailure.wrongCurrency);
    }

    final merchant = fields['26'];
    if (merchant == null) return const QrisRejected(QrisFailure.missingBank);
    final merchantFields = _parse(utf8.encode(merchant));
    if (merchantFields == null) {
      return const QrisRejected(QrisFailure.missingBank);
    }

    final bankName = merchantFields['00']?.trim() ?? '';
    if (bankName.isEmpty) return const QrisRejected(QrisFailure.missingBank);

    final accountNumber =
        (merchantFields['01'] ?? '').replaceAll(RegExp(r'\D'), '');
    if (!isPlausibleAccountNumber(accountNumber)) {
      return const QrisRejected(QrisFailure.badAccountNumber);
    }

    final recipientName = fields['59']?.trim() ?? '';
    if (recipientName.isEmpty) {
      return const QrisRejected(QrisFailure.missingName);
    }

    Money? amount;
    if (fields['54'] case final String written) {
      amount = _parseAmount(written);
      if (amount == null) return const QrisRejected(QrisFailure.badAmount);
    }

    final additional = fields['62'];
    final note = additional == null
        ? null
        : _parse(utf8.encode(additional))?['01']?.trim();

    return QrisDecoded(QrisPayload(
      bankName: bankName,
      accountNumber: accountNumber,
      recipientName: recipientName,
      amount: amount,
      note: note == null || note.isEmpty ? null : note,
    ));
  }

  /// Indonesian account numbers run 10 to 16 digits depending on the bank.
  static bool isPlausibleAccountNumber(String digits) =>
      digits.length >= 10 &&
      digits.length <= 16 &&
      !digits.contains(RegExp(r'\D'));

  /// Splits one level of tag-length-value, or null if the bytes are not that.
  ///
  /// A repeated tag keeps the first occurrence. Silently preferring the last
  /// would let a crafted code append a second amount that overrides the one
  /// the payer was shown.
  static Map<String, String>? _parse(Uint8List bytes) {
    final fields = <String, String>{};
    var index = 0;

    while (index < bytes.length) {
      // A tag and a length are two digits each, so any field needs four bytes.
      if (index + 4 > bytes.length) return null;

      final tag = ascii.decode(bytes.sublist(index, index + 2),
          allowInvalid: true);
      final lengthText = ascii.decode(bytes.sublist(index + 2, index + 4),
          allowInvalid: true);
      if (!_isTwoDigits(tag) || !_isTwoDigits(lengthText)) return null;

      final end = index + 4 + int.parse(lengthText);
      if (end > bytes.length) return null;

      fields.putIfAbsent(
        tag,
        () => utf8.decode(bytes.sublist(index + 4, end), allowMalformed: true),
      );
      index = end;
    }

    return fields.isEmpty ? null : fields;
  }

  static bool _isTwoDigits(String text) =>
      text.length == 2 && !text.contains(RegExp(r'\D'));

  /// Reads tag 54, which may carry decimals even where the currency has none.
  static Money? _parseAmount(String written) {
    final value = num.tryParse(written.trim());
    // Rupiah is paid in whole units, and a fractional request cannot be
    // honoured exactly, so it is refused instead of quietly rounded.
    if (value == null || value <= 0 || value != value.roundToDouble()) {
      return null;
    }
    return Money(value.toInt());
  }

  /// Cuts a string to a byte budget without splitting a character in half.
  static String _truncateToBytes(String text, int maxBytes) {
    if (utf8.encode(text).length <= maxBytes) return text;

    // Walked by code point, so a name is never cut through the middle of a
    // character and turned into mojibake.
    final buffer = StringBuffer();
    var used = 0;
    for (final rune in text.runes) {
      final character = String.fromCharCode(rune);
      final size = utf8.encode(character).length;
      if (used + size > maxBytes) break;
      buffer.write(character);
      used += size;
    }
    return buffer.toString();
  }

  /// CRC-16/CCITT-FALSE: polynomial 0x1021, initial value 0xFFFF.
  static String _crc16(String text) {
    var crc = 0xFFFF;

    for (final byte in utf8.encode(text)) {
      crc ^= byte << 8;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
        crc &= 0xFFFF;
      }
    }

    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
