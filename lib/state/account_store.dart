import 'package:flutter/foundation.dart';
import 'package:newtronic_banking/data/model/balance_model.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/repository/repository.dart';

/// Why a debit could not go through.
enum DebitFailure {
  unknownAccount,
  notPositive,
  insufficientFunds,
}

/// The accounts the user holds, and the only place their balances change.
///
/// Routing every debit through one method is what lets the balance on Home
/// update the moment a transfer clears, rather than each screen keeping its own
/// copy and drifting.
class AccountStore extends ChangeNotifier {
  AccountStore(this._repository);

  final Repository _repository;

  List<Balances> _accounts = const [];
  bool _isLoaded = false;

  List<Balances> get accounts => List.unmodifiable(_accounts);
  bool get isLoaded => _isLoaded;

  Balances? byId(String id) {
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  Money get total => _accounts.fold(
        const Money.zero(),
        (sum, account) => sum + account.balance,
      );

  Future<void> load() async {
    _accounts = _repository.readAccounts();
    _isLoaded = true;
    notifyListeners();
  }

  /// Whether [amount] can leave [accountId] without going negative.
  bool canDebit(String accountId, Money amount) {
    final account = byId(accountId);
    if (account == null || amount.rupiah <= 0) return false;
    return account.balance >= amount;
  }

  /// Takes [amount] out of [accountId].
  ///
  /// Returns null on success, or the reason it was refused. Refusing rather
  /// than clamping means an overdraw surfaces as an error the caller has to
  /// handle, instead of a balance that silently stops at zero.
  Future<DebitFailure?> debit(String accountId, Money amount) async {
    final account = byId(accountId);
    if (account == null) return DebitFailure.unknownAccount;
    if (amount.rupiah <= 0) return DebitFailure.notPositive;
    if (account.balance < amount) return DebitFailure.insufficientFunds;

    _accounts = [
      for (final current in _accounts)
        if (current.id == accountId)
          current.copyWith(balance: current.balance - amount)
        else
          current,
    ];

    await _repository.writeAccounts(_accounts);
    notifyListeners();
    return null;
  }

  /// Puts [amount] back into [accountId] — used to undo a transfer whose
  /// record could not be written.
  Future<void> credit(String accountId, Money amount) async {
    if (byId(accountId) == null || amount.rupiah <= 0) return;

    _accounts = [
      for (final current in _accounts)
        if (current.id == accountId)
          current.copyWith(balance: current.balance + amount)
        else
          current,
    ];

    await _repository.writeAccounts(_accounts);
    notifyListeners();
  }
}
