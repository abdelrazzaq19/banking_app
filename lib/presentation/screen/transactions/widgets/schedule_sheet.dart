import 'package:flutter/material.dart';
import 'package:newtronic_banking/common/constants.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/model/balance_model.dart';
import 'package:newtronic_banking/data/model/favourite_transfer.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/model/scheduled_transfer.dart';
import 'package:newtronic_banking/data/utils/currency_input_formatter.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';
import 'package:newtronic_banking/state/schedule_store.dart';

/// Sets up a repeating transfer to a saved recipient.
///
/// Only offered for favourites: a schedule needs a destination that will still
/// be there next month, and asking for full bank details inside a sheet would
/// duplicate the transfer form badly.
Future<ScheduledTransfer?> showScheduleSheet({
  required BuildContext context,
  required FavouriteTransfer favourite,
  required List<Balances> accounts,
  DateTime? now,
}) {
  if (accounts.isEmpty) return Future<ScheduledTransfer?>.value();

  return showModalBottomSheet<ScheduledTransfer>(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: Alphas.scrim),
    shape: const RoundedRectangleBorder(borderRadius: Radii.sheetTop),
    builder: (sheetContext) => _ScheduleSheet(
      favourite: favourite,
      accounts: accounts,
      now: now ?? DateTime.now(),
    ),
  );
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({
    required this.favourite,
    required this.accounts,
    required this.now,
  });

  final FavouriteTransfer favourite;
  final List<Balances> accounts;
  final DateTime now;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late final TextEditingController _amountController = TextEditingController(
    text: widget.favourite.amount?.formatted ?? '',
  );

  late Balances _source = widget.accounts.first;
  ScheduleFrequency _frequency = ScheduleFrequency.monthly;
  late DateTime _firstDueAt = widget.now.add(const Duration(days: 1));

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDueAt,
      // Starting today at the earliest: a schedule dated in the past would
      // fire the moment it is created, which is never what was meant.
      firstDate: widget.now,
      lastDate: DateTime(widget.now.year + 5),
    );
    if (picked != null) setState(() => _firstDueAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amount = parseRupiah(_amountController.text);
    final canSave = amount != null && amount > 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Insets.lg,
          right: Insets.lg,
          top: Insets.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + Insets.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              Text(
                'Repeat this transfer',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Insets.xxs),
              Text(
                'to ${widget.favourite.recipientName} · '
                '${widget.favourite.bankName}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.subtleText),
              ),
              const SizedBox(height: Insets.lg),
              AppTextField(
                controller: _amountController,
                hintText: 'Amount',
                semanticLabel: 'Scheduled amount in rupiah',
                useTabularFigures: true,
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsSeparatorInputFormatter()],
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Insets.md),
              DropdownButtonFormField<String>(
                initialValue: _source.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'From account'),
                items: [
                  for (final account in widget.accounts)
                    DropdownMenuItem<String>(
                      value: account.id,
                      child: Text(
                        '${account.cardName} · '
                        '${account.balance.formattedWithSymbol}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) => setState(() {
                  _source = widget.accounts.firstWhere((a) => a.id == id);
                }),
              ),
              const SizedBox(height: Insets.md),
              SegmentedButton<ScheduleFrequency>(
                segments: [
                  for (final frequency in ScheduleFrequency.values)
                    ButtonSegment(
                      value: frequency,
                      label: Text(frequency.label),
                    ),
                ],
                selected: {_frequency},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    setState(() => _frequency = selection.first),
              ),
              const SizedBox(height: Insets.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: const Text('First payment'),
                subtitle: Text(formattedTransactionDate(_firstDueAt)),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: const Text('Change'),
                ),
              ),
              const SizedBox(height: Insets.sm),
              Text(
                'Scheduled transfers run when you next open the app on or '
                'after the due date. Nothing happens while the app is closed.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.subtleText),
              ),
              const SizedBox(height: Insets.lg),
              AppButton(
                label: 'Schedule it',
                onPressed: canSave
                    ? () => Navigator.of(context).pop(
                          ScheduleStore.create(
                            recipientName: widget.favourite.recipientName,
                            bankName: widget.favourite.bankName,
                            bankImage: widget.favourite.bankImage,
                            accountNumber: widget.favourite.accountNumber,
                            sourceAccountId: _source.id,
                            sourceAccountName: _source.cardName,
                            amount: Money(amount),
                            frequency: _frequency,
                            firstDueAt: _firstDueAt,
                            createdAt: DateTime.now(),
                            transactionType:
                                widget.favourite.transactionType ??
                                    transactionTypes.first,
                            note: widget.favourite.note,
                          ),
                        )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
