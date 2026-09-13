import 'package:newtronic_banking/data/model/favourite_transfer.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/qr/qris_payload.dart';

/// Values the transfer form should open with.
///
/// Two things now prefill the form — a saved recipient and a scanned payment
/// code — and they are not the same thing: a favourite is something the user
/// chose to keep, a code is something they were handed a moment ago. Passing
/// a `FavouriteTransfer` for a scanned code would have meant either
/// fabricating an id and a created-at for a payee nobody saved, or letting the
/// form quietly treat a stranger's code as a trusted entry.
class TransferPrefill {
  const TransferPrefill({
    required this.recipientName,
    required this.bankName,
    required this.accountNumber,
    this.bankImage = '',
    this.amount,
    this.transactionType,
    this.note,
    this.isAmountFixed = false,
  });

  factory TransferPrefill.fromFavourite(FavouriteTransfer favourite) =>
      TransferPrefill(
        recipientName: favourite.recipientName,
        bankName: favourite.bankName,
        bankImage: favourite.bankImage,
        accountNumber: favourite.accountNumber,
        amount: favourite.amount,
        transactionType: favourite.transactionType,
        note: favourite.note,
      );

  /// A payment code the user scanned or pasted.
  ///
  /// [isAmountFixed] carries over so the form can show that the amount came
  /// from the code rather than from the user — a payee who asked for a
  /// specific sum should not have it silently edited.
  factory TransferPrefill.fromQris(QrisPayload payload) => TransferPrefill(
        recipientName: payload.recipientName,
        bankName: payload.bankName,
        accountNumber: payload.accountNumber,
        amount: payload.amount,
        note: payload.note,
        isAmountFixed: payload.isDynamic,
      );

  final String recipientName;
  final String bankName;
  final String bankImage;
  final String accountNumber;
  final Money? amount;
  final String? transactionType;
  final String? note;
  final bool isAmountFixed;
}

/// Route arguments for the transfer form.
///
/// The form used to take a bare user id. Prefilling from a saved recipient
/// needs more than that, and a typed argument keeps the route from growing a
/// positional tuple nobody can read at the call site.
class TransferArgs {
  const TransferArgs({required this.userId, this.prefill});

  final int userId;

  /// When present, the form opens already filled in.
  final TransferPrefill? prefill;
}
