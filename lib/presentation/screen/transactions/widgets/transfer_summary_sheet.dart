import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

/// The last screen before money moves: everything about the transfer, laid out
/// to be checked.
///
/// Resolves to `true` when confirmed, `false` or `null` when dismissed. This
/// replaces a generic "Are you sure?" dialog, which asked for confirmation
/// without showing what was being confirmed.
Future<bool?> showTransferSummarySheet({
  required BuildContext context,
  required TransferReceipt receipt,
  required Money balanceAfter,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: Alphas.scrim),
    shape: const RoundedRectangleBorder(borderRadius: Radii.sheetTop),
    builder: (sheetContext) => _TransferSummarySheet(
      receipt: receipt,
      balanceAfter: balanceAfter,
    ),
  );
}

class _TransferSummarySheet extends StatelessWidget {
  const _TransferSummarySheet({
    required this.receipt,
    required this.balanceAfter,
  });

  final TransferReceipt receipt;
  final Money balanceAfter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Insets.lg,
          right: Insets.lg,
          top: Insets.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + Insets.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            Text('Review transfer', style: textTheme.titleLarge),
            const SizedBox(height: Insets.lg),

            // The amount, given the weight it deserves.
            Center(
              child: Text(
                receipt.nominal.formattedWithSymbol,
                style: textTheme.displaySmall,
              ),
            ),
            const SizedBox(height: Insets.lg),

            _RecipientRow(receipt: receipt),
            const SizedBox(height: Insets.md),
            const Divider(height: 1),
            const SizedBox(height: Insets.sm),

            _SummaryRow(label: 'From', value: receipt.sourceAccountName),
            _SummaryRow(label: 'Type', value: receipt.transactionType),
            if (receipt.note != null)
              _SummaryRow(label: 'Note', value: receipt.note!),
            _SummaryRow(
              label: 'Admin fee',
              value: receipt.adminFee.formattedWithSymbol,
            ),
            const SizedBox(height: Insets.xs),
            const Divider(height: 1),
            const SizedBox(height: Insets.xs),
            _SummaryRow(
              label: 'Total debited',
              value: receipt.total.formattedWithSymbol,
              emphasise: true,
            ),
            _SummaryRow(
              label: 'Balance after',
              value: balanceAfter.formattedWithSymbol,
              valueColor: balanceAfter.isNegative ? context.scheme.error : colors.success,
            ),

            const SizedBox(height: Insets.lg),
            AppButton(
              label: 'Confirm transfer',
              icon: Icons.lock_rounded,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: Insets.xs),
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({required this.receipt});

  final TransferReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        ClipRRect(
          borderRadius: Radii.pillAll,
          child: RemoteImage(
            url: receipt.bankImage,
            size: 44,
            fallback: (context) => const BankLogoFallback(size: 44),
          ),
        ),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                receipt.recipientName,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${receipt.bankName} · '
                '${maskedBankNumber(receipt.accountNumber)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.subtleText),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasise = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasise;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium
                  ?.copyWith(color: context.colors.subtleText),
            ),
          ),
          const SizedBox(width: Insets.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: (emphasise ? textTheme.titleMedium : textTheme.titleSmall)
                  ?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
