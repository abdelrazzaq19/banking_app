import 'package:newtronic_banking/data/analytics/spending_category.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/model/transaction_model.dart';

/// How a month's spending stands against the budget.
enum BudgetStatus {
  /// No limit set.
  none,

  /// Under 80% of the limit.
  onTrack,

  /// 80% or more, but not over.
  approaching,

  /// Over the limit.
  exceeded;

  /// Whether this state warrants a warning treatment.
  bool get needsAttention =>
      this == BudgetStatus.approaching || this == BudgetStatus.exceeded;
}

/// One month's total.
class MonthlySpend {
  const MonthlySpend({required this.month, required this.total});

  /// The first day of the month, so months compare and sort by date.
  final DateTime month;
  final Money total;
}

/// One category's share of a period.
class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.total,
    required this.share,
  });

  final SpendingCategory category;
  final Money total;

  /// 0 to 1. Zero when the period total is zero, rather than NaN.
  final double share;
}

/// Everything the Tracker tab shows, computed from stored transactions.
class SpendingSummary {
  const SpendingSummary({
    required this.months,
    required this.categories,
    required this.currentMonthTotal,
    required this.previousMonthTotal,
    required this.budget,
    required this.hasTransactions,
  });

  /// Oldest first, one entry per month in the window — including months with
  /// nothing in them, so the chart has an even time axis rather than skipping
  /// quiet months.
  final List<MonthlySpend> months;

  /// The current month's categories, largest first.
  final List<CategorySpend> categories;

  final Money currentMonthTotal;
  final Money previousMonthTotal;
  final Money? budget;

  /// False when there is nothing at all to summarise — which is a different
  /// situation from a month that happens to be empty.
  final bool hasTransactions;

  /// Change against last month, as a fraction. `0.25` is a quarter more spent.
  ///
  /// Null when last month was zero: "up from nothing" has no percentage, and
  /// showing infinity or 100% would both be lies.
  double? get monthOverMonthChange {
    if (previousMonthTotal.isZero) return null;
    final difference = currentMonthTotal.rupiah - previousMonthTotal.rupiah;
    return difference / previousMonthTotal.rupiah;
  }

  Money get remainingBudget {
    final limit = budget;
    if (limit == null) return const Money.zero();
    return limit - currentMonthTotal;
  }

  /// How much of the limit is used, 0 to 1 for the meter. Clamped at 1 so an
  /// overspend fills the track rather than overflowing it; [status] carries
  /// the fact that it went over.
  double get budgetUsed {
    final limit = budget;
    if (limit == null || limit.rupiah <= 0) return 0;
    final ratio = currentMonthTotal.rupiah / limit.rupiah;
    return ratio.clamp(0.0, 1.0);
  }

  BudgetStatus get status {
    final limit = budget;
    if (limit == null || limit.rupiah <= 0) return BudgetStatus.none;
    if (currentMonthTotal > limit) return BudgetStatus.exceeded;
    if (currentMonthTotal.rupiah / limit.rupiah >= 0.8) {
      return BudgetStatus.approaching;
    }
    return BudgetStatus.onTrack;
  }
}

/// Turns stored transactions into the Tracker tab's numbers.
///
/// Pure functions over data that is passed in — no store, no clock of its own —
/// so every figure on the screen can be asserted directly.
abstract final class SpendingAnalytics {
  /// How many months the trend chart covers.
  static const int defaultMonthWindow = 6;

  static DateTime monthOf(DateTime date) => DateTime(date.year, date.month);

  /// What a transaction took out of the account: the amount plus any fee.
  static Money spendOf(Transactions transaction) => transaction.total;

  static SpendingSummary summarise({
    required List<Transactions> transactions,
    required DateTime now,
    Map<String, SpendingCategory> overrides = const {},
    Money? budget,
    int monthWindow = defaultMonthWindow,
  }) {
    final thisMonth = monthOf(now);
    final lastMonth = DateTime(now.year, now.month - 1);

    // A fixed window of months, each starting at zero, so a month with no
    // spending still appears on the axis.
    final totalsByMonth = <DateTime, int>{
      for (var back = monthWindow - 1; back >= 0; back--)
        DateTime(now.year, now.month - back): 0,
    };

    final totalsByCategory = <SpendingCategory, int>{};
    var currentTotal = 0;
    var previousTotal = 0;

    for (final transaction in transactions) {
      final amount = spendOf(transaction).rupiah;
      final month = monthOf(transaction.date);

      if (totalsByMonth.containsKey(month)) {
        totalsByMonth[month] = totalsByMonth[month]! + amount;
      }

      if (month == thisMonth) {
        currentTotal += amount;
        final category = overrides[transaction.id] ??
            CategoryGuesser.guess(transaction);
        totalsByCategory[category] =
            (totalsByCategory[category] ?? 0) + amount;
      } else if (month == lastMonth) {
        previousTotal += amount;
      }
    }

    final months = totalsByMonth.entries
        .map((entry) => MonthlySpend(
              month: entry.key,
              total: Money(entry.value),
            ))
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));

    final categories = totalsByCategory.entries
        .map((entry) => CategorySpend(
              category: entry.key,
              total: Money(entry.value),
              share: currentTotal == 0 ? 0 : entry.value / currentTotal,
            ))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return SpendingSummary(
      months: months,
      categories: categories,
      currentMonthTotal: Money(currentTotal),
      previousMonthTotal: Money(previousTotal),
      budget: budget,
      hasTransactions: transactions.isNotEmpty,
    );
  }
}
