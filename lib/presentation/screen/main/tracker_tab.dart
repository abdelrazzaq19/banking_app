import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/analytics/spending_analytics.dart';
import 'package:newtronic_banking/data/analytics/spending_category.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/utils/currency_input_formatter.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';
import 'package:newtronic_banking/state/spending_store.dart';
import 'package:newtronic_banking/state/transaction_store.dart';
import 'package:provider/provider.dart';

/// Spending analytics over the stored history.
///
/// Chart choices follow the data's job rather than decoration: the budget is a
/// ratio against a limit, so it is a meter and not a two-slice pie; the trend
/// is magnitude over time, so it is a column chart in a single hue with no
/// legend; the breakdown is part-to-whole, so it is a horizontal composition
/// bar paired with a ranked, labelled list rather than a donut — a donut makes
/// close values genuinely hard to compare.
class TrackerTab extends StatelessWidget {
  const TrackerTab({super.key, this.now});

  /// Injectable so tests can pin "this month" instead of depending on the date
  /// the suite happens to run.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final transactions = context.watch<TransactionStore>();
    final spending = context.watch<SpendingStore>();

    final summary = SpendingAnalytics.summarise(
      transactions: transactions.transactions,
      now: now ?? DateTime.now(),
      overrides: spending.overrides,
      budget: spending.monthlyLimit,
    );

    if (!summary.hasTransactions) {
      return const EmptyState(
        icon: Icons.insights_rounded,
        title: 'Nothing to track yet',
        message: 'Once you have some activity, your spending by month and '
            'category will appear here.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.lg,
        Insets.lg,
        Insets.xxxl,
      ),
      children: staggeredReveal([
        _BudgetMeter(summary: summary),
        const SizedBox(height: Insets.lg),
        _MonthTotals(summary: summary),
        const SizedBox(height: Insets.xl),
        const SectionHeader(
          title: 'Last 6 months',
          padding: EdgeInsets.only(bottom: Insets.sm),
        ),
        _MonthlyTrend(summary: summary),
        const SizedBox(height: Insets.xl),
        const SectionHeader(
          title: 'This month by category',
          padding: EdgeInsets.only(bottom: Insets.sm),
        ),
        _CategoryBreakdown(summary: summary),
        const SizedBox(height: Insets.xl),
        const SectionHeader(
          title: 'This month',
          padding: EdgeInsets.only(bottom: Insets.sm),
        ),
        _MonthTransactions(now: now ?? DateTime.now()),
      ]),
    );
  }
}

/// A ratio against a limit: a meter, with the status carried by an icon and a
/// label as well as colour.
class _BudgetMeter extends StatelessWidget {
  const _BudgetMeter({required this.summary});

  final SpendingSummary summary;

  ({Color tint, IconData icon, String label}) _statusOf(BuildContext context) {
    final colors = context.colors;
    return switch (summary.status) {
      BudgetStatus.none => (
          tint: colors.subtleText,
          icon: Icons.flag_outlined,
          label: 'No budget set',
        ),
      BudgetStatus.onTrack => (
          tint: colors.success,
          icon: Icons.check_circle_rounded,
          label: 'On track',
        ),
      BudgetStatus.approaching => (
          tint: colors.warning,
          icon: Icons.warning_amber_rounded,
          label: 'Close to your limit',
        ),
      BudgetStatus.exceeded => (
          tint: context.scheme.error,
          icon: Icons.error_rounded,
          label: 'Over your limit',
        ),
    };
  }

  Future<void> _editBudget(BuildContext context) async {
    final store = context.read<SpendingStore>();
    final result = await showBudgetSheet(context, current: store.monthlyLimit);
    if (result == null) return;
    await store.setMonthlyLimit(result.limit);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final status = _statusOf(context);
    final budget = summary.budget;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: colors.mutedFill,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(status.icon, size: 18, color: status.tint),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: Text(
                  status.label,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: status.tint),
                ),
              ),
              TextButton(
                onPressed: () => _editBudget(context),
                child: Text(budget == null ? 'Set budget' : 'Edit'),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          Text(
            summary.currentMonthTotal.formattedWithSymbol,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          Text(
            budget == null
                ? 'spent this month'
                : 'of ${budget.formattedWithSymbol} this month',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.subtleText),
          ),
          if (budget != null) ...[
            const SizedBox(height: Insets.sm),
            // A same-ramp track: the fill is the status colour, the track is
            // the surface behind it.
            ClipRRect(
              borderRadius: BorderRadius.circular(Insets.xxs),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: summary.budgetUsed),
                duration: Motion.slow,
                curve: Motion.enter,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: colors.mutedBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(status.tint),
                ),
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              summary.remainingBudget.isNegative
                  ? '${(-summary.remainingBudget).formattedWithSymbol} over'
                  : '${summary.remainingBudget.formattedWithSymbol} left',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: status.tint),
            ),
          ],
        ],
      ),
    );
  }
}

/// Two headline numbers, and the change between them.
class _MonthTotals extends StatelessWidget {
  const _MonthTotals({required this.summary});

