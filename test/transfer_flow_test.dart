import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/presentation/screen/transactions/add_transaction_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/status_transaction_screen.dart';

/// Holds the receipt the transfer screen pushed to the status route.
class _ReceiptSpy {
  TransferReceipt? value;
}

/// Pumps the transfer screen inside a navigator that records what it was asked
/// to push, so the receipt handed to the status screen can be inspected.
Future<_ReceiptSpy> _pumpTransferScreen(WidgetTester tester) async {
  final spy = _ReceiptSpy();

  // A phone-shaped surface: the default 800x600 is too short for the picker
  // sheet, which is 70% of the viewport height.
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    onGenerateRoute: (settings) {
      if (settings.name == StatusTransactionScreen.routeName) {
        spy.value = settings.arguments as TransferReceipt;
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('receipt')),
        );
      }
      return MaterialPageRoute(
        builder: (_) => const AddTransactionScreen(userId: 3),
      );
    },
  ));

  return spy;
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  testWidgets('bank picker opens with the full list already populated',
      (tester) async {
    await _pumpTransferScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bank-name-field')));
    await tester.pumpAndSettle();

    // The old code copied `banks` into `filteredBanks` before the repository
    // returned, so the sheet always opened on the "not found" state.
    expect(find.textContaining('not found'), findsNothing);
    expect(find.text('Bank Mandiri'), findsOneWidget);
    expect(find.text('Bank Central Asia (BCA)'), findsOneWidget);
  });

  testWidgets('selecting a bank sticks after the sheet closes', (tester) async {
    await _pumpTransferScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bank-name-field')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bank Danamon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank Danamon'));
    await tester.pumpAndSettle();

    expect(find.text('Bank Danamon'), findsOneWidget);
  });

  testWidgets('searching the bank picker filters the list', (tester) async {
    await _pumpTransferScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bank-name-field')));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Search'), 'danamon');
    await tester.pumpAndSettle();

    expect(find.text('Bank Danamon'), findsOneWidget);
    expect(find.text('Bank Mandiri'), findsNothing);

    await tester.enterText(
        find.widgetWithText(TextField, 'Search'), 'zzz-no-such-bank');
    await tester.pumpAndSettle();
    expect(find.textContaining('not found'), findsOneWidget);
  });

  testWidgets('a full transfer produces a receipt with the entered values',
      (tester) async {
    final spy = await _pumpTransferScreen(tester);
    await tester.pumpAndSettle();

    // Step one: recipient details.
    await tester.tap(find.byKey(const ValueKey('bank-name-field')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bank Danamon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank Danamon'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Account Number'), '123456789012');
    await tester.enterText(
        find.widgetWithText(TextField, 'Recipient Name'), 'Siti Rahayu');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step two: amount.
    await tester.enterText(
        find.widgetWithText(TextField, 'Nominal Transfer'), '250000');
    await tester.pumpAndSettle();

    // The dialogs host looping Lottie animations, so pumpAndSettle would never
    // settle here; the frames are pumped explicitly instead.
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Yes'));
    await tester.pump();
    // Clears the two-second delay before the success dialog hands over.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final receipt = spy.value;
    expect(receipt, isNotNull);
    expect(receipt!.recipientName, 'Siti Rahayu');
    expect(receipt.bankName, 'Bank Danamon');
    expect(receipt.accountNumber, '123456789012');
    expect(receipt.nominal, 250000);
    expect(receipt.adminFee, 2500);
    expect(receipt.total, 252500);
    // The signed-in user is carried through instead of a hardcoded id.
    expect(receipt.userId, 3);
    // Every receipt used to show the same hardcoded reference.
    expect(receipt.reference, isNot('1696 2200 4022 5002'));
    expect(receipt.reference.replaceAll(' ', '').length, 16);
  });

  testWidgets('an under-minimum amount blocks the transfer', (tester) async {
    final spy = await _pumpTransferScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bank-name-field')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bank Danamon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank Danamon'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Account Number'), '123456789012');
    await tester.enterText(
        find.widgetWithText(TextField, 'Recipient Name'), 'Siti Rahayu');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Nominal Transfer'), '500');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.textContaining('must be between'), findsOneWidget);
    expect(spy.value, isNull);
  });
}
