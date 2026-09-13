import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/data/analytics/spending_category.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/model/transaction_model.dart';
import 'package:newtronic_banking/presentation/screen/main/tracker_tab.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

import 'support/test_harness.dart';

final _now = DateTime(2026, 9, 15);

Transactions _entry({
  required String id,
  required String name,
  required int amount,
  DateTime? date,
}) =>
    Transactions(
      id: id,
      name: name,
      date: date ?? DateTime(2026, 9, 3),
      amount: Money(amount),
      image: '',
    );

Future<TestBackend> _pumpTracker(
  WidgetTester tester, {
  List<Transactions>? history,
  Money? budget,
}) async {
  useMobileSurface(tester, size: const Size(430, 1400));
  final backend = await createTestBackend();

  // Replace the seeded history with a known set, so the assertions are about
  // arithmetic rather than about whatever the seed file happens to hold.
  await backend.repository.writeTransactions(history ?? const []);
  await backend.transactions.load();
  if (budget != null) await backend.spending.setMonthlyLimit(budget);

  await tester.pumpWidget(
    wrapWithBackend(backend, child: Scaffold(body: TrackerTab(now: _now))),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return backend;
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  testWidgets('an empty history gets a real empty state', (tester) async {
    await _pumpTracker(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Nothing to track yet'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('renders the trend chart from stored transactions',
      (tester) async {
    await _pumpTracker(tester, history: [
      _entry(id: '1', name: 'Netflix', amount: 100000),
    ]);

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('Last 6 months'), findsOneWidget);
  });

  testWidgets('shows the month total and the category breakdown',
      (tester) async {
    await _pumpTracker(tester, history: [
      _entry(id: '1', name: 'Netflix', amount: 100000),
      _entry(id: '2', name: 'Tokopedia', amount: 300000),
    ]);

    expect(find.text('Rp 400.000'), findsWidgets);
    // Each category appears twice: once in the ranked breakdown, once as the
    // label on the transaction it was filed under.
    expect(find.text('Shopping'), findsWidgets);
    expect(find.text('Subscriptions'), findsWidgets);
    // Ranked largest first: shopping is 75%.
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
  });

  group('budget', () {
    testWidgets('prompts to set one when there is none', (tester) async {
      await _pumpTracker(tester, history: [
        _entry(id: '1', name: 'Netflix', amount: 100000),
      ]);

      expect(find.text('No budget set'), findsOneWidget);
      expect(find.text('Set budget'), findsOneWidget);
    });

    testWidgets('says on track while comfortably under', (tester) async {
      await _pumpTracker(
        tester,
        history: [_entry(id: '1', name: 'Netflix', amount: 100000)],
        budget: const Money(1000000),
      );

      expect(find.text('On track'), findsOneWidget);
      expect(find.text('Rp 900.000 left'), findsOneWidget);
    });

    testWidgets('warns clearly when the limit is exceeded', (tester) async {
      await _pumpTracker(
        tester,
        history: [_entry(id: '1', name: 'Tokopedia', amount: 1200000)],
        budget: const Money(1000000),
      );

      // The warning is a label and an icon, not colour alone.
      expect(find.text('Over your limit'), findsOneWidget);
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
      expect(find.text('Rp 200.000 over'), findsOneWidget);
    });

    testWidgets('setting a budget persists it', (tester) async {
      final backend = await _pumpTracker(tester, history: [
        _entry(id: '1', name: 'Netflix', amount: 100000),
      ]);

      await tester.tap(find.text('Set budget'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Amount'), '2000000');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Save budget'));
      await tester.pumpAndSettle();

      expect(backend.spending.monthlyLimit, const Money(2000000));
      final reloaded = await createReloadedSpendingStore(backend);
      expect(reloaded.monthlyLimit, const Money(2000000));
    });
  });

  group('category override', () {
    testWidgets('a transaction can be refiled, and it sticks', (tester) async {
      final backend = await _pumpTracker(tester, history: [
        _entry(id: '1', name: 'Netflix', amount: 100000),
      ]);

      // Guessed as a subscription from the payee.
      expect(find.text('Subscriptions'), findsWidgets);

      await tester.tap(find.text('Netflix').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bills & utilities').last);
      await tester.pumpAndSettle();

      expect(backend.spending.overrides['1'], SpendingCategory.bills);
      expect(find.text('Bills & utilities'), findsWidgets);
      expect(find.text('Subscriptions'), findsNothing);

      final reloaded = await createReloadedSpendingStore(backend);
      expect(reloaded.overrides['1'], SpendingCategory.bills);
    });

    testWidgets('the override can be reverted to the guess', (tester) async {
      final backend = await _pumpTracker(tester, history: [
        _entry(id: '1', name: 'Netflix', amount: 100000),
      ]);

      await tester.tap(find.text('Netflix').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bills & utilities').last);
      await tester.pumpAndSettle();
      expect(backend.spending.overrides['1'], SpendingCategory.bills);

      await tester.tap(find.text('Netflix').last);
      await tester.pumpAndSettle();
      await tester.tap(
          find.widgetWithText(AppButton, 'Use the automatic guess'));
      await tester.pumpAndSettle();

      expect(backend.spending.overrides.containsKey('1'), isFalse);
      expect(find.text('Subscriptions'), findsWidgets);
    });
  });

  testWidgets('renders in dark mode without losing its labels',
      (tester) async {
    useMobileSurface(tester, size: const Size(430, 1400));
    final backend = await createTestBackend();
    await backend.repository.writeTransactions([
      _entry(id: '1', name: 'Netflix', amount: 100000),
      _entry(id: '2', name: 'Tokopedia', amount: 300000),
    ]);
    await backend.transactions.load();

    await tester.pumpWidget(wrapWithBackend(
      backend,
      themeMode: ThemeMode.dark,
      child: Scaffold(body: TrackerTab(now: _now)),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Identity never rests on colour alone, so the labels are the check.
    expect(find.text('Shopping'), findsWidgets);
    expect(find.text('Subscriptions'), findsWidgets);
    expect(find.byType(BarChart), findsOneWidget);
  });
}