  final SpendingSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final change = summary.monthOverMonthChange;

    final String deltaLabel;
    final Color deltaTint;
    final IconData? deltaIcon;

    if (change == null) {
      deltaLabel = summary.previousMonthTotal.isZero &&
              summary.currentMonthTotal.isZero
          ? 'No spending either month'
          : 'Nothing spent last month';
      deltaTint = colors.subtleText;
      deltaIcon = null;
    } else {
      final percent = (change.abs() * 100).round();
      final isUp = change > 0;
      deltaLabel = isUp
          ? '$percent% more than last month'
          : '$percent% less than last month';
      // Spending more is not an error, so this is not the error colour; it is
      // simply the direction worth noticing.
      deltaTint = isUp ? colors.warning : colors.success;
      deltaIcon = isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    }

    return Row(
      children: [
        if (deltaIcon != null) ...[
          Icon(deltaIcon, size: 18, color: deltaTint),
          const SizedBox(width: Insets.xs),
        ],
        Expanded(
          child: Text(
            deltaLabel,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: deltaTint),
          ),
        ),
        Text(
          'was ${summary.previousMonthTotal.formattedWithSymbol}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colors.subtleText),
        ),
      ],
    );
  }
}

/// Magnitude over time: one series, one hue, no legend — the heading names it.
class _MonthlyTrend extends StatelessWidget {
  const _MonthlyTrend({required this.summary});

  final SpendingSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;
    final months = summary.months;

    final highest = months.fold<int>(
      0,
      (peak, month) => month.total.rupiah > peak ? month.total.rupiah : peak,
    );
    // A flat zero axis would make every bar full height; give it a headroom.
    final maxY = (highest == 0 ? 1 : highest) * 1.2;

