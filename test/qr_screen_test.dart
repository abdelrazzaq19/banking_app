import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newtronic_banking/data/model/balance_model.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/qr/qris_payload.dart';
import 'package:newtronic_banking/presentation/screen/qr/enter_code_screen.dart';
import 'package:newtronic_banking/presentation/screen/qr/my_qr_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/add_transaction_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/transfer_args.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';
import 'package:newtronic_banking/presentation/screen/qr/widgets/qr_payment_panel.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'support/test_harness.dart';

const _account = Balances(
  cardName: 'BlueSky',
  cardNumber: '1234 5678 9012 3456',
  balance: Money(5000000),
  expiryDate: '12/25',
  id: '001',
);

const _second = Balances(
  cardName: 'SilverWave',
  cardNumber: '9876 5432 1098 7654',
  balance: Money(3500000),
  expiryDate: '09/24',
  id: '002',
);

/// The field carrying [hint].
///
/// `bySemanticsLabel` finds the Semantics node, not the editable inside it, so
/// `enterText` against it throws — the same finder shape the rest of the suite
/// already uses is the one that works.
Finder _fieldWithHint(String hint) => find.ancestor(
      of: find.text(hint),
      matching: find.byType(AppTextField),
    );

/// The payload the rendered panel carries.
///
/// Round-tripped through the codec rather than read straight off the widget,
/// so the assertion covers what a scanner would actually get out of the image
/// and not just what was handed to it.
QrisPayload _renderedPayload(WidgetTester tester) {
  final panel = tester.widget<QrPaymentPanel>(find.byType(QrPaymentPanel));
  final result = QrisPayload.decode(panel.payload.encode());
  expect(result, isA<QrisDecoded>(), reason: switch (result) {
    QrisRejected(:final message) => message,
    _ => '',
  });
  return (result as QrisDecoded).payload;
}

