import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/data/model/balance_model.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/data/qr/qris_payload.dart';
import 'package:newtronic_banking/presentation/screen/auth/authentication_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/account_detail_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/home_screen.dart';
import 'package:newtronic_banking/presentation/screen/main/profile_screen.dart';
import 'package:newtronic_banking/presentation/screen/qr/enter_code_screen.dart';
import 'package:newtronic_banking/presentation/screen/qr/my_qr_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/add_transaction_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/receipt_detail_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/status_transaction_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/transaction_screen.dart';

import 'support/test_harness.dart';

/// A small phone. The narrow width is the point: a screen that survives 200%
/// on a tablet has not been tested.
const Size _smallPhone = Size(360, 780);

final _receipt = TransferReceipt(
  userId: 1,
  recipientName: 'Siti Rahayu',
  bankName: 'Bank Danamon',
  bankImage: '',
  accountNumber: '123456789012',
  sourceAccountId: '001',
  sourceAccountName: 'BlueSky',
  nominal: const Money(250000),
  transactionType: 'BI-FAST',
  reference: '1696 2200 4022 5002',
  createdAt: DateTime(2026, 9, 11),
  note: 'Rent',
);

const _account = Balances(
  cardName: 'BlueSky',
  cardNumber: '1234 5678 9012 3456',
  balance: Money(5000000),
  expiryDate: '12/25',
  id: '001',
);

/// Pumps [build] at double text size and fails on any overflow.
///
/// The framework reports an overflowing RenderFlex as an exception during
/// paint, so an empty `takeException` is a real check on the layout rather
/// than only on the build.
void scaleTest(String description, Widget Function() build, {Size? surface}) {
  testWidgets('$description survives 200% text', (tester) async {
    useMobileSurface(tester, size: surface ?? _smallPhone);
    final backend = await createTestBackend();

    await tester.pumpWidget(wrapWithBackend(
      backend,
      child: atTextScale(2, build()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
  });
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  scaleTest('the auth screen', AuthenticationScreen.new);
  scaleTest('home', () => const HomeScreen(id: 1));
  scaleTest('the profile screen', ProfileScreen.new);
  scaleTest('account detail', () => const AccountDetailScreen(
        balance: _account,
        label: 'Account',
        userId: 1,
      ));
  scaleTest('the transfer form', () => const AddTransactionScreen(userId: 1));
  scaleTest('history', () => const TransactionScreen(userId: 1));
  scaleTest('the receipt', () => StatusTransactionScreen(receipt: _receipt));
  scaleTest('a re-opened receipt',
      () => ReceiptDetailScreen(receipt: _receipt));
  scaleTest('my QR', () => const MyQrScreen(
        accounts: [_account],
        holderName: 'Ahmad Yusuf',
      ));
  scaleTest('entering a code', () => const EnterCodeScreen(userId: 1));

  testWidgets('a decoded code stays readable at 200% text', (tester) async {
    // The panel that appears after a successful decode is the one part of the
    // screen the plain scale test never reaches, because nothing is typed.
    useMobileSurface(tester, size: _smallPhone);
    final backend = await createTestBackend();

    await tester.pumpWidget(wrapWithBackend(
      backend,
      child: atTextScale(2, const EnterCodeScreen(userId: 1)),
    ));
    await tester.pump();

    await tester.enterText(
      find.byType(TextField).first,
      const QrisPayload(
        bankName: 'Bank Negara Indonesia (BNI)',
        accountNumber: '123456789012',
        recipientName: 'Siti Rahayu',
        amount: Money(47500),
        note: 'Rent',
      ).encode(),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
