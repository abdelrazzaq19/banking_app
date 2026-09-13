import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/data/analytics/spending_analytics.dart';
import 'package:newtronic_banking/data/analytics/spending_category.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/model/transaction_model.dart';

import 'support/test_harness.dart';

/// A plain history entry — a subscription, a shop, whatever [name] suggests.
Transactions _entry({
  required String id,
  required String name,
  required DateTime date,
  required int amount,
}) =>
    Transactions(
      id: id,
      name: name,
      date: date,
      amount: Money(amount),
      image: '',
    );

/// A transfer the user made, which carries a fee.
Transactions _transfer({
  required String id,
  required String name,
  required DateTime date,
  required int amount,
  int fee = 2500,
}) =>
    Transactions(
      id: id,
      name: name,
      date: date,
      amount: Money(amount),
      image: '',
      bankName: 'Bank Mandiri',
      reference: id,
      fee: Money(fee),
    );

final _now = DateTime(2026, 9, 15);
final _thisMonth = DateTime(2026, 9, 3);
final _lastMonth = DateTime(2026, 8, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('monthly totals', () {
    test('sums the current and previous months separately', () {
      final summary = SpendingAnalytics.summarise(
        transactions: [
          _entry(id: '1', name: 'Netflix', date: _thisMonth, amount: 100000),
          _entry(id: '2', name: 'Spotify', date: _thisMonth, amount: 50000),
          _entry(id: '3', name: 'Netflix', date: _lastMonth, amount: 200000),
        ],
        now: _now,
      );

      expect(summary.currentMonthTotal.rupiah, 150000);
      expect(summary.previousMonthTotal.rupiah, 200000);
    });

    test('counts the fee as part of what was spent', () {
      final summary = SpendingAnalytics.summarise(
        transactions: [
          _transfer(id: 't1', name: 'Siti', date: _thisMonth, amount: 250000),
        ],
        now: _now,
      );

      // 250.000 left the account plus the 2.500 fee.
      expect(summary.currentMonthTotal.rupiah, 252500);
    });

    test('covers a fixed window, including months with nothing in them', () {
      final summary = SpendingAnalytics.summarise(
        transactions: [
          _entry(id: '1', name: 'Netflix', date: _thisMonth, amount: 100000),
        ],
        now: _now,
      );

      expect(summary.months, hasLength(6));
      // A quiet month still holds a place on the axis.
      expect(summary.months.where((m) => m.total.isZero), hasLength(5));
      expect(summary.months.last.total.rupiah, 100000);
    });

    test('returns months oldest first', () {
      final summary = SpendingAnalytics.summarise(
        transactions: const [],
        now: _now,
      );
      final dates = summary.months.map((m) => m.month).toList();

      expect(dates, orderedEquals(dates.toList()..sort()));
      expect(dates.last, DateTime(2026, 9));
      expect(dates.first, DateTime(2026, 4));
    });

    test('ignores anything older than the window', () {
      final summary = SpendingAnalytics.summarise(
        transactions: [
          _entry(
            id: 'old',
            name: 'Netflix',
            date: DateTime(2025, 1, 1),
            amount: 999000,
          ),
        ],
        now: _now,
      );

      expect(summary.months.every((m) => m.total.isZero), isTrue);
      expect(summary.currentMonthTotal.isZero, isTrue);
    });
  });

  group('month over month', () {
    test('reports the fraction of change', () {
      final summary = SpendingAnalytics.summarise(
        transactions: [
          _entry(id: '1', name: 'Shop', date: _thisMonth, amount: 150000),
          _entry(id: '2', name: 'Shop', date: _lastMonth, amount: 100000),
        ],
        now: _now,
      );

      expect(summary.monthOverMonthChange, closeTo(0.5, 0.0001));
    });

    test('is negative when spending fell', () {
      final summary = SpendingAnalytics.summarise(
        transactions: [
          _entry(id: '1', name: 'Shop', date: _thisMonth, amount: 50000),
          _entry(id: '2', name: 'Shop', date: _lastMonth, amount: 100000),
        ],
        now: _now,
      );

      expect(summary.monthOverMonthChange, closeTo(-0.5, 0.0001));
    });

    test('is null when last month was zero, rather than infinity', () {
      // "Up from nothing" has no percentage; reporting one would be a lie.
      final summary = SpendingAnalytics.summarise(
        transactions: [
          _entry(id: '1', name: 'Shop', date: _thisMonth, amount: 50000),
        ],
        now: _now,
      );

      expect(summary.monthOverMonthChange, isNull);
    });
  });

  group('categories', () {
    test('guesses from the payee', () {
      final summary = SpendingAnalytics.summarise(
        transactions: [
          _entry(id: '1', name: 'Netflix', date: _thisMonth, amount: 100000),
          _entry(id: '2', name: 'Warung Padang', date: _thisMonth, amount: 40000),
          _entry(id: '3', name: 'Tokopedia', date: _thisMonth, amount: 60000),
        ],
        now: _now,
      );

      final byCategory = {
        for (final entry in summary.categories) entry.category: entry.total.rupiah,
      };
      expect(byCategory[SpendingCategory.subscriptions], 100000);
      expect(byCategory[SpendingCategory.food], 40000);
      expect(byCategory[SpendingCategory.shopping], 60000);
    });

    test('a subscription beats a shopping keyword in the same name', () {
      // "Amazon Prime" is a subscription, not shopping, even though "amazon"
      // is a shopping keyword.
      final transaction =
          _entry(id: '1', name: 'Amazon Prime', date: _thisMonth, amount: 1);
      expect(CategoryGuesser.guess(transaction),
          SpendingCategory.subscriptions);
    });

    test('a transfer is a transfer whatever the payee is called', () {
      final transaction =
          _transfer(id: 't1', name: 'Netflix', date: _thisMonth, amount: 1);
      expect(CategoryGuesser.guess(transaction), SpendingCategory.transfers);
    });

    test('an unrecognised payee falls into other', () {
      final transaction = _entry(
          id: '1', name: 'Zzz Unknown Ltd', date: _thisMonth, amount: 1);
      expect(CategoryGuesser.guess(transaction), SpendingCategory.other);
    });

    test('an override wins over the guess', () {
      final summary = SpendingAnalytics.summarise(
        transactions: [
          _entry(id: '1', name: 'Netflix', date: _thisMonth, amount: 100000),
        ],
        now: _now,
        overrides: {'1': SpendingCategory.bills},
      );

      expect(summary.categories.single.category, SpendingCategory.bills);
    });

    test('ranks largest first and shares sum to one', () {
      final summary = SpendingAnalytics.summarise(
        transactions: [
          _entry(id: '1', name: 'Netflix', date: _thisMonth, amount: 25000),
          _entry(id: '2', name: 'Tokopedia', date: _thisMonth, amount: 75000),
        ],
        now: _now,
      );

      expect(summary.categories.first.category, SpendingCategory.shopping);
      expect(summary.categories.first.share, closeTo(0.75, 0.0001));
      expect(
        summary.categories.fold<double>(0, (sum, c) => sum + c.share),
        closeTo(1.0, 0.0001),
      );
    });

    test('only covers the current month', () {
      final summary = SpendingAnalytics.summarise(
        transactions: [
          _entry(id: '1', name: 'Netflix', date: _lastMonth, amount: 100000),
        ],
        now: _now,
      );

      expect(summary.categories, isEmpty);
    });

    test('shares are zero rather than NaN when nothing was spent', () {
      final summary = SpendingAnalytics.summarise(
        transactions: const [],
        now: _now,
      );

      expect(summary.categories, isEmpty);
      expect(summary.currentMonthTotal.isZero, isTrue);
    });
  });

  group('budget', () {
    SpendingSummary withBudget(int spent, int? limit) =>
        SpendingAnalytics.summarise(
          transactions: [
            if (spent > 0)
              _entry(id: '1', name: 'Shop', date: _thisMonth, amount: spent),
          ],
          now: _now,
          budget: limit == null ? null : Money(limit),
        );

    test('no limit means no status', () {
      expect(withBudget(500000, null).status, BudgetStatus.none);
    });

    test('under 80% is on track', () {
      expect(withBudget(700000, 1000000).status, BudgetStatus.onTrack);
    });

    test('80% is where the warning starts', () {
      expect(withBudget(799999, 1000000).status, BudgetStatus.onTrack);
      expect(withBudget(800000, 1000000).status, BudgetStatus.approaching);
    });

    test('exactly the limit is not yet over', () {
      expect(withBudget(1000000, 1000000).status, BudgetStatus.approaching);
      expect(withBudget(1000001, 1000000).status, BudgetStatus.exceeded);
    });

    test('approaching and exceeded both want attention', () {
      expect(withBudget(850000, 1000000).status.needsAttention, isTrue);
      expect(withBudget(1200000, 1000000).status.needsAttention, isTrue);
      expect(withBudget(100000, 1000000).status.needsAttention, isFalse);
    });

    test('the meter fills but does not overflow', () {
      expect(withBudget(500000, 1000000).budgetUsed, closeTo(0.5, 0.0001));
      // Overspending fills the track; the status carries the overspend.
      expect(withBudget(2000000, 1000000).budgetUsed, 1.0);
    });

    test('remaining goes negative when overspent', () {
      expect(withBudget(1200000, 1000000).remainingBudget.rupiah, -200000);
      expect(withBudget(1200000, 1000000).remainingBudget.isNegative, isTrue);
      expect(withBudget(400000, 1000000).remainingBudget.rupiah, 600000);
    });

    test('a zero limit is treated as no limit, not as instant overspend', () {
      expect(withBudget(1000, 0).status, BudgetStatus.none);
      expect(withBudget(1000, 0).budgetUsed, 0);
    });
  });

  group('empty history', () {
    test('is distinguishable from a quiet month', () {
      final nothing =
          SpendingAnalytics.summarise(transactions: const [], now: _now);
      final quiet = SpendingAnalytics.summarise(
        transactions: [
          _entry(id: '1', name: 'Shop', date: _lastMonth, amount: 1000),
        ],
        now: _now,
      );

      expect(nothing.hasTransactions, isFalse);
      expect(quiet.hasTransactions, isTrue);
      expect(quiet.currentMonthTotal.isZero, isTrue);
    });
  });

  group('SpendingStore', () {
    test('starts with no budget and no overrides', () async {
      final backend = await createTestBackend();
      expect(backend.spending.monthlyLimit, isNull);
      expect(backend.spending.hasBudget, isFalse);
      expect(backend.spending.overrides, isEmpty);
    });

    test('a budget persists across a reload', () async {
      final backend = await createTestBackend();
      await backend.spending.setMonthlyLimit(const Money(2500000));

      final reopened = await createReloadedSpendingStore(backend);
      expect(reopened.monthlyLimit, const Money(2500000));
    });

    test('a non-positive limit clears the budget', () async {
      final backend = await createTestBackend();
      await backend.spending.setMonthlyLimit(const Money(2500000));

      await backend.spending.setMonthlyLimit(const Money(0));
      expect(backend.spending.monthlyLimit, isNull);

      await backend.spending.setMonthlyLimit(const Money(2500000));
      await backend.spending.setMonthlyLimit(null);
      expect(backend.spending.hasBudget, isFalse);
    });

    test('an override persists and can be cleared', () async {
      final backend = await createTestBackend();
      await backend.spending.setCategory('1', SpendingCategory.bills);

      final reopened = await createReloadedSpendingStore(backend);
      expect(reopened.overrides['1'], SpendingCategory.bills);

      await backend.spending.clearCategory('1');
      final afterClear = await createReloadedSpendingStore(backend);
      expect(afterClear.overrides.containsKey('1'), isFalse);
    });

    test('notifies listeners when the budget changes', () async {
      final backend = await createTestBackend();
      var notifications = 0;
      backend.spending.addListener(() => notifications++);

      await backend.spending.setMonthlyLimit(const Money(1000000));
      await backend.spending.setCategory('1', SpendingCategory.food);

      expect(notifications, 2);
    });
  });
}
