import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/data/local/local_store.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/repository/repository.dart';
import 'package:newtronic_banking/state/account_store.dart';
import 'package:newtronic_banking/state/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('LocalStore', () {
    late LocalStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = await LocalStore.open();
    });

    test('starts empty at version zero', () {
      expect(store.isEmpty, isTrue);
      expect(store.version, 0);
    });

    test('round-trips a document', () async {
      await store.writeDocument(StoreKeys.session, {'userId': 7});
      expect(store.readDocument(StoreKeys.session), {'userId': 7});
    });

    test('round-trips a collection', () async {
      await store.writeCollection(StoreKeys.accounts, [
        {'id': '001', 'balance': 5000000},
        {'id': '002', 'balance': 3500000},
      ]);

      final read = store.readCollection(StoreKeys.accounts);
      expect(read, hasLength(2));
      expect(read.first['balance'], 5000000);
    });

    test('reads absent keys as empty rather than throwing', () {
      expect(store.readDocument('store.nothing'), isNull);
      expect(store.readCollection('store.nothing'), isEmpty);
    });

    test('degrades to empty when the stored value is corrupt', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        StoreKeys.accounts: 'not json at all',
        StoreKeys.session: '{ broken',
      });
      final corrupt = await LocalStore.open();

      // A bad value must not take the app down on launch.
      expect(corrupt.readCollection(StoreKeys.accounts), isEmpty);
      expect(corrupt.readDocument(StoreKeys.session), isNull);
    });

    test('migrate brings an old store up to the current version', () async {
      await store.setVersion(0);
      await store.migrate();
      expect(store.version, LocalStore.currentVersion);
    });

    test('clear removes everything the app wrote', () async {
      await store.writeCollection(StoreKeys.accounts, [
        {'id': '001'},
      ]);
      await store.setVersion(LocalStore.currentVersion);

      await store.clear();

      expect(store.readCollection(StoreKeys.accounts), isEmpty);
      expect(store.isEmpty, isTrue);
    });
  });

  group('seeding', () {
    test('first launch copies the bundled data into the store', () async {
      final backend = await createTestBackend();

      expect(backend.store.isEmpty, isFalse);
      expect(backend.store.version, LocalStore.currentVersion);
      expect(backend.repository.readAccounts(), isNotEmpty);
      expect(backend.repository.readUsers(), isNotEmpty);
      expect(backend.repository.readTransactions(), isNotEmpty);
    });

    test('amounts arrive as Money, not strings', () async {
      final backend = await createTestBackend();
      final account = backend.repository.readAccounts().first;

      expect(account.balance, isA<Money>());
      expect(account.balance.rupiah, 5000000);
      // The old shape stored `"5,000,000 "`, trailing space and all.
      expect(account.balance.formattedWithSymbol, 'Rp 5.000.000');
    });

    test('a second launch reads the store instead of reseeding', () async {
      final backend = await createTestBackend();

      // Spend from the seeded account, then rebuild the data layer over the
      // same store — as a relaunch would.
      final account = backend.accounts.accounts.first;
      await backend.accounts.debit(account.id, const Money(1000000));

      final reopened = Repository(store: backend.store);
      await reopened.ensureSeeded();

      expect(
        reopened.readAccounts().first.balance.rupiah,
        4000000,
        reason: 'reseeding would have restored the original 5.000.000',
      );
    });
  });

  group('AccountStore', () {
    test('debits an account and persists the new balance', () async {
      final backend = await createTestBackend();
      final account = backend.accounts.accounts.first;

      final failure =
          await backend.accounts.debit(account.id, const Money(250000));

      expect(failure, isNull);
      expect(backend.accounts.byId(account.id)!.balance.rupiah, 4750000);
      // Written through, not just held in memory.
      expect(backend.repository.readAccounts().first.balance.rupiah, 4750000);
    });

    test('refuses an overdraw instead of clamping at zero', () async {
      final backend = await createTestBackend();
      final account = backend.accounts.accounts.first;

      final failure =
          await backend.accounts.debit(account.id, const Money(99000000));

      expect(failure, DebitFailure.insufficientFunds);
      expect(backend.accounts.byId(account.id)!.balance.rupiah, 5000000);
    });

    test('refuses a non-positive amount and an unknown account', () async {
      final backend = await createTestBackend();
      final account = backend.accounts.accounts.first;

      expect(await backend.accounts.debit(account.id, const Money(0)),
          DebitFailure.notPositive);
      expect(await backend.accounts.debit('no-such-account', const Money(1)),
          DebitFailure.unknownAccount);
    });

    test('credit restores a balance', () async {
      final backend = await createTestBackend();
      final account = backend.accounts.accounts.first;

      await backend.accounts.debit(account.id, const Money(250000));
      await backend.accounts.credit(account.id, const Money(250000));

      expect(backend.accounts.byId(account.id)!.balance.rupiah, 5000000);
    });

    test('notifies listeners when a balance changes', () async {
      final backend = await createTestBackend();
      var notifications = 0;
      backend.accounts.addListener(() => notifications++);

      await backend.accounts
          .debit(backend.accounts.accounts.first.id, const Money(1000));

      expect(notifications, 1);
    });

    test('totals every account', () async {
      final backend = await createTestBackend();
      final expected = backend.accounts.accounts
          .fold(0, (sum, account) => sum + account.balance.rupiah);

      expect(backend.accounts.total.rupiah, expected);
    });
  });

  group('TransactionStore', () {
    test('lists newest first', () async {
      final backend = await createTestBackend();
      final dates = backend.transactions.transactions.map((t) => t.date);

      expect(
        dates.toList(),
        orderedEquals(dates.toList()..sort((a, b) => b.compareTo(a))),
      );
    });

    test('adds to the front and persists', () async {
      final backend = await createTestBackend();
      final before = backend.transactions.transactions.length;

      await backend.transactions.add(
        backend.transactions.transactions.first,
      );

      expect(backend.transactions.transactions, hasLength(before + 1));
      expect(backend.repository.readTransactions(), hasLength(before + 1));
    });

    test('search matches name and amount, and empty returns all', () async {
      final backend = await createTestBackend();

      expect(backend.transactions.search('').length,
          backend.transactions.transactions.length);
      expect(backend.transactions.search('netflix'), hasLength(1));
      expect(backend.transactions.search('181.286'), hasLength(1));
      expect(backend.transactions.search('no-such-payee'), isEmpty);
    });
  });

  group('SessionStore', () {
    test('starts signed out', () async {
      final backend = await createTestBackend();
      expect(backend.session.isSignedIn, isFalse);
      expect(backend.session.isRestored, isTrue);
    });

    test('valid credentials sign in and persist', () async {
      final backend = await createTestBackend();

      final user = await backend.session.signInWithCredentials(
        emailOrUsername: 'john.doe@newtronic.com',
        password: 'password123',
      );

      expect(user, isNotNull);
      expect(backend.session.isSignedIn, isTrue);

      // A relaunch over the same store restores the session.
      final reopened = SessionStore(
        repository: backend.repository,
        store: backend.store,
      );
      await reopened.restore();
      expect(reopened.userId, user!.id);
    });

    test('a wrong password does not sign in', () async {
      final backend = await createTestBackend();

      final user = await backend.session.signInWithCredentials(
        emailOrUsername: 'john.doe@newtronic.com',
        password: 'wrong',
      );

      expect(user, isNull);
      expect(backend.session.isSignedIn, isFalse);
    });

    test('signing out clears the saved session', () async {
      final backend = await createTestBackend();
      await backend.session.signInWithCredentials(
        emailOrUsername: 'johndoe123',
        password: 'password123',
      );

      await backend.session.signOut();

      expect(backend.session.isSignedIn, isFalse);
      expect(backend.store.readDocument(StoreKeys.session), isNull);
    });

    test('a saved session for a deleted user is not trusted', () async {
      final backend = await createTestBackend();
      await backend.store
          .writeDocument(StoreKeys.session, {'userId': 99999});

      final restored = SessionStore(
        repository: backend.repository,
        store: backend.store,
      );
      await restored.restore();

      expect(restored.isSignedIn, isFalse);
    });
  });
}
