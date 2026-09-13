import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/presentation/screen/main/home_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/status_transaction_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/widgets/receipt_card.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

import 'support/test_harness.dart';

final _receipt = TransferReceipt(
  userId: 7,
  recipientName: 'Siti Rahayu',
  bankName: 'Bank Danamon',
  bankImage: 'https://example.invalid/logo.png',
  accountNumber: '123456789012',
  sourceAccountId: '001',
  sourceAccountName: 'BlueSky',
  nominal: Money(250000),
  transactionType: 'BI-FAST',
  reference: '1696 2200 4022 5002',
  createdAt: DateTime(2026, 9, 11),
  note: 'Rent',
);

/// Records what the receipt screen asked the navigator to do, and holds the
/// backend so a saved favourite can be checked.
class _NavSpy {
  String? route;
  Object? arguments;
  late TestBackend backend;
}

Future<_NavSpy> _pumpReceipt(WidgetTester tester) async {
  useMobileSurface(tester);

  final spy = _NavSpy()..backend = await createTestBackend();
  await tester.pumpWidget(wrapWithBackend(
    spy.backend,
    onGenerateRoute: (settings) {
      if (settings.name == HomeScreen.routeName) {
        spy.route = settings.name;
        spy.arguments = settings.arguments;
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('home')),
        );
      }
      return MaterialPageRoute(
        builder: (_) => StatusTransactionScreen(receipt: _receipt),
      );
    },
  ));
  // The success animation is driven by a controller, so a couple of frames is
  // enough; pumpAndSettle would wait on the Lottie itself.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  return spy;
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  testWidgets('shows the real transfer values', (tester) async {
    await _pumpReceipt(tester);

    expect(find.text('Rp 250.000'), findsOneWidget);
    expect(find.text('Siti Rahayu'), findsOneWidget);
    expect(find.textContaining('Bank Danamon'), findsOneWidget);
    expect(find.text('BI-FAST'), findsOneWidget);
    expect(find.text('1696 2200 4022 5002'), findsOneWidget);
    expect(find.text('11 September 2026'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('BlueSky'), findsOneWidget);
  });

  testWidgets('masks the recipient account number', (tester) async {
    await _pumpReceipt(tester);

    expect(find.textContaining('1234 **** 9012'), findsOneWidget);
    expect(find.textContaining('123456789012'), findsNothing);
  });

  testWidgets('the fee breakdown is collapsed until expanded', (tester) async {
    await _pumpReceipt(tester);

    expect(find.text('Total debited'), findsNothing);

    await tester.tap(find.text('Detail'));
    await tester.pumpAndSettle();

    expect(find.text('Transfer amount'), findsOneWidget);
    expect(find.text('Admin fee'), findsOneWidget);
    expect(find.text('Rp 2.500'), findsOneWidget);
    // 250.000 + 2.500 — computed, not a hardcoded string.
    expect(find.text('Rp 252.500'), findsOneWidget);
  });

  testWidgets('Done returns to the home of the user who transferred',
      (tester) async {
    final spy = await _pumpReceipt(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Done'));
    await tester.pumpAndSettle();

    expect(spy.route, HomeScreen.routeName);
    // Used to push a hardcoded `arguments: 5`, silently switching users.
    expect(spy.arguments, 7);
  });

  testWidgets('saving a favourite persists it and disables the button',
      (tester) async {
    final spy = await _pumpReceipt(tester);

    final saveButton = find.widgetWithText(AppButton, 'Save as Favorite');
    expect(tester.widget<AppButton>(saveButton).onPressed, isNotNull);

    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('saved to favourites'), findsOneWidget);

    final saved = find.widgetWithText(AppButton, 'Saved to favourites');
    expect(saved, findsOneWidget);
    expect(tester.widget<AppButton>(saved).onPressed, isNull);

    // It is a real save, not a local flag.
    expect(spy.backend.favourites.favourites, hasLength(1));
    expect(spy.backend.favourites.favourites.single.recipientName,
        'Siti Rahayu');
    expect(spy.backend.favourites.containsReceipt(_receipt), isTrue);
  });

  testWidgets('saving does not navigate away from the receipt',
      (tester) async {
    final spy = await _pumpReceipt(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Save as Favorite'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The old flow claimed a save and then left for home.
    expect(spy.route, isNull);
    expect(find.byType(ReceiptCard), findsOneWidget);
  });

  testWidgets('the back gesture cannot return to the transfer form',
      (tester) async {
    await _pumpReceipt(tester);

    // PopScope is generic, so match on the instance rather than a concrete type.
    expect(
      find.byWidgetPredicate((widget) => widget is PopScope && !widget.canPop),
      findsOneWidget,
    );
  });

  testWidgets('a receipt without a note omits the row', (tester) async {
    final backend = await createTestBackend();
    await tester.pumpWidget(wrapWithBackend(
      backend,
      child: Scaffold(
        body: ReceiptCard(
          receipt: TransferReceipt(
            userId: 1,
            recipientName: 'Budi',
            bankName: 'Bank Mandiri',
            bankImage: '',
            accountNumber: '999888777666',
            sourceAccountId: '001',
            sourceAccountName: 'BlueSky',
            nominal: Money(10000),
            transactionType: 'BI-FAST',
            reference: '1111 2222 3333 4444',
            createdAt: DateTime(2026, 9, 11),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Note'), findsNothing);
    expect(find.text('Budi'), findsOneWidget);
  });
}
