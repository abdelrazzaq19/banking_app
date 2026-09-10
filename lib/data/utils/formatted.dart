import 'package:intl/intl.dart';

final NumberFormat _rupiahFormat = NumberFormat.decimalPattern('id_ID');

/// Formats a whole-rupiah amount, e.g. `2500` -> `2.500`.
String formatRupiah(int amount) => _rupiahFormat.format(amount);

/// Formats a whole-rupiah amount with its symbol, e.g. `2500` -> `Rp 2.500`.
String formatRupiahWithSymbol(int amount) => 'Rp ${formatRupiah(amount)}';

/// Parses user input such as `1.500.000` or `1500000` into whole rupiah.
///
/// Returns `null` when the input contains no digits.
int? parseRupiah(String text) {
  final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.isEmpty) return null;
  return int.tryParse(digitsOnly);
}

/// Groups an account number into blocks of four, e.g. `123456789` -> `1234 5678 9`.
///
/// Safe for any length: the final block is short rather than out of range.
String formattedBankNumber(String text) {
  final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
  final groups = <String>[];
  for (var i = 0; i < digitsOnly.length; i += 4) {
    final end = (i + 4) < digitsOnly.length ? i + 4 : digitsOnly.length;
    groups.add(digitsOnly.substring(i, end));
  }
  return groups.join(' ');
}

/// Masks the middle of an account number, e.g. `123456789012` -> `1234 **** 9012`.
///
/// Falls back to the grouped number when there are too few digits to mask.
String maskedBankNumber(String text) {
  final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length < 8) return formattedBankNumber(digitsOnly);
  final head = digitsOnly.substring(0, 4);
  final tail = digitsOnly.substring(digitsOnly.length - 4);
  return '$head **** $tail';
}

/// Formats a transaction date for display, e.g. `01 September 2023`.
String formattedTransactionDate(DateTime date) =>
    DateFormat('dd MMMM yyyy', 'id_ID').format(date);
