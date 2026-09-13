import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/data/local/local_store.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/data/repository/repository.dart';
import 'package:newtronic_banking/state/account_store.dart';
import 'package:newtronic_banking/state/session_store.dart';
import 'package:newtronic_banking/state/transaction_store.dart';
import 'package:newtronic_banking/state/transfer_service.dart';

import 'support/test_harness.dart';

/// Checkpoint C, as the plan states it:
/// "sign up → transfer → balance drops → restart → everything persisted".
///
/// The individual pieces are covered elsewhere. This walks the whole path in
/// one go, because the parts passing separately is not the same claim as the
/// journey working end to end.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  test('sign up, transfer, relaunch — everything persists', () async {
    final backend = await createTestBackend();

    // 1. Sign up.
    final registration = await backend.session.register(
      name: 'Siti Rahayu',
      username: 'sitirahayu',
      email: 'siti@example.com',
      password: 'Passw0rd!',
    );
    expect(registration.isSuccess, isTrue);
    final userId = registration.user!.id;
    expect(backend.session.isSignedIn, isTrue);

    // 2. Transfer, from a known starting balance.
    final account = backend.accounts.accounts.first;
    expect(account.balance.rupiah, 5000000);

    final outcome = await backend.transfers.execute(TransferReceipt(
      userId: userId,
      recipientName: 'Budi Santoso',
      bankName: 'Bank Mandiri',
      bankImage: '',
      accountNumber: '123456789012',
      sourceAccountId: account.id,
      sourceAccountName: account.cardName,
      nominal: const Money(1250000),
      transactionType: 'BI-FAST',
      reference: '9999 8888 7777 6666',
      createdAt: DateTime(2026, 9, 11),
      note: 'Rent',
    ));
    expect(outcome.isSuccess, isTrue);

    // 3. The balance drops by the amount plus the fee.
    expect(backend.accounts.byId(account.id)!.balance.rupiah,
        5000000 - 1250000 - 2500);

    // 4. Relaunch: rebuild every layer over the same store, as `main` does.
    final store = await LocalStore.open();
    final repository = Repository(store: store);
    await repository.ensureSeeded();

    final accounts = AccountStore(repository);
    final transactions = TransactionStore(repository);
    final session = SessionStore(repository: repository, store: store);
    await accounts.load();
    await transactions.load();
    await session.restore();

    // The session survived — no signing in again.
    expect(session.isSignedIn, isTrue);
    expect(session.userId, userId);
    expect(session.currentUser?.name, 'Siti Rahayu');

    // The balance survived.
    expect(accounts.byId(account.id)!.balance.rupiah, 3747500);

    // The transfer is in the history, with its detail intact.
    final recorded = transactions.transactions.first;
    expect(recorded.name, 'Budi Santoso');
    expect(recorded.amount.rupiah, 1250000);
    expect(recorded.fee?.rupiah, 2500);
    expect(recorded.note, 'Rent');
    expect(recorded.bankName, 'Bank Mandiri');

    // And it is findable.
    expect(transactions.search('budi'), hasLength(1));
    expect(transactions.search('mandiri'), hasLength(1));
    expect(transactions.search('1.250.000'), hasLength(1));

    // 5. Signing out ends the session but keeps the money and the history.
    await session.signOut();
    final afterSignOut = SessionStore(repository: repository, store: store);
    await afterSignOut.restore();
    expect(afterSignOut.isSignedIn, isFalse);

    final reloadedAccounts = AccountStore(repository);
    await reloadedAccounts.load();
    expect(reloadedAccounts.byId(account.id)!.balance.rupiah, 3747500);

    // 6. Signing back in with the password chosen at sign-up works.
    final signedIn = await afterSignOut.signInWithCredentials(
      emailOrUsername: 'siti@example.com',
      password: 'Passw0rd!',
    );
    expect(signedIn?.id, userId);
  });

  test('a refused transfer leaves nothing behind after a relaunch', () async {
    final backend = await createTestBackend();
    final account = backend.accounts.accounts.first;
    final historyBefore = backend.transactions.transactions.length;

    final outcome = await backend.transfers.execute(TransferReceipt(
      userId: 1,
      recipientName: 'Budi Santoso',
      bankName: 'Bank Mandiri',
      bankImage: '',
      accountNumber: '123456789012',
      sourceAccountId: account.id,
      sourceAccountName: account.cardName,
      nominal: const Money(99000000),
      transactionType: 'BI-FAST',
      reference: '1111 1111 1111 1111',
      createdAt: DateTime(2026, 9, 11),
    ));
    expect(outcome.failure, TransferFailure.insufficientFunds);

    final repository = Repository(store: backend.store);
    await repository.ensureSeeded();

    expect(repository.readAccounts().first.balance.rupiah, 5000000);
    expect(repository.readTransactions(), hasLength(historyBefore));
  });
}