void main() {
  group('My QR', () {
    testWidgets('the code carries the account it is shown for',
        (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const MyQrScreen(
          accounts: [_account, _second],
          holderName: 'Ahmad Yusuf',
          initialAccount: _account,
        ),
      ));
      await tester.pump();

      final payload = _renderedPayload(tester);
      expect(payload.recipientName, 'Ahmad Yusuf');
      expect(payload.bankName, ownBankName);
      // The stored number is grouped for display; a code carries digits.
      expect(payload.accountNumber, '1234567890123456');
      expect(payload.amount, isNull);
    });

    testWidgets('an empty amount leaves the code open', (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const MyQrScreen(
          accounts: [_account],
          holderName: 'Ahmad Yusuf',
        ),
      ));
      await tester.pump();

      expect(find.text('Any amount'), findsOneWidget);
      expect(_renderedPayload(tester).isDynamic, isFalse);
    });

    testWidgets('typing an amount fixes it into the code', (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const MyQrScreen(
          accounts: [_account],
          holderName: 'Ahmad Yusuf',
        ),
      ));
      await tester.pump();

      await tester.enterText(
        _fieldWithHint('Amount (optional)'),
        '125000',
      );
      await tester.pump();

      final payload = _renderedPayload(tester);
      expect(payload.amount, const Money(125000));
      expect(payload.isDynamic, isTrue);
      expect(find.text('Rp 125.000'), findsOneWidget);
    });

    testWidgets('no account means no code, and says so', (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const MyQrScreen(accounts: [], holderName: 'Ahmad Yusuf'),
      ));
      await tester.pump();

      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('No account to receive into'), findsOneWidget);
      // Nothing to share, so the action is disabled rather than failing later.
      expect(
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Share code'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('one account hides the picker it does not need',
        (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const MyQrScreen(
          accounts: [_account],
          holderName: 'Ahmad Yusuf',
        ),
      ));
      await tester.pump();

      expect(find.text('Receive into'), findsNothing);
    });
  });

  group('entering a code', () {
    testWidgets('a good code is shown before anything is paid',
        (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const EnterCodeScreen(userId: 1),
      ));
      await tester.pump();

      await tester.enterText(
        _fieldWithHint('Paste the code here'),
        const QrisPayload(
          bankName: 'Bank Danamon',
          accountNumber: '123456789012',
          recipientName: 'Siti Rahayu',
          amount: Money(47500),
          note: 'Table 4',
        ).encode(),
      );
      await tester.pump();

      expect(find.text('Siti Rahayu'), findsOneWidget);
      expect(find.text('Bank Danamon'), findsOneWidget);
      expect(find.text('1234 **** 9012'), findsOneWidget);
      expect(find.text('Rp 47.500'), findsOneWidget);
      expect(find.text('Table 4'), findsOneWidget);
      expect(
        find.textContaining('Nothing is sent yet'),
        findsOneWidget,
      );
    });

    testWidgets('an open code says the payer chooses the amount',
        (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const EnterCodeScreen(userId: 1),
      ));
      await tester.pump();

      await tester.enterText(
        _fieldWithHint('Paste the code here'),
        const QrisPayload(
          bankName: 'Bank Danamon',
          accountNumber: '123456789012',
          recipientName: 'Siti Rahayu',
        ).encode(),
      );
      await tester.pump();

      expect(find.text('You choose'), findsOneWidget);
    });

    testWidgets('a damaged code says what is wrong with it', (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const EnterCodeScreen(userId: 1),
      ));
      await tester.pump();

      final tampered = const QrisPayload(
        bankName: 'Bank Danamon',
        accountNumber: '123456789012',
        recipientName: 'Siti Rahayu',
      ).encode().replaceFirst('123456789012', '123456789013');

      await tester.enterText(_fieldWithHint('Paste the code here'), tampered);
      await tester.pump();

      expect(find.textContaining('checksum does not match'), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, 'Continue to transfer'),
        findsNothing,
      );
    });

    testWidgets('text that is not a code at all is refused', (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const EnterCodeScreen(userId: 1),
      ));
      await tester.pump();

      await tester.enterText(
        _fieldWithHint('Paste the code here'),
        'have you seen my cat',
      );
      await tester.pump();

      expect(find.text('This is not a payment code.'), findsOneWidget);
    });

    testWidgets('clearing the field clears the verdict with it',
        (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const EnterCodeScreen(userId: 1),
      ));
      await tester.pump();

      final field = _fieldWithHint('Paste the code here');
      await tester.enterText(field, 'nonsense');
      await tester.pump();
      expect(find.text('This is not a payment code.'), findsOneWidget);

      await tester.enterText(field, '');
      await tester.pump();
      expect(find.text('This is not a payment code.'), findsNothing);
    });

    testWidgets('pasting an empty clipboard says so rather than failing',
        (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      // A platform answering with no text at all: Flutter's own getData casts
      // the missing entry to String and throws, so this is the crash path.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async =>
            call.method == 'Clipboard.getData' ? <String, Object?>{} : null,
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const EnterCodeScreen(userId: 1),
      ));
      await tester.pump();

      await tester.tap(find.widgetWithText(AppButton, 'Paste from clipboard'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Could not read the clipboard. Paste into the field.'),
        findsOneWidget,
      );
    });

    testWidgets('an empty clipboard says so rather than doing nothing',
        (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, Object?>{'text': '  '}
            : null,
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: const EnterCodeScreen(userId: 1),
      ));
      await tester.pump();

      await tester.tap(find.widgetWithText(AppButton, 'Paste from clipboard'));
      await tester.pump();
      await tester.pump();

      expect(find.text('There is nothing on the clipboard.'), findsOneWidget);
    });

    testWidgets('continuing hands the details to the transfer form',
        (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();
      TransferArgs? received;

      await tester.pumpWidget(wrapWithBackend(
        backend,
        onGenerateRoute: (settings) => switch (settings.name) {
          AddTransactionScreen.routeName => MaterialPageRoute(
              builder: (_) {
                received = settings.arguments as TransferArgs?;
                return const Scaffold(body: Text('transfer form'));
              },
            ),
          _ => MaterialPageRoute(
              builder: (_) => const EnterCodeScreen(userId: 7),
            ),
        },
      ));
      await tester.pump();

      await tester.enterText(
        _fieldWithHint('Paste the code here'),
        const QrisPayload(
          bankName: 'Bank Danamon',
          accountNumber: '123456789012',
          recipientName: 'Siti Rahayu',
          amount: Money(47500),
        ).encode(),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(AppButton, 'Continue to transfer'));
      await tester.pumpAndSettle();

      expect(received, isNotNull);
      expect(received!.userId, 7);
      expect(received!.prefill!.recipientName, 'Siti Rahayu');
      expect(received!.prefill!.accountNumber, '123456789012');
      expect(received!.prefill!.amount, const Money(47500));
      // The code named the amount, so the form is told it was not the user's
      // choice.
      expect(received!.prefill!.isAmountFixed, isTrue);
    });
  });

  group('prefilling the transfer form', () {
    testWidgets('a scanned code fills the recipient step', (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: AddTransactionScreen(
          userId: 1,
          prefill: TransferPrefill.fromQris(const QrisPayload(
            bankName: 'Bank Danamon',
            accountNumber: '123456789012',
            recipientName: 'Siti Rahayu',
            amount: Money(47500),
          )),
        ),
      ));
      await pumpUntil(tester, find.text('Bank Danamon'));

      expect(find.text('Bank Danamon'), findsOneWidget);
      expect(find.text('123456789012'), findsOneWidget);
      expect(find.text('Siti Rahayu'), findsOneWidget);
    });

    testWidgets('a bank this app does not carry is called out, not guessed',
        (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: AddTransactionScreen(
          userId: 1,
          prefill: TransferPrefill.fromQris(const QrisPayload(
            bankName: 'Bank Of Nowhere',
            accountNumber: '123456789012',
            recipientName: 'Siti Rahayu',
          )),
        ),
      ));
      await pumpUntil(tester, find.textContaining('Bank Of Nowhere'));

      expect(
        find.textContaining('which is not in the list'),
        findsOneWidget,
      );
      // The bank picker stays empty rather than being filled with a near miss.
      expect(find.text('Select a bank'), findsOneWidget);
    });

    testWidgets('a 16-digit number from a code is accepted', (tester) async {
      // The old rule was a flat 12 digits, which rejected every code generated
      // from one of this app's own 16-digit cards.
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: AddTransactionScreen(
          userId: 1,
          prefill: TransferPrefill.fromQris(const QrisPayload(
            bankName: 'Bank Danamon',
            accountNumber: '1234567890123456',
            recipientName: 'Siti Rahayu',
          )),
        ),
      ));
      await pumpUntil(tester, find.text('1234567890123456'));

      expect(find.textContaining('must be 10 to 16 digits'), findsNothing);
    });
  });
}
