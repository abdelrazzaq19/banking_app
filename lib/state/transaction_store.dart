import 'package:flutter/foundation.dart';
import 'package:newtronic_banking/data/model/transaction_model.dart';
import 'package:newtronic_banking/data/repository/repository.dart';

/// The activity history, newest first.
class TransactionStore extends ChangeNotifier {
  TransactionStore(this._repository);

  final Repository _repository;

  List<Transactions> _transactions = const [];
  bool _isLoaded = false;

  List<Transactions> get transactions => List.unmodifiable(_transactions);
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    _transactions = _repository.readTransactions();
    _isLoaded = true;
    notifyListeners();
  }

  /// The [count] most recent entries, for the summary on Home.
  List<Transactions> recent([int count = 4]) =>
      _transactions.take(count).toList();

  Future<void> add(Transactions transaction) async {
    _transactions = [transaction, ..._transactions];
    await _repository.writeTransactions(_transactions);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _transactions =
        _transactions.where((transaction) => transaction.id != id).toList();
    await _repository.writeTransactions(_transactions);
    notifyListeners();
  }

  /// Free-text search across the fields a user would actually search by:
  /// payee, bank, note, reference, account number and amount.
  ///
  /// An empty query returns everything, so callers can bind it straight to a
  /// search box without special-casing the initial state.
  List<Transactions> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return transactions;

    return _transactions.where((transaction) {
      return transaction.name.toLowerCase().contains(needle) ||
          (transaction.bankName?.toLowerCase().contains(needle) ?? false) ||
          (transaction.note?.toLowerCase().contains(needle) ?? false) ||
          (transaction.reference?.toLowerCase().contains(needle) ?? false) ||
          (transaction.accountNumber?.contains(needle) ?? false) ||
          // Both the grouped form the user sees and the raw digits, so
          // "250.000" and "250000" both find the same transfer.
          transaction.amount.formatted.contains(needle) ||
          transaction.amount.rupiah.toString().contains(needle);
    }).toList();
  }
}
