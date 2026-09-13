import 'package:flutter/foundation.dart';
import 'package:newtronic_banking/data/model/transaction_model.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/state/account_store.dart';
import 'package:newtronic_banking/state/transaction_store.dart';

/// Why a transfer did not go through.
enum TransferFailure {
  /// The source account is gone — it was chosen, then removed.
  unknownAccount,

  /// The amount was zero or negative.
  notPositive,

  /// The account does not hold the amount plus the fee.
  insufficientFunds,

  /// The money moved but the history entry could not be written; the debit was
  /// rolled back.
  couldNotRecord;

  String get message => switch (this) {
        TransferFailure.unknownAccount =>
          'That account is no longer available.',
        TransferFailure.notPositive =>
          'Enter an amount greater than zero.',
        TransferFailure.insufficientFunds =>
          'Not enough balance for this transfer plus the fee.',
        TransferFailure.couldNotRecord =>
          'The transfer could not be recorded. Nothing was taken from your '
              'account.',
      };
}

/// The outcome of [TransferService.execute].
class TransferOutcome {
  const TransferOutcome.success() : failure = null;
  const TransferOutcome.failed(this.failure);

  final TransferFailure? failure;

  bool get isSuccess => failure == null;
}

/// Moves money.
///
/// A transfer spans two stores — the balance comes down in [AccountStore] and
/// the record goes into [TransactionStore] — so it lives here rather than in
/// either one. Doing it in the screen would mean every caller had to remember
/// the ordering and the rollback.
class TransferService {
  const TransferService({
    required AccountStore accounts,
    required TransactionStore transactions,
  })  : _accounts = accounts,
        _transactions = transactions;

  final AccountStore _accounts;
  final TransactionStore _transactions;

  /// Debits the source account by the amount plus the fee, then records it.
  ///
  /// If the record cannot be written the debit is put back, so a failure never
  /// leaves money missing with nothing to show for it. There is no real
  /// transaction to roll back to here — this is two sequential writes to a
  /// local store — so the compensation is explicit.
  Future<TransferOutcome> execute(TransferReceipt receipt) async {
    final debitFailure =
        await _accounts.debit(receipt.sourceAccountId, receipt.total);

    if (debitFailure != null) {
      return TransferOutcome.failed(switch (debitFailure) {
        DebitFailure.unknownAccount => TransferFailure.unknownAccount,
        DebitFailure.notPositive => TransferFailure.notPositive,
        DebitFailure.insufficientFunds => TransferFailure.insufficientFunds,
      });
    }

    try {
      await _transactions.add(Transactions.fromReceipt(receipt));
    } catch (error, stackTrace) {
      debugPrint('TransferService: could not record transfer: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _accounts.credit(receipt.sourceAccountId, receipt.total);
      return const TransferOutcome.failed(TransferFailure.couldNotRecord);
    }

    return const TransferOutcome.success();
  }
}
