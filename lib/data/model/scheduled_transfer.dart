import 'package:newtronic_banking/data/model/money.dart';

/// How often a scheduled transfer repeats.
enum ScheduleFrequency {
  weekly,
  monthly;

  String get label => switch (this) {
        ScheduleFrequency.weekly => 'Weekly',
        ScheduleFrequency.monthly => 'Monthly',
      };

  static ScheduleFrequency fromName(String? name) =>
      ScheduleFrequency.values.firstWhere(
        (frequency) => frequency.name == name,
        orElse: () => ScheduleFrequency.monthly,
      );
}

/// A transfer set to repeat.
///
/// There is no background scheduler behind this. Nothing runs while the app is
/// closed — due transfers are found and applied when the app next opens, which
/// is the only honest option on web and avoids a notification dependency that
/// does not exist on every platform this ships to.
class ScheduledTransfer {
  const ScheduledTransfer({
    required this.id,
    required this.recipientName,
    required this.bankName,
    required this.bankImage,
    required this.accountNumber,
    required this.sourceAccountId,
    required this.sourceAccountName,
    required this.amount,
    required this.frequency,
    required this.nextDueAt,
    required this.createdAt,
    this.transactionType = 'BI-FAST',
    this.note,
    this.isPaused = false,
    this.lastRunAt,
    this.lastFailure,
  });

  factory ScheduledTransfer.fromJson(Map<String, dynamic> json) =>
      ScheduledTransfer(
        id: json['id'] as String,
        recipientName: json['recipient_name'] as String,
        bankName: json['bank_name'] as String,
        bankImage: json['bank_image'] as String? ?? '',
        accountNumber: json['account_number'] as String,
        sourceAccountId: json['source_account_id'] as String,
        sourceAccountName: json['source_account_name'] as String? ?? '',
        amount: Money.parse(json['amount']),
        frequency: ScheduleFrequency.fromName(json['frequency'] as String?),
        nextDueAt: DateTime.parse(json['next_due_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        transactionType: json['transaction_type'] as String? ?? 'BI-FAST',
        note: json['note'] as String?,
        isPaused: json['is_paused'] as bool? ?? false,
        lastRunAt: json['last_run_at'] == null
            ? null
            : DateTime.parse(json['last_run_at'] as String),
        lastFailure: json['last_failure'] as String?,
      );

  final String id;
  final String recipientName;
  final String bankName;
  final String bankImage;
  final String accountNumber;
  final String sourceAccountId;
  final String sourceAccountName;
  final Money amount;
  final ScheduleFrequency frequency;

  /// When this is next meant to run. Always the source of truth for "due".
  final DateTime nextDueAt;

  final DateTime createdAt;
  final String transactionType;
  final String? note;
  final bool isPaused;
  final DateTime? lastRunAt;

  /// Why the last attempt failed, kept so the failure is visible on the card
  /// rather than disappearing with the run that produced it.
  final String? lastFailure;

  bool isDue(DateTime now) => !isPaused && !nextDueAt.isAfter(now);

  ScheduledTransfer copyWith({
    DateTime? nextDueAt,
    bool? isPaused,
    DateTime? lastRunAt,
    String? lastFailure,
    bool clearFailure = false,
  }) =>
      ScheduledTransfer(
        id: id,
        recipientName: recipientName,
        bankName: bankName,
        bankImage: bankImage,
        accountNumber: accountNumber,
        sourceAccountId: sourceAccountId,
        sourceAccountName: sourceAccountName,
        amount: amount,
        frequency: frequency,
        nextDueAt: nextDueAt ?? this.nextDueAt,
        createdAt: createdAt,
        transactionType: transactionType,
        note: note,
        isPaused: isPaused ?? this.isPaused,
        lastRunAt: lastRunAt ?? this.lastRunAt,
        lastFailure: clearFailure ? null : (lastFailure ?? this.lastFailure),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipient_name': recipientName,
        'bank_name': bankName,
        'bank_image': bankImage,
        'account_number': accountNumber,
        'source_account_id': sourceAccountId,
        'source_account_name': sourceAccountName,
        'amount': amount.toJson(),
        'frequency': frequency.name,
        'next_due_at': nextDueAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'transaction_type': transactionType,
        if (note != null) 'note': note,
        'is_paused': isPaused,
        if (lastRunAt != null) 'last_run_at': lastRunAt!.toIso8601String(),
        if (lastFailure != null) 'last_failure': lastFailure,
      };
}

/// Works out when a schedule falls due.
abstract final class ScheduleDates {
  /// The next occurrence strictly after [from].
  ///
  /// Monthly keeps the day of the month where it can and clamps where it
  /// cannot: the 31st becomes the 30th, or the 28th/29th in February, rather
  /// than rolling forward into the next month.
  static DateTime next(DateTime from, ScheduleFrequency frequency) =>
      switch (frequency) {
        ScheduleFrequency.weekly => from.add(const Duration(days: 7)),
        ScheduleFrequency.monthly => _addMonth(from),
      };

  /// The first occurrence strictly after [now], advancing repeatedly.
  ///
  /// A schedule left unopened for months catches up to the present in one
  /// step. That is deliberate: running every missed occurrence would empty an
  /// account without warning the moment the app is opened, which is a far
  /// worse surprise than a single missed payment.
  static DateTime catchUp(
    DateTime dueAt,
    ScheduleFrequency frequency,
    DateTime now, {
    int maxSteps = 600,
  }) {
    var next = dueAt;
    var steps = 0;
    while (!next.isAfter(now) && steps < maxSteps) {
      next = ScheduleDates.next(next, frequency);
      steps++;
    }
    return next;
  }

  static DateTime _addMonth(DateTime from) {
    final targetYear = from.month == 12 ? from.year + 1 : from.year;
    final targetMonth = from.month == 12 ? 1 : from.month + 1;
    final lastDay = _daysInMonth(targetYear, targetMonth);

    return DateTime(
      targetYear,
      targetMonth,
      from.day > lastDay ? lastDay : from.day,
      from.hour,
      from.minute,
    );
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;
}
