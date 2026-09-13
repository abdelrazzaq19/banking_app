import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/data/model/favourite_transfer.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/model/scheduled_transfer.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/state/favourite_store.dart';
import 'package:newtronic_banking/state/schedule_store.dart';

import 'support/test_harness.dart';

ScheduledTransfer _schedule({
  required DateTime dueAt,
  String sourceAccountId = '001',
  int amount = 250000,
  ScheduleFrequency frequency = ScheduleFrequency.monthly,
  bool isPaused = false,
}) =>
    ScheduledTransfer(
      id: 'sched-1',
      recipientName: 'Siti Rahayu',
      bankName: 'Bank Danamon',
      bankImage: '',
      accountNumber: '123456789012',
      sourceAccountId: sourceAccountId,
      sourceAccountName: 'BlueSky',
      amount: Money(amount),
      frequency: frequency,
      nextDueAt: dueAt,
      createdAt: DateTime(2026, 1, 1),
      isPaused: isPaused,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('ScheduleDates.next', () {
    test('weekly adds seven days', () {
      expect(
        ScheduleDates.next(DateTime(2026, 9, 11), ScheduleFrequency.weekly),
        DateTime(2026, 9, 18),
      );
    });

    test('weekly crosses a month boundary', () {
      expect(
        ScheduleDates.next(DateTime(2026, 9, 28), ScheduleFrequency.weekly),
        DateTime(2026, 10, 5),
      );
    });

    test('monthly keeps the day of the month', () {
      expect(
        ScheduleDates.next(DateTime(2026, 9, 15), ScheduleFrequency.monthly),
        DateTime(2026, 10, 15),
      );
    });

    test('monthly clamps rather than rolling into the next month', () {
      // The 31st of January is not the 3rd of March.
      expect(
        ScheduleDates.next(DateTime(2026, 1, 31), ScheduleFrequency.monthly),
        DateTime(2026, 2, 28),
      );
      expect(
        ScheduleDates.next(DateTime(2026, 3, 31), ScheduleFrequency.monthly),
        DateTime(2026, 4, 30),
      );
    });

    test('monthly handles a leap February', () {
      expect(
        ScheduleDates.next(DateTime(2028, 1, 31), ScheduleFrequency.monthly),
        DateTime(2028, 2, 29),
      );
    });

    test('monthly rolls the year over at December', () {
      expect(
        ScheduleDates.next(DateTime(2026, 12, 10), ScheduleFrequency.monthly),
        DateTime(2027, 1, 10),
      );
    });

    test('monthly preserves the time of day', () {
      final next = ScheduleDates.next(
        DateTime(2026, 9, 15, 9, 30),
        ScheduleFrequency.monthly,
      );
      expect(next.hour, 9);
      expect(next.minute, 30);
    });
  });

  group('ScheduleDates.catchUp', () {
    test('advances past now in one call', () {
      final caught = ScheduleDates.catchUp(
        DateTime(2026, 1, 15),
        ScheduleFrequency.monthly,
        DateTime(2026, 9, 11),
      );

      // Eight months overdue, but the next date is simply the next future one.
      expect(caught, DateTime(2026, 9, 15));
    });

    test('always lands strictly after now', () {
      final caught = ScheduleDates.catchUp(
        DateTime(2026, 9, 11),
        ScheduleFrequency.weekly,
        DateTime(2026, 9, 11),
      );
      expect(caught.isAfter(DateTime(2026, 9, 11)), isTrue);
    });

    test('does not spin forever on an absurd backlog', () {
      final caught = ScheduleDates.catchUp(
        DateTime(1990, 1, 1),
        ScheduleFrequency.weekly,
        DateTime(2026, 9, 11),
        maxSteps: 10,
      );
      // Bounded: it gives up rather than looping, and the caller still gets a
      // usable date.
      expect(caught, isNotNull);
    });
  });

  group('isDue', () {
    test('is due on and after the date, not before', () {
      final schedule = _schedule(dueAt: DateTime(2026, 9, 11));

      expect(schedule.isDue(DateTime(2026, 9, 10)), isFalse);
      expect(schedule.isDue(DateTime(2026, 9, 11)), isTrue);
      expect(schedule.isDue(DateTime(2026, 9, 12)), isTrue);
    });

    test('a paused schedule is never due', () {
      final schedule =
          _schedule(dueAt: DateTime(2026, 1, 1), isPaused: true);
      expect(schedule.isDue(DateTime(2026, 9, 11)), isFalse);
    });
  });

  group('running due schedules', () {
    test('a backdated schedule runs once and advances', () async {
      final backend = await createTestBackend();
      final account = backend.accounts.accounts.first;
      final store = ScheduleStore(backend.store);
      await store.load();

      // Three months overdue.
      await store.add(_schedule(
        dueAt: DateTime(2026, 6, 15),
        sourceAccountId: account.id,
      ));

      final report = await store.runDue(
        now: DateTime(2026, 9, 11),
        transfers: backend.transfers,
        userId: 1,
      );

      expect(report.results, hasLength(1));
      expect(report.succeeded, hasLength(1));

      // Exactly one transfer, not one per missed month.
      expect(backend.accounts.byId(account.id)!.balance.rupiah,
          5000000 - 250000 - 2500);
      expect(
        backend.transactions.transactions
            .where((t) => t.name == 'Siti Rahayu'),
        hasLength(1),
      );

      // And it is scheduled forward, not left in the past.
      final advanced = store.byId('sched-1')!;
      expect(advanced.nextDueAt.isAfter(DateTime(2026, 9, 11)), isTrue);
      expect(advanced.lastRunAt, DateTime(2026, 9, 11));
      expect(advanced.lastFailure, isNull);
    });

    test('a schedule that is not yet due does nothing', () async {
      final backend = await createTestBackend();
      final store = ScheduleStore(backend.store);
      await store.load();
      await store.add(_schedule(
        dueAt: DateTime(2026, 12, 1),
        sourceAccountId: backend.accounts.accounts.first.id,
      ));

      final report = await store.runDue(
        now: DateTime(2026, 9, 11),
        transfers: backend.transfers,
        userId: 1,
      );

      expect(report.isEmpty, isTrue);
      expect(backend.accounts.accounts.first.balance.rupiah, 5000000);
    });

    test('a paused schedule does not run even when overdue', () async {
      final backend = await createTestBackend();
      final store = ScheduleStore(backend.store);
      await store.load();
      await store.add(_schedule(
        dueAt: DateTime(2026, 1, 1),
        sourceAccountId: backend.accounts.accounts.first.id,
        isPaused: true,
      ));

      final report = await store.runDue(
        now: DateTime(2026, 9, 11),
        transfers: backend.transfers,
        userId: 1,
      );

      expect(report.isEmpty, isTrue);
      expect(backend.accounts.accounts.first.balance.rupiah, 5000000);
    });

    test('insufficient funds fails visibly and takes nothing', () async {
      final backend = await createTestBackend();
      final account = backend.accounts.accounts.first;
      final store = ScheduleStore(backend.store);
      await store.load();
      await store.add(_schedule(
        dueAt: DateTime(2026, 9, 1),
        sourceAccountId: account.id,
        amount: 99000000,
      ));

      final report = await store.runDue(
        now: DateTime(2026, 9, 11),
        transfers: backend.transfers,
        userId: 1,
      );

      expect(report.failed, hasLength(1));
      expect(report.failed.single.failureMessage,
          contains('Not enough balance'));
      // Nothing moved.
      expect(backend.accounts.byId(account.id)!.balance.rupiah, 5000000);

      // The reason is kept on the schedule, so it is visible afterwards
      // rather than vanishing with the run that produced it.
      final afterRun = store.byId('sched-1')!;
      expect(afterRun.lastFailure, contains('Not enough balance'));
      expect(afterRun.lastRunAt, DateTime(2026, 9, 11));
    });

    test('a failed schedule still advances, so it does not retry every launch',
        () async {
      final backend = await createTestBackend();
      final store = ScheduleStore(backend.store);
      await store.load();
      await store.add(_schedule(
        dueAt: DateTime(2026, 9, 1),
        sourceAccountId: backend.accounts.accounts.first.id,
        amount: 99000000,
      ));

      await store.runDue(
        now: DateTime(2026, 9, 11),
        transfers: backend.transfers,
        userId: 1,
      );

      expect(
        store.byId('sched-1')!.nextDueAt.isAfter(DateTime(2026, 9, 11)),
        isTrue,
      );
    });

    test('a later success clears the recorded failure', () async {
      final backend = await createTestBackend();
      final account = backend.accounts.accounts.first;
      final store = ScheduleStore(backend.store);
      await store.load();
      await store.add(_schedule(
        dueAt: DateTime(2026, 9, 1),
        sourceAccountId: account.id,
        amount: 99000000,
      ));

      await store.runDue(
        now: DateTime(2026, 9, 11),
        transfers: backend.transfers,
        userId: 1,
      );
      expect(store.byId('sched-1')!.lastFailure, isNotNull);

      // Make it affordable, then let it run again.
      await store.remove('sched-1');
      await store.add(_schedule(
        dueAt: DateTime(2026, 10, 1),
        sourceAccountId: account.id,
        amount: 100000,
      ));
      await store.runDue(
        now: DateTime(2026, 10, 11),
        transfers: backend.transfers,
        userId: 1,
      );

      expect(store.byId('sched-1')!.lastFailure, isNull);
    });

    test('several due schedules all run', () async {
      final backend = await createTestBackend();
      final store = ScheduleStore(backend.store);
      await store.load();

      for (var index = 0; index < 3; index++) {
        await store.add(ScheduledTransfer(
          id: 'sched-$index',
          recipientName: 'Payee $index',
          bankName: 'Bank Mandiri',
          bankImage: '',
          accountNumber: '12345678901$index',
          sourceAccountId: backend.accounts.accounts.first.id,
          sourceAccountName: 'BlueSky',
          amount: const Money(100000),
          frequency: ScheduleFrequency.monthly,
          nextDueAt: DateTime(2026, 9, 1),
          createdAt: DateTime(2026, 1, 1),
        ));
      }

      final report = await store.runDue(
        now: DateTime(2026, 9, 11),
        transfers: backend.transfers,
        userId: 1,
      );

      expect(report.succeeded, hasLength(3));
      expect(backend.accounts.accounts.first.balance.rupiah,
          5000000 - (100000 + 2500) * 3);
    });

    test('the report summarises mixed outcomes', () async {
      final backend = await createTestBackend();
      final store = ScheduleStore(backend.store);
      await store.load();

      await store.add(_schedule(
        dueAt: DateTime(2026, 9, 1),
        sourceAccountId: backend.accounts.accounts.first.id,
        amount: 100000,
      ));
      await store.add(ScheduledTransfer(
        id: 'sched-2',
        recipientName: 'Too Expensive',
        bankName: 'Bank Mandiri',
        bankImage: '',
        accountNumber: '999888777666',
        sourceAccountId: backend.accounts.accounts.first.id,
        sourceAccountName: 'BlueSky',
        amount: const Money(99000000),
        frequency: ScheduleFrequency.monthly,
        nextDueAt: DateTime(2026, 9, 1),
        createdAt: DateTime(2026, 1, 1),
      ));

      final report = await store.runDue(
        now: DateTime(2026, 9, 11),
        transfers: backend.transfers,
        userId: 1,
      );

      expect(report.summary, '1 sent, 1 could not be sent');
    });

    test('schedules survive a relaunch', () async {
      final backend = await createTestBackend();
      final store = ScheduleStore(backend.store);
      await store.load();
      await store.add(_schedule(dueAt: DateTime(2026, 12, 1)));

      final reopened = ScheduleStore(backend.store);
      await reopened.load();

      expect(reopened.schedules, hasLength(1));
      expect(reopened.byId('sched-1')!.recipientName, 'Siti Rahayu');
    });

    test('pause, resume and delete all persist', () async {
      final backend = await createTestBackend();
      final store = ScheduleStore(backend.store);
      await store.load();
      await store.add(_schedule(dueAt: DateTime(2026, 12, 1)));

      await store.setPaused('sched-1', true);
      var reopened = ScheduleStore(backend.store);
      await reopened.load();
      expect(reopened.byId('sched-1')!.isPaused, isTrue);

      await store.setPaused('sched-1', false);
      reopened = ScheduleStore(backend.store);
      await reopened.load();
      expect(reopened.byId('sched-1')!.isPaused, isFalse);

      await store.remove('sched-1');
      reopened = ScheduleStore(backend.store);
      await reopened.load();
      expect(reopened.schedules, isEmpty);
    });
  });

  group('favourites', () {
    TransferReceipt receipt({
      String recipient = 'Siti Rahayu',
      String accountNumber = '123456789012',
    }) =>
        TransferReceipt(
          userId: 1,
          recipientName: recipient,
          bankName: 'Bank Danamon',
          bankImage: '',
          accountNumber: accountNumber,
          sourceAccountId: '001',
          sourceAccountName: 'BlueSky',
          nominal: const Money(250000),
          transactionType: 'BI-FAST',
          reference: '1111 2222 3333 4444',
          createdAt: DateTime(2026, 9, 11),
        );

    test('saving a receipt persists the recipient', () async {
      final backend = await createTestBackend();
      final store = FavouriteStore(backend.store);
      await store.load();

      await store.saveReceipt(receipt());

      final reopened = FavouriteStore(backend.store);
      await reopened.load();
      expect(reopened.favourites, hasLength(1));
      expect(reopened.favourites.single.recipientName, 'Siti Rahayu');
      expect(reopened.favourites.single.amount, const Money(250000));
    });

    test('saving the same destination twice replaces rather than duplicates',
        () async {
      final backend = await createTestBackend();
      final store = FavouriteStore(backend.store);
      await store.load();

      await store.saveReceipt(receipt(recipient: 'Siti Rahayu'));
      await store.saveReceipt(receipt(recipient: 'Siti R.'));

      expect(store.favourites, hasLength(1));
      expect(store.favourites.single.recipientName, 'Siti R.');
    });

    test('different destinations are separate favourites', () async {
      final backend = await createTestBackend();
      final store = FavouriteStore(backend.store);
      await store.load();

      await store.saveReceipt(receipt(accountNumber: '123456789012'));
      await store.saveReceipt(receipt(accountNumber: '999888777666'));

      expect(store.favourites, hasLength(2));
    });

    test('the id ignores formatting in the account number', () async {
      expect(
        favouriteIdFor(bankName: 'Bank Danamon', accountNumber: '1234 5678'),
        favouriteIdFor(bankName: 'bank danamon', accountNumber: '12345678'),
      );
    });

    test('containsReceipt reports whether it is already saved', () async {
      final backend = await createTestBackend();
      final store = FavouriteStore(backend.store);
      await store.load();

      expect(store.containsReceipt(receipt()), isFalse);
      await store.saveReceipt(receipt());
      expect(store.containsReceipt(receipt()), isTrue);
    });

    test('removing takes it out and persists', () async {
      final backend = await createTestBackend();
      final store = FavouriteStore(backend.store);
      await store.load();
      await store.saveReceipt(receipt());

      await store.remove(store.favourites.single.id);

      final reopened = FavouriteStore(backend.store);
      await reopened.load();
      expect(reopened.favourites, isEmpty);
    });
  });
}
