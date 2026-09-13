import 'package:flutter/foundation.dart';
import 'package:newtronic_banking/data/analytics/spending_category.dart';
import 'package:newtronic_banking/data/local/local_store.dart';
import 'package:newtronic_banking/data/model/money.dart';

/// The monthly budget and any hand-corrected categories.
///
/// Kept apart from the transactions themselves: a category the user corrected
/// is an opinion about a record, not part of it, and the records are rewritten
/// wholesale whenever one is added.
class SpendingStore extends ChangeNotifier {
  SpendingStore(this._store);

  static const String _limitField = 'monthlyLimit';
  static const String _overridesField = 'categories';

  final LocalStore _store;

  Money? _monthlyLimit;
  Map<String, SpendingCategory> _overrides = const {};
  bool _isLoaded = false;

  Money? get monthlyLimit => _monthlyLimit;
  Map<String, SpendingCategory> get overrides => Map.unmodifiable(_overrides);
  bool get isLoaded => _isLoaded;
  bool get hasBudget => _monthlyLimit != null && _monthlyLimit!.rupiah > 0;

  Future<void> load() async {
    final saved = _store.readDocument(StoreKeys.budget);

    final limit = saved?[_limitField];
    _monthlyLimit = limit == null ? null : Money.parse(limit);

    final stored = saved?[_overridesField];
    _overrides = stored is Map
        ? {
            for (final entry in stored.entries)
              entry.key as String:
                  SpendingCategory.fromName(entry.value as String?),
          }
        : const {};

    _isLoaded = true;
    notifyListeners();
  }

  /// Sets the monthly limit. Passing null, or a non-positive amount, clears it.
  Future<void> setMonthlyLimit(Money? limit) async {
    _monthlyLimit = (limit == null || limit.rupiah <= 0) ? null : limit;
    await _persist();
    notifyListeners();
  }

  /// Overrides the guessed category for one transaction.
  Future<void> setCategory(String transactionId, SpendingCategory category) async {
    _overrides = {..._overrides, transactionId: category};
    await _persist();
    notifyListeners();
  }

  /// Drops an override, putting the transaction back on the guess.
  Future<void> clearCategory(String transactionId) async {
    final next = {..._overrides}..remove(transactionId);
    _overrides = next;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() => _store.writeDocument(StoreKeys.budget, {
        if (_monthlyLimit != null) _limitField: _monthlyLimit!.toJson(),
        _overridesField: {
          for (final entry in _overrides.entries) entry.key: entry.value.name,
        },
      });
}
