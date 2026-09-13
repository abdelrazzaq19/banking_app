import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/model/transaction_model.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/data/repository/repository.dart';
import 'package:newtronic_banking/state/transfer_service.dart';

import 'support/test_harness.dart';

TransferReceipt _receiptFor({
  required String sourceAccountId,
  required Money nominal,
  String reference = '1111 2222 3333 4444',
  String? note,
}) =>
    TransferReceipt(
      userId: 1,
      recipientName: 'Siti Rahayu',
      bankName: 'Bank Danamon',
      bankImage: '',
      accountNumber: '123456789012',
      sourceAccountId: sourceAccountId,
      sourceAccountName: 'BlueSky',
      nominal: nominal,
      transactionType: 'BI-FAST',
      reference: reference,
      createdAt: DateTime(2026, 9, 11),
      note: note,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('a successful transfer', () {
    test('takes the amount plus the fee out of the source account', () async {
      final backend = await createTestBackend();
      final account = backend.accounts.accounts.first;
      final before = account.balance;

      final outcome = await TransferService(
        accounts: backend.accounts,
        transactions: backend.transactions,
      ).execute(_receiptFor(
        sourceAccountId: account.id,
        nominal: const Money(250000),
      ));

      expect(outcome.isSuccess, isTrue);
      // 5.000.000 - 250.000 - 2.500
      expect(backend.accounts.byId(account.id)!.balance,
          before - const Money(252500));
      expect(backend.accounts.byId(account.id)!.balance.rupiah, 4747500);
    });

    test('leaves the other accounts alone', () async {
      final backend = await createTestBackend();
      final source = backend.accounts.accounts.first;
      final other = backend.accounts.accounts[1];
      final otherBefore = other.balance;

      await TransferService(
        accounts: backend.accounts,
        transactions: backend.transactions,
      ).execute(_receiptFor(
        sourceAccountId: source.id,
        nominal: const Money(250000),
      ));

      expect(backend.accounts.byId(other.id)!.balance, otherBefore);
    });

    test('records it at the top of the history', () async {
      final backend = await createTestBackend();
      final account = backend.accounts.accounts.first;
      final before = backend.transactions.transactions.length;

      await TransferService(
        accounts: backend.accounts,
        transactions: backend.transactions,
      ).execute(_receiptFor(
        sourceAccountId: account.id,
        nominal: const Money(250000),
        note: 'Rent',
      ));

      final history = backend.transactions.transactions;
      expect(history, hasLength(before + 1));
      expect(history.first.name, 'Siti Rahayu');
      expect(history.first.amount.rupiah, 250000);
      expect(history.first.fee?.rupiah, 2500);
      expect(history.first.note, 'Rent');
      expect(history.first.isTransfer, isTrue);
    });

    test('both the balance and the record survive a relaunch', () async {
      final backend = await createTestBackend();
      final account = backend.accounts.accounts.first;

      await TransferService(
        accounts: backend.accounts,
        transactions: backend.transactions,
      ).execute(_receiptFor(
        sourceAccountId: account.id,
        nominal: const Money(250000),
      ));

      // Rebuild the data layer over the same store, as a relaunch would.
      final reopened = Repository(store: backend.store);
      await reopened.ensureSeeded();

      expect(
        reopened.readAccounts().firstWhere((a) => a.id == account.id).balance
            .rupiah,
        4747500,
      );
      expect(
        reopened.readTransactions().any((t) => t.name == 'Siti Rahayu'),
        isTrue,
      );
    });

    test('the stored record rebuilds the receipt', () async {
      final backend = await createTestBackend();
      final account = backend.accounts.accounts.first;
      final original = _receiptFor(
        sourceAccountId: account.id,
        nominal: const Money(250000),
        note: 'Rent',
      );

      await TransferService(
        accounts: backend.accounts,
        transactions: backend.transactions,
      ).execute(original);

      final rebuilt = backend.transactions.transactions.first.toReceipt(1);
      expect(rebuilt, isNotNull);
      expect(rebuilt!.recipientName, original.recipientName);
      expect(rebuilt.bankName, original.bankName);
      expect(rebuilt.accountNumber, original.accountNumber);
      expect(rebuilt.nominal, original.nominal);
      expect(rebuilt.adminFee, original.adminFee);
      expect(rebuilt.total, original.total);
      expect(rebuilt.reference, original.reference);
      expect(rebuilt.note, original.note);
    });

    test('a seeded entry has no receipt to rebuild', () async {
      final backend = await createTestBackend();
      final seeded = backend.transactions.transactions
          .firstWhere((transaction) => !transaction.isTransfer);

      expect(seeded.toReceipt(1), isNull);
    });
  });

  group('a refused transfer', () {
    test('an amount beyond the balance changes nothing', () async {
      final backend = await createTestBackend();
      final account = backend.accounts.accounts.first;
      final before = account.balance;
      final historyBefore = backend.transactions.transactions.length;

      final outcome = await TransferService(
        accounts: backend.accounts,
        transactions: backend.transactions,
      ).execute(_receiptFor(
        sourceAccountId: account.id,
        nominal: const Money(99000000),
      ));

      expect(outcome.isSuccess, isFalse);
      expect(outcome.failure, TransferFailure.insufficientFunds);
      expect(backend.accounts.byId(account.id)!.balance, before);
      expect(backend.transactions.transactions, hasLength(historyBefore));
    });

    test('the fee is what tips an exact-balance transfer over', () async {
      final backend = await createTestBackend();
      final account = backend.accounts.accounts.first;

      // Exactly the balance: affordable on its own, not once the fee is added.
      final outcome = await TransferService(
        accounts: backend.accounts,
        transactions: backend.transactions,
      ).execute(_receiptFor(
        sourceAccountId: account.id,
        nominal: account.balance,
      ));

      expect(outcome.failure, TransferFailure.insufficientFunds);
      expect(backend.accounts.byId(account.id)!.balance, account.balance);
    });

    test('the balance minus the fee is affordable to the last rupiah',
        () async {
      final backend = await createTestBackend();
      final account = backend.accounts.accounts.first;
      final spendable = account.balance - const Money(2500);

      final outcome = await TransferService(
        accounts: backend.accounts,
        transactions: backend.transactions,
      ).execute(_receiptFor(
        sourceAccountId: account.id,
        nominal: spendable,
      ));

      expect(outcome.isSuccess, isTrue);
      expect(backend.accounts.byId(account.id)!.balance.rupiah, 0);
    });

    test('an unknown account is reported, not silently ignored', () async {
      final backend = await createTestBackend();

      final outcome = await TransferService(
        accounts: backend.accounts,
        transactions: backend.transactions,
      ).execute(_receiptFor(
        sourceAccountId: 'no-such-account',
        nominal: const Money(1000),
      ));

      expect(outcome.failure, TransferFailure.unknownAccount);
    });

    test('every failure carries a message a user could act on', () {
      for (final failure in TransferFailure.values) {
        expect(failure.message, isNotEmpty);
        expect(failure.message.endsWith('.'), isTrue,
            reason: '${failure.name} should read as a sentence');
      }
    });
  });

  group('history search', () {
    Future<void> seedTransfer(
      dynamic backend, {
      required String recipient,
      required String bank,
      required Money amount,
      required String reference,
    }) async {
      await backend.transactions.add(Transactions.fromReceipt(
        TransferReceipt(
          userId: 1,
          recipientName: recipient,
          bankName: bank,
          bankImage: '',
          accountNumber: '123456789012',
          sourceAccountId: '001',
          sourceAccountName: 'BlueSky',
          nominal: amount,
          transactionType: 'BI-FAST',
          reference: reference,
          createdAt: DateTime(2026, 9, 11),
        ),
      ));
    }

    test('finds a transfer by recipient, bank and amount', () async {
      final backend = await createTestBackend();
      await seedTransfer(
        backend,
        recipient: 'Siti Rahayu',
        bank: 'Bank Danamon',
        amount: const Money(250000),
        reference: '1111 2222 3333 4444',
      );

      expect(backend.transactions.search('siti'), hasLength(1));
      expect(backend.transactions.search('danamon'), hasLength(1));
      // Both the grouped form and the raw digits.
      expect(backend.transactions.search('250.000'), hasLength(1));
      expect(backend.transactions.search('250000'), hasLength(1));
    });

    test('an empty query returns the whole history', () async {
      final backend = await createTestBackend();
      expect(
        backend.transactions.search('  ').length,
        backend.transactions.transactions.length,
      );
    });

    test('a query matching nothing returns nothing', () async {
      final backend = await createTestBackend();
      expect(backend.transactions.search('zzz-no-such-payee'), isEmpty);
    });
  });
}