    return SizedBox(
      height: 180,
      child: Semantics(
        label: 'Spending for the last ${months.length} months. '
            '${months.map((m) => '${DateFormat.MMMM('id_ID').format(m.month)}: '
                '${m.total.formattedWithSymbol}').join('. ')}',
        child: ExcludeSemantics(
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              // Recessive: a horizontal rule per gridline, no vertical noise,
              // no chart border.
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 3,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: colors.mutedBorder,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= months.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: Insets.xs),
                        child: Text(
                          DateFormat.MMM('id_ID')
                              .format(months[index].month),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: colors.subtleText),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => scheme.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                    '${DateFormat.MMMM('id_ID').format(months[group.x].month)}\n'
                    '${months[group.x].total.formattedWithSymbol}',
                    Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: scheme.onInverseSurface,
                        ),
                  ),
                ),
              ),
              barGroups: [
                for (var index = 0; index < months.length; index++)
                  BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: months[index].total.rupiah.toDouble(),
                        width: 18,
                        // Rounded data-end, square against the baseline.
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        color: index == months.length - 1
                            ? scheme.primary
                            : scheme.primary.withValues(alpha: 0.45),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Part-to-whole: a horizontal composition bar, then the ranked list that
/// carries the labels.
///
/// The list is not decoration — three of the seven light-mode series colours
/// fall below 3:1 against white, and a labelled list is the relief that keeps
/// identity off colour alone.
class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.summary});

  final SpendingSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (summary.categories.isEmpty) {
      return const EmptyState(
        compact: true,
        icon: Icons.pie_chart_outline_rounded,
        title: 'Nothing spent this month',
        message: 'Categories appear once money moves.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Insets.xxs),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (var index = 0; index < summary.categories.length; index++)
                  Expanded(
                    // Flex needs whole numbers; scaling the share keeps the
                    // proportions without rounding a small slice to nothing.
                    flex: (summary.categories[index].share * 1000)
                        .round()
                        .clamp(1, 1000),
                    child: Padding(
                      // A 2px surface gap between segments, so neighbouring
                      // fills read as separate marks.
                      padding: EdgeInsets.only(
                        right:
                            index == summary.categories.length - 1 ? 0 : 2,
                      ),
                      child: ColoredBox(color: colors.seriesColor(index)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.md),
        for (var index = 0; index < summary.categories.length; index++)
          _CategoryRow(
            spend: summary.categories[index],
            tint: colors.seriesColor(index),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.spend, required this.tint});

  final CategorySpend spend;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final percent = (spend.share * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        children: [
          // The colour swatch carries identity beside the label; the label
          // carries it for anyone the colour does not reach.
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          const SizedBox(width: Insets.sm),
          Icon(spend.category.icon, size: 18, color: colors.subtleText),
          const SizedBox(width: Insets.xs),
          Expanded(
            child: Text(
              spend.category.label,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Insets.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                spend.total.formattedWithSymbol,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '$percent%',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colors.subtleText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// This month's transactions, each showing the category it was filed under.
///
/// The guess is a starting point, not a verdict — tapping a row reassigns it,
/// which is the only way a keyword guesser can be honest about being wrong.
class _MonthTransactions extends StatelessWidget {
  const _MonthTransactions({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spending = context.watch<SpendingStore>();
    final thisMonth = SpendingAnalytics.monthOf(now);

    final entries = context
        .watch<TransactionStore>()
        .transactions
        .where((transaction) =>
            SpendingAnalytics.monthOf(transaction.date) == thisMonth)
        .toList();

    if (entries.isEmpty) {
      return Text(
        'No transactions this month.',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: colors.subtleText),
      );
    }

    return Column(
      children: [
        for (final entry in entries)
          _TransactionCategoryRow(
            transactionId: entry.id,
            name: entry.name,
            amount: SpendingAnalytics.spendOf(entry),
            category: spending.overrides[entry.id] ??
                CategoryGuesser.guess(entry),
            isCorrected: spending.overrides.containsKey(entry.id),
          ),
      ],
    );
  }
}

class _TransactionCategoryRow extends StatelessWidget {
  const _TransactionCategoryRow({
    required this.transactionId,
    required this.name,
    required this.amount,
    required this.category,
    required this.isCorrected,
  });

  final String transactionId;
  final String name;
  final Money amount;
  final SpendingCategory category;
  final bool isCorrected;

  Future<void> _recategorise(BuildContext context) async {
    final store = context.read<SpendingStore>();
    final picked = await showCategoryPicker(
      context,
      current: category,
      payee: name,
    );
    if (picked == null) return;

    if (picked.isReset) {
      await store.clearCategory(transactionId);
    } else {
      await store.setCategory(transactionId, picked.category!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _recategorise(context),
        borderRadius: Radii.smAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.xs),
          child: Row(
            children: [
              Icon(category.icon, size: 18, color: colors.subtleText),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          category.label,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: colors.subtleText),
                        ),
                        if (isCorrected) ...[
                          const SizedBox(width: Insets.xxs),
                          Icon(
                            Icons.edit_rounded,
                            size: 11,
                            color: colors.subtleText,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.xs),
              Text(
                amount.formattedWithSymbol,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What [showCategoryPicker] resolves to.
class CategoryPickerResult {
  const CategoryPickerResult.pick(SpendingCategory this.category)
      : isReset = false;
  const CategoryPickerResult.reset()
      : category = null,
        isReset = true;

  final SpendingCategory? category;

  /// Put the transaction back on the automatic guess.
  final bool isReset;
}

/// Lets the user file one transaction under a different category.
Future<CategoryPickerResult?> showCategoryPicker(
  BuildContext context, {
  required SpendingCategory current,
  required String payee,
}) {
  return showModalBottomSheet<CategoryPickerResult>(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: Alphas.scrim),
    shape: const RoundedRectangleBorder(borderRadius: Radii.sheetTop),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            Text(
              'Category for $payee',
              style: Theme.of(sheetContext).textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Insets.md),
            for (final category in SpendingCategory.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(category.icon),
                title: Text(category.label),
                trailing: category == current
                    ? Icon(
                        Icons.check_rounded,
                        color: sheetContext.scheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext)
                    .pop(CategoryPickerResult.pick(category)),
              ),
            const SizedBox(height: Insets.xs),
            AppButton(
              label: 'Use the automatic guess',
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.of(sheetContext)
                  .pop(const CategoryPickerResult.reset()),
            ),
          ],
        ),
      ),
    ),
  );
}

/// What [showBudgetSheet] resolves to. A null [limit] means "no budget".
class BudgetSheetResult {
  const BudgetSheetResult(this.limit);
  final Money? limit;
}

/// Asks for a monthly spending limit.
Future<BudgetSheetResult?> showBudgetSheet(
  BuildContext context, {
  Money? current,
}) {
  return showModalBottomSheet<BudgetSheetResult>(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: Alphas.scrim),
    shape: const RoundedRectangleBorder(borderRadius: Radii.sheetTop),
    builder: (sheetContext) => _BudgetSheet(current: current),
  );
}

class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet({this.current});

  final Money? current;

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current == null ? '' : widget.current!.formatted,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = parseRupiah(_controller.text);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Insets.lg,
          right: Insets.lg,
          top: Insets.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + Insets.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            Text(
              'Monthly budget',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'You will be warned as you approach it, and told when you go '
              'over.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.colors.subtleText),
            ),
            const SizedBox(height: Insets.lg),
            AppTextField(
              controller: _controller,
              hintText: 'Amount',
              semanticLabel: 'Monthly budget amount in rupiah',
              autofocus: true,
              useTabularFigures: true,
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsSeparatorInputFormatter()],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Insets.lg),
            AppButton(
              label: 'Save budget',
              onPressed: amount == null || amount <= 0
                  ? null
                  : () => Navigator.of(context)
                      .pop(BudgetSheetResult(Money(amount))),
            ),
            if (widget.current != null) ...[
              const SizedBox(height: Insets.xs),
              AppButton(
                label: 'Remove budget',
                variant: AppButtonVariant.ghost,
                onPressed: () =>
                    Navigator.of(context).pop(const BudgetSheetResult(null)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
