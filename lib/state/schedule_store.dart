import 'package:flutter/foundation.dart';
import 'package:newtronic_banking/data/local/local_store.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/model/scheduled_transfer.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/state/transfer_service.dart';

/// What happened to one schedule when it came due.
class ScheduleRunResult {
  const ScheduleRunResult({
    required this.schedule,
    required this.succeeded,
    this.failureMessage,
  });

  final ScheduledTransfer schedule;
  final bool succeeded;
  final String? failureMessage;
}

/// What happened across a whole run.
class ScheduleRunReport {
  const ScheduleRunReport(this.results);

  final List<ScheduleRunResult> results;

  bool get isEmpty => results.isEmpty;
  List<ScheduleRunResult> get succeeded =>
      results.where((result) => result.succeeded).toList();
  List<ScheduleRunResult> get failed =>
      results.where((result) => !result.succeeded).toList();

  /// A one-line summary for a snackbar.
  String? get summary {
    if (isEmpty) return null;
    final done = succeeded.length;
    final failures = failed.length;

    if (failures == 0) {
      return done == 1
          ? 'Scheduled transfer to ${succeeded.first.schedule.recipientName} '
              'was sent'
          : '$done scheduled transfers were sent';
    }
    if (done == 0) {
      return failures == 1
          ? 'Scheduled transfer to ${failed.first.schedule.recipientName} '
              'could not be sent'
          : '$failures scheduled transfers could not be sent';
    }
    return '$done sent, $failures could not be sent';
  }
}

/// Recurring transfers, and the engine that applies the ones that fall due.
class ScheduleStore extends ChangeNotifier {
  ScheduleStore(this._store);

  final LocalStore _store;

  List<ScheduledTransfer> _schedules = const [];
  bool _isLoaded = false;

  List<ScheduledTransfer> get schedules => List.unmodifiable(_schedules);
  bool get isLoaded => _isLoaded;
  bool get isEmpty => _schedules.isEmpty;

  Future<void> load() async {
    _schedules = _store
        .readCollection(StoreKeys.schedules)
        .map(ScheduledTransfer.fromJson)
        .toList()
      ..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));
    _isLoaded = true;
    notifyListeners();
  }

  ScheduledTransfer? byId(String id) {
    for (final schedule in _schedules) {
      if (schedule.id == id) return schedule;
    }
    return null;
  }

  List<ScheduledTransfer> dueAt(DateTime now) =>
      _schedules.where((schedule) => schedule.isDue(now)).toList();

  Future<void> add(ScheduledTransfer schedule) async {
    _schedules = [..._schedules, schedule]
      ..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _schedules = _schedules.where((schedule) => schedule.id != id).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> setPaused(String id, bool isPaused) async {
    await _replace(id, (schedule) => schedule.copyWith(isPaused: isPaused));
  }

  /// Applies every schedule that has fallen due.
  ///
  /// Each due schedule runs **once**, however far overdue it is, then advances
  /// to its next date after [now]. Running every missed occurrence would drain
  /// an account the moment the app is opened after a break — a much worse
  /// surprise than a skipped payment.
  ///
  /// A failure is recorded on the schedule and the date still advances, so a
  /// single month of insufficient funds does not leave it permanently stuck
  /// and retrying on every launch.
  Future<ScheduleRunReport> runDue({
    required DateTime now,
    required TransferService transfers,
    required int userId,
  }) async {
    final due = dueAt(now);
    if (due.isEmpty) return const ScheduleRunReport([]);

    final results = <ScheduleRunResult>[];

    for (final schedule in due) {
      final outcome = await transfers.execute(
        TransferReceipt(
          userId: userId,
          recipientName: schedule.recipientName,
          bankName: schedule.bankName,
          bankImage: schedule.bankImage,
          accountNumber: schedule.accountNumber,
          sourceAccountId: schedule.sourceAccountId,
          sourceAccountName: schedule.sourceAccountName,
          nominal: schedule.amount,
          transactionType: schedule.transactionType,
          reference: _referenceFor(schedule, now),
          createdAt: now,
          note: schedule.note,
        ),
      );

      final advanced = ScheduleDates.catchUp(
        schedule.nextDueAt,
        schedule.frequency,
        now,
      );

      await _replace(
        schedule.id,
        (current) => current.copyWith(
          nextDueAt: advanced,
          lastRunAt: now,
          lastFailure: outcome.isSuccess ? null : outcome.failure!.message,
          clearFailure: outcome.isSuccess,
        ),
        notify: false,
      );

      results.add(ScheduleRunResult(
        schedule: schedule,
        succeeded: outcome.isSuccess,
        failureMessage: outcome.isSuccess ? null : outcome.failure!.message,
      ));
    }

    notifyListeners();
    return ScheduleRunReport(results);
  }

  /// A 16-digit reference derived from the schedule and the run time, so two
  /// runs of the same schedule do not collide in the history.
  String _referenceFor(ScheduledTransfer schedule, DateTime now) {
    final digits =
        '${schedule.id.hashCode.abs()}${now.millisecondsSinceEpoch}'
            .padRight(16, '0')
            .substring(0, 16);
    return '${digits.substring(0, 4)} ${digits.substring(4, 8)} '
        '${digits.substring(8, 12)} ${digits.substring(12, 16)}';
  }

  Future<void> _replace(
    String id,
    ScheduledTransfer Function(ScheduledTransfer schedule) update, {
    bool notify = true,
  }) async {
    _schedules = [
      for (final schedule in _schedules)
        if (schedule.id == id) update(schedule) else schedule,
    ]..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));

    await _persist();
    if (notify) notifyListeners();
  }

  Future<void> _persist() => _store.writeCollection(
        StoreKeys.schedules,
        _schedules.map((schedule) => schedule.toJson()).toList(),
      );

  /// Builds a schedule from the form's fields.
  static ScheduledTransfer create({
    required String recipientName,
    required String bankName,
    required String bankImage,
    required String accountNumber,
    required String sourceAccountId,
    required String sourceAccountName,
    required Money amount,
    required ScheduleFrequency frequency,
    required DateTime firstDueAt,
    required DateTime createdAt,
    String transactionType = 'BI-FAST',
    String? note,
  }) =>
      ScheduledTransfer(
        id: 'sched-${createdAt.microsecondsSinceEpoch}',
        recipientName: recipientName,
        bankName: bankName,
        bankImage: bankImage,
        accountNumber: accountNumber,
        sourceAccountId: sourceAccountId,
        sourceAccountName: sourceAccountName,
        amount: amount,
        frequency: frequency,
        nextDueAt: firstDueAt,
        createdAt: createdAt,
        transactionType: transactionType,
        note: note,
      );
}
