import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/presentation/screen/transactions/add_transaction_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/status_transaction_screen.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

import 'package:newtronic_banking/data/model/favourite_transfer.dart';
import 'support/test_harness.dart';

/// Holds the receipt the transfer screen pushed to the status route, plus the
/// backend it ran against so balances can be checked afterwards.
class _ReceiptSpy {
  TransferReceipt? value;
  late TestBackend backend;
}

Future<_ReceiptSpy> _pumpTransferScreen(WidgetTester tester) async {
  final spy = _ReceiptSpy();

  // A phone-shaped surface: the default 800x600 is too short for the picker
  // sheet, which is 70% of the viewport height.
  useMobileSurface(tester);

  final backend = await createTestBackend();
  spy.backend = backend;
  await tester.pumpWidget(wrapWithBackend(
    backend,
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
  await tester.pump();
  await pumpUntil(tester, find.text('New Transfer'));
  await tester.pumpAndSettle();

  return spy;
}

Finder _amountField() => find.widgetWithText(TextField, 'Nominal Transfer');

/// Fills in step one and advances to the amount step.
Future<void> _completeRecipientStep(
  WidgetTester tester, {
  String bank = 'Bank Danamon',
}) async {
  await tester.tap(find.byKey(const ValueKey('bank-name-field')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(bank));
  await tester.pumpAndSettle();
  await tester.tap(find.text(bank));
  await tester.pumpAndSettle();

  await tester.enterText(
      find.widgetWithText(TextField, 'Account Number'), '123456789012');
  await tester.enterText(
      find.widgetWithText(TextField, 'Recipient Name'), 'Siti Rahayu');
  await tester.pumpAndSettle();

  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('bank picker', () {
    testWidgets('opens with the full list already populated', (tester) async {
      await _pumpTransferScreen(tester);

      await tester.tap(find.byKey(const ValueKey('bank-name-field')));
      await tester.pumpAndSettle();

      // The old code copied `banks` into `filteredBanks` before the repository
      // returned, so the sheet always opened on the "not found" state.
      expect(find.textContaining('not found'), findsNothing);
      expect(find.text('Bank Mandiri'), findsOneWidget);
      expect(find.text('Bank Central Asia (BCA)'), findsOneWidget);
    });

    testWidgets('a selection sticks after the sheet closes', (tester) async {
      await _pumpTransferScreen(tester);

      await tester.tap(find.byKey(const ValueKey('bank-name-field')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bank Danamon'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bank Danamon'));
      await tester.pumpAndSettle();

      expect(find.text('Bank Danamon'), findsOneWidget);
    });

    testWidgets('searching filters, highlights and reports no matches',
        (tester) async {
      await _pumpTransferScreen(tester);

      await tester.tap(find.byKey(const ValueKey('bank-name-field')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Search banks'), 'danamon');
      // The search is debounced, and a pending Timer schedules no frame.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.text('Bank Danamon'), findsOneWidget);
      expect(find.text('Bank Mandiri'), findsNothing);

      // The matched run is emphasised so the result explains itself.
      final highlighted = tester.widget<HighlightedText>(
        find.byType(HighlightedText).first,
      );
      expect(highlighted.query, 'danamon');

      await tester.enterText(
          find.widgetWithText(TextField, 'Search banks'), 'zzz-no-such-bank');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.textContaining('not found'), findsOneWidget);
    });
  });

  group('amount step', () {
    testWidgets('groups the amount with separators as it is typed',
        (tester) async {
      await _pumpTransferScreen(tester);
      await _completeRecipientStep(tester);

      await tester.enterText(_amountField(), '250000');
      await tester.pumpAndSettle();

      expect(find.text('250.000'), findsOneWidget);
    });

    testWidgets('shows what the balance would be after the transfer',
        (tester) async {
      await _pumpTransferScreen(tester);
      await _completeRecipientStep(tester);

      expect(find.text('After transfer'), findsNothing);

      await tester.enterText(_amountField(), '250000');
      await tester.pumpAndSettle();

      // BlueSky holds Rp 5.000.000; 250.000 plus the 2.500 fee leaves this.
      expect(find.text('After transfer'), findsOneWidget);
      expect(find.text('Rp 4.747.500'), findsOneWidget);
    });

    testWidgets('an under-minimum amount blocks the transfer', (tester) async {
      await _pumpTransferScreen(tester);
      await _completeRecipientStep(tester);

      await tester.enterText(_amountField(), '500');
      await tester.pumpAndSettle();

      expect(find.textContaining('must be between'), findsOneWidget);
      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Continue'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('an amount beyond the balance blocks the transfer',
        (tester) async {
      await _pumpTransferScreen(tester);
      await _completeRecipientStep(tester);

      // Within the per-transfer cap, but more than the account holds.
      await tester.enterText(_amountField(), '6000000');
      await tester.pumpAndSettle();

      expect(find.textContaining('Not enough balance'), findsOneWidget);
      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Continue'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('confirmation', () {
    testWidgets('the summary sheet shows what is about to happen',
        (tester) async {
      await _pumpTransferScreen(tester);
      await _completeRecipientStep(tester);
      await tester.enterText(_amountField(), '250000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Review transfer'), findsOneWidget);
      expect(find.text('Confirm transfer'), findsOneWidget);
      expect(find.text('Siti Rahayu'), findsWidgets);
      expect(find.text('Total debited'), findsOneWidget);
      expect(find.text('Rp 252.500'), findsOneWidget);
      expect(find.text('Balance after'), findsOneWidget);
    });

    testWidgets('cancelling leaves the form untouched', (tester) async {
      final spy = await _pumpTransferScreen(tester);
      await _completeRecipientStep(tester);
      await tester.enterText(_amountField(), '250000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(spy.value, isNull);
      expect(find.text('250.000'), findsOneWidget);
    });

    testWidgets('confirming produces a receipt with the entered values',
        (tester) async {
      final spy = await _pumpTransferScreen(tester);
      await _completeRecipientStep(tester);
      await tester.enterText(_amountField(), '250000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm transfer'));
      await tester.pumpAndSettle();

      // The success dialog loops, so the frames are pumped explicitly.
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final receipt = spy.value;
      expect(receipt, isNotNull);
      expect(receipt!.recipientName, 'Siti Rahayu');
      expect(receipt.bankName, 'Bank Danamon');
      expect(receipt.accountNumber, '123456789012');
      expect(receipt.nominal, const Money(250000));
      expect(receipt.adminFee, const Money(2500));
      expect(receipt.total, const Money(252500));
      // The signed-in user is carried through instead of a hardcoded id.
      expect(receipt.userId, 3);
      // Every receipt used to show the same hardcoded reference.
      expect(receipt.reference, isNot('1696 2200 4022 5002'));
      expect(receipt.reference.replaceAll(' ', '').length, 16);

      // The money moved: the source account is down by amount + fee, and the
      // transfer is in the history.
      final source = spy.backend.accounts.byId(receipt.sourceAccountId)!;
      expect(source.balance.rupiah, 5000000 - 252500);
      expect(
        spy.backend.transactions.transactions.first.name,
        'Siti Rahayu',
      );
    });
  });

  group('the favourites tab on the transfer form', () {
    testWidgets('says so when there is nothing saved', (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const AddTransactionScreen(userId: 1),
      ));
      await pumpUntil(tester, find.text('Favorites'));
      // The Tab, not its label: the text sits outside the ink area, so a tap
      // aimed at it lands on nothing and the tab never switches.
      await tester.tap(find.widgetWithText(Tab, 'Favorites'));
      // Pumped until the tab has actually swapped: one large pump advances the
      // clock but the view still needs frames to rebuild.
      await pumpUntil(tester, find.text('No favourites yet'));

      expect(find.text('No favourites yet'), findsOneWidget);
    });

    testWidgets('lists what is saved and fills the form from it',
        (tester) async {
      // This tab used to show the empty panel whether or not anything was
      // saved, so a favourite could be created and never appear here.
      useMobileSurface(tester);
      final backend = await createTestBackend();
      await backend.favourites.save(FavouriteTransfer(
        id: favouriteIdFor(
          bankName: 'Bank Danamon',
          accountNumber: '123456789012',
        ),
        recipientName: 'Siti Rahayu',
        bankName: 'Bank Danamon',
        bankImage: '',
        accountNumber: '123456789012',
        amount: const Money(47500),
        createdAt: DateTime(2026, 9, 11),
      ));

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const AddTransactionScreen(userId: 1),
      ));
      await pumpUntil(tester, find.text('Favorites'));
      // The Tab, not its label: the text sits outside the ink area, so a tap
      // aimed at it lands on nothing and the tab never switches.
      await tester.tap(find.widgetWithText(Tab, 'Favorites'));
      await pumpUntil(tester, find.text('Siti Rahayu'));
      // The row exists as soon as the tab starts sliding in. Tapping then
      // lands on whatever is still under that point, so the swap has to
      // finish before the row can be used.
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Siti Rahayu'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Siti Rahayu'));
      await pumpUntil(tester, find.text('123456789012'));
      await tester.pump(const Duration(milliseconds: 600));

      // Back on the form, filled in.
      expect(find.text('Bank Danamon'), findsWidgets);
      expect(find.text('123456789012'), findsOneWidget);
    });
  });

  testWidgets('a bank list that cannot be read says so instead of sitting '
      'empty', (tester) async {
    useMobileSurface(tester);
    final backend = await createTestBackend();

    // The bank list is a bundled asset, so the failure has to come from the
    // asset channel: this answers every asset request with something that is
    // not JSON, which is what a truncated or corrupt bundle looks like.
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (message) async =>
          Uint8List.fromList(utf8.encode('not json at all')).buffer.asByteData(),
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null));
    rootBundle.clear();

    await tester.pumpWidget(wrapWithBackend(
      backend,
      child: const AddTransactionScreen(userId: 1),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Could not load the bank list'), findsOneWidget);
  });
}
