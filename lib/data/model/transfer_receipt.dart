import 'package:newtronic_banking/common/constants.dart';
import 'package:newtronic_banking/data/model/money.dart';

/// Everything about a transfer, from the form through to the receipt.
///
/// Replaces the untyped `List<Map<String, String>>` that used to be passed as a
/// route argument, which forced callers to index `[0]['nominal']!` and left the
/// recipient name, reference number and admin fee hardcoded.
class TransferReceipt {
  const TransferReceipt({
    required this.userId,
    required this.recipientName,
    required this.bankName,
    required this.bankImage,
    required this.accountNumber,
    required this.sourceAccountId,
    required this.sourceAccountName,
    required this.nominal,
    required this.transactionType,
    required this.reference,
    required this.createdAt,
    this.adminFee = const Money(adminFeeIdr),
    this.note,
  });

  /// The signed-in user this transfer belongs to.
  final int userId;

  final String recipientName;
  final String bankName;
  final String bankImage;
  final String accountNumber;

  /// Which account the money leaves. Needed to debit the right one — the name
  /// alone is not a key.
  final String sourceAccountId;

  final String sourceAccountName;

  final Money nominal;
  final Money adminFee;
  final String transactionType;
  final String reference;
  final DateTime createdAt;
  final String? note;

  /// What actually leaves the account.
  Money get total => nominal + adminFee;
}
