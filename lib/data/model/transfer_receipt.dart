import 'package:newtronic_banking/common/constants.dart';

/// Everything the receipt screen needs about a completed transfer.
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
    required this.sourceAccountName,
    required this.nominal,
    required this.transactionType,
    required this.reference,
    required this.createdAt,
    this.adminFee = adminFeeIdr,
    this.note,
  });

  /// The signed-in user this transfer belongs to.
  final int userId;
  final String recipientName;
  final String bankName;
  final String bankImage;
  final String accountNumber;
  final String sourceAccountName;

  /// Whole rupiah.
  final int nominal;
  final int adminFee;
  final String transactionType;
  final String reference;
  final DateTime createdAt;
  final String? note;

  int get total => nominal + adminFee;
}
