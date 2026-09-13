import 'package:flutter/services.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';

/// Groups an amount with thousands separators as it is typed.
///
/// `1500000` becomes `1.500.000` while the user types, so a large figure can be
/// read back at a glance instead of being counted digit by digit.
///
/// The caret is always placed at the end. For an amount field that is the right
/// trade: separators shift as digits are added, so preserving an interior caret
/// position would land it in the wrong place more often than not.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter({this.maxDigits = 12});

  /// Guards against an int overflow from a pasted or held-down key.
  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    if (digits.length > maxDigits) {
      // Refuse the edit rather than silently truncating what was typed.
      if (oldValue.text.isNotEmpty) return oldValue;
      digits = digits.substring(0, maxDigits);
    }

    final amount = int.tryParse(digits);
    if (amount == null) return oldValue;

    final formatted = formatRupiah(amount);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
