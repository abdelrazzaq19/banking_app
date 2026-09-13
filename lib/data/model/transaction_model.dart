import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';

class Transaction {
  Transaction({required this.transactions});

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        transactions: List<Transactions>.from(
          json['transactions'].map((x) => Transactions.fromJson(x)),
        ),
      );

  final List<Transactions> transactions;

  Map<String, dynamic> toJson() => {
        'transactions': List<dynamic>.from(transactions.map((x) => x.toJson())),
      };
}

/// One entry in the activity history.
///
/// The seeded entries are bare — a payee, a date and an amount. A transfer the
/// user made carries the rest of its detail too, so the history can be searched
/// by bank and the receipt can be rebuilt from the record rather than only
/// existing in the moment it was made.
class Transactions {
  const Transactions({
    required this.id,
    required this.name,
    required this.date,
    required this.amount,
    required this.image,
    this.bankName,
    this.accountNumber,
    this.sourceAccountId,
    this.sourceAccountName,
    this.reference,
    this.transactionType,
    this.note,
    this.fee,
  });

  /// Builds the history entry for a completed transfer.
  factory Transactions.fromReceipt(TransferReceipt receipt) => Transactions(
        id: receipt.reference.replaceAll(' ', ''),
        name: receipt.recipientName,
        date: receipt.createdAt,
        amount: receipt.nominal,
        image: receipt.bankImage,
        bankName: receipt.bankName,
        accountNumber: receipt.accountNumber,
        sourceAccountId: receipt.sourceAccountId,
        sourceAccountName: receipt.sourceAccountName,
        reference: receipt.reference,
        transactionType: receipt.transactionType,
        note: receipt.note,
        fee: receipt.adminFee,
      );

  factory Transactions.fromJson(Map<String, dynamic> json) => Transactions(
        id: json['id'] as String,
        name: json['name'] as String,
        date: DateTime.parse(json['date'] as String),
        // Tolerates both the number the seed data now stores and the older
        // `"181,286"` string.
        amount: Money.parse(json['price_idr']),
        image: json['image'] as String? ?? '',
        bankName: json['bank_name'] as String?,
        accountNumber: json['account_number'] as String?,
        sourceAccountId: json['source_account_id'] as String?,
        sourceAccountName: json['source_account_name'] as String?,
        reference: json['reference'] as String?,
        transactionType: json['transaction_type'] as String?,
        note: json['note'] as String?,
        fee: json['fee'] == null ? null : Money.parse(json['fee']),
      );

  final String id;
  final String name;
  final DateTime date;
  final Money amount;
  final String image;

  // Present only on transfers the user made.
  final String? bankName;
  final String? accountNumber;
  final String? sourceAccountId;
  final String? sourceAccountName;
  final String? reference;
  final String? transactionType;
  final String? note;
  final Money? fee;

  /// Whether this entry came from a transfer rather than the seeded history.
  bool get isTransfer => reference != null;

  /// What left the account: the amount plus any fee.
  Money get total => amount + (fee ?? const Money.zero());

  /// Rebuilds the receipt for a transfer, so history can re-open or re-export
  /// it. Null for seeded entries, which never had one.
  TransferReceipt? toReceipt(int userId) {
    if (!isTransfer) return null;
    return TransferReceipt(
      userId: userId,
      recipientName: name,
      bankName: bankName ?? '',
      bankImage: image,
      accountNumber: accountNumber ?? '',
      sourceAccountId: sourceAccountId ?? '',
      sourceAccountName: sourceAccountName ?? '',
      nominal: amount,
      adminFee: fee ?? const Money.zero(),
      transactionType: transactionType ?? '',
      reference: reference!,
      createdAt: date,
      note: note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        'price_idr': amount.toJson(),
        'image': image,
        if (bankName != null) 'bank_name': bankName,
        if (accountNumber != null) 'account_number': accountNumber,
        if (sourceAccountId != null) 'source_account_id': sourceAccountId,
        if (sourceAccountName != null)
          'source_account_name': sourceAccountName,
        if (reference != null) 'reference': reference,
        if (transactionType != null) 'transaction_type': transactionType,
        if (note != null) 'note': note,
        if (fee != null) 'fee': fee!.toJson(),
      };
}
