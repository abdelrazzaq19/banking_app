import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/presentation/screen/main/account_detail_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/home_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/tracker_tab.dart';
import 'package:newtronic_banking/presentation/screen/main/widgets/balance_card.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

import 'support/test_harness.dart';

Future<TestBackend> _pumpHome(WidgetTester tester, {int userId = 1}) async {
  useMobileSurface(tester, size: const Size(430, 1200));

  final backend = await createTestBackend();
  await tester.pumpWidget(
    wrapWithBackend(backend, child: HomeScreen(id: userId)),
  );
  await tester.pump();
  // Wait for the loaded state rather than guessing at a frame count.
  await pumpUntil(tester, find.byType(RefreshIndicator));
  return backend;
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  testWidgets('loads the signed-in user and greets them by first name',
      (tester) async {
    await _pumpHome(tester);

    // user.json's first user is John Doe.
    expect(find.text('John'), findsOneWidget);
  });

  testWidgets('renders a balance card carousel with dots', (tester) async {
    await _pumpHome(tester);

    expect(find.byType(BalanceCard), findsWidgets);
    expect(find.byType(PageDots), findsOneWidget);
    expect(find.text('BlueSky Account'), findsOneWidget);
  });

  testWidgets('formats the balance as rupiah rather than a raw string',
      (tester) async {
    await _pumpHome(tester);
    // Let the count-up animation finish.
    await tester.pump(const Duration(seconds: 1));

    // balance.json stores "5,000,000 " with a trailing space; the card must
    // show a properly formatted figure, not the raw value.
    expect(find.text('Rp 5.000.000'), findsOneWidget);
  });

  testWidgets('the card actions use the on-card variant', (tester) async {
    await _pumpHome(tester);

    final moveButton = tester.widget<AppButton>(
      find.ancestor(
        of: find.text('MOVE').first,
        matching: find.byType(AppButton),
      ),
    );
    expect(moveButton.variant, AppButtonVariant.onCard);
  });

  testWidgets('tapping a card opens its detail screen', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.byType(BalanceCard).first);
    await tester.pump();
    await pumpUntil(tester, find.byType(AccountDetailScreen));

    expect(find.byType(AccountDetailScreen), findsOneWidget);
    expect(find.text('Account details'), findsOneWidget);
    expect(find.text('Available balance'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads the data', (tester) async {
    await _pumpHome(tester);

    expect(find.byType(RefreshIndicator), findsOneWidget);

    await tester.fling(find.byType(ListView).first, const Offset(0, 320), 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await pumpUntil(tester, find.text('John'));

    // Survives the refresh with its content intact.
    expect(find.text('John'), findsOneWidget);
    expect(find.byType(BalanceCard), findsWidgets);
  });

  testWidgets('sections are headed and reveal in sequence', (tester) async {
    await _pumpHome(tester);

    expect(find.text('Favorite Transactions'), findsOneWidget);
    expect(find.text('Recent Activities'), findsOneWidget);
    expect(find.byType(Reveal), findsWidgets);
  });

  testWidgets('the Tracker tab shows real analytics, not a placeholder',
      (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('Tracker'));
    await tester.pump();
    await pumpUntil(tester, find.byType(TrackerTab));

    expect(find.byType(TrackerTab), findsOneWidget);
    // The seeded history is old enough that this month is quiet, but the
    // section headings prove the real tab is mounted rather than a stand-in.
    expect(find.text('Last 6 months'), findsOneWidget);
    expect(find.textContaining('on the way'), findsNothing);
  });

  testWidgets('the still-unbuilt tab keeps a designed empty state',
      (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('Porto'));
    await tester.pump();
    await pumpUntil(tester, find.text('Portfolio is on the way'));

    expect(find.byType(EmptyState), findsWidgets);
    expect(find.text('Portfolio is on the way'), findsOneWidget);
  });

  testWidgets('an unknown user id still renders instead of crashing',
      (tester) async {
    await _pumpHome(tester, userId: 9999);

    // No user matches, so the greeting falls back rather than throwing on null.
    expect(find.text('there'), findsOneWidget);
    expect(find.byType(BalanceCard), findsWidgets);
  });
}
