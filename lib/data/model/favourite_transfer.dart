import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';

/// A recipient worth keeping, so the next transfer to them is one tap.
///
/// Stores who the money goes to, not how much: the amount is a suggestion that
/// can be left off, because paying the same person a different amount is the
/// normal case.
class FavouriteTransfer {
  const FavouriteTransfer({
    required this.id,
    required this.recipientName,
    required this.bankName,
    required this.bankImage,
    required this.accountNumber,
    required this.createdAt,
    this.amount,
    this.transactionType,
    this.note,
  });

  /// Built from a transfer the user just made.
  ///
  /// The id is derived from the destination rather than the receipt, so saving
  /// the same recipient twice updates one entry instead of making a duplicate.
  factory FavouriteTransfer.fromReceipt(TransferReceipt receipt) =>
      FavouriteTransfer(
        id: favouriteIdFor(
          bankName: receipt.bankName,
          accountNumber: receipt.accountNumber,
        ),
        recipientName: receipt.recipientName,
        bankName: receipt.bankName,
        bankImage: receipt.bankImage,
        accountNumber: receipt.accountNumber,
        amount: receipt.nominal,
        transactionType: receipt.transactionType,
        note: receipt.note,
        createdAt: receipt.createdAt,
      );

  factory FavouriteTransfer.fromJson(Map<String, dynamic> json) =>
      FavouriteTransfer(
        id: json['id'] as String,
        recipientName: json['recipient_name'] as String,
        bankName: json['bank_name'] as String,
        bankImage: json['bank_image'] as String? ?? '',
        accountNumber: json['account_number'] as String,
        amount: json['amount'] == null ? null : Money.parse(json['amount']),
        transactionType: json['transaction_type'] as String?,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String recipientName;
  final String bankName;
  final String bankImage;
  final String accountNumber;

  /// The last amount sent, offered as a default. Null means "ask me".
  final Money? amount;

  final String? transactionType;
  final String? note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipient_name': recipientName,
        'bank_name': bankName,
        'bank_image': bankImage,
        'account_number': accountNumber,
        if (amount != null) 'amount': amount!.toJson(),
        if (transactionType != null) 'transaction_type': transactionType,
        if (note != null) 'note': note,
        'created_at': createdAt.toIso8601String(),
      };
}

/// One destination, one favourite — so re-saving a recipient replaces rather
/// than duplicates.
String favouriteIdFor({
  required String bankName,
  required String accountNumber,
}) =>
    '${bankName.toLowerCase().trim()}:'
    '${accountNumber.replaceAll(RegExp(r'\D'), '')}';
