import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

/// The receipt for a completed transfer.
///
/// Split out from the screen because Task 14 renders this same widget offscreen
/// to produce the PNG and PDF exports — what the user sees and what they share
/// should be the same thing, not two layouts that drift apart.
class ReceiptCard extends StatelessWidget {
  const ReceiptCard({
    super.key,
    required this.receipt,
    this.initiallyExpanded = false,
  });

  final TransferReceipt receipt;

  /// Opens the fee breakdown on first build. The export uses this so the
  /// shared copy shows everything.
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: Radii.lgAll,
        border: Border.all(color: colors.mutedBorder),
      ),
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  'Transfer successful',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.success,
                  ),
                ),
                const SizedBox(height: Insets.xxs),
                Text(
                  receipt.nominal.formattedWithSymbol,
                  style: textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          _RecipientRow(receipt: receipt),
          const SizedBox(height: Insets.md),
          const DashedDivider(),
          const SizedBox(height: Insets.sm),
          _Row(label: 'From', value: receipt.sourceAccountName),
          _Row(label: 'Transaction type', value: receipt.transactionType),
          _Row(label: 'Reference', value: receipt.reference),
          _Row(
            label: 'Date',
            value: formattedTransactionDate(receipt.createdAt),
          ),
          if (receipt.note != null)
            _Row(label: 'Note', value: receipt.note!),
          const SizedBox(height: Insets.xs),
          _FeeBreakdown(
            receipt: receipt,
            initiallyExpanded: initiallyExpanded,
          ),
        ],
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

/// The amount, the fee, and what actually left the account.
class _FeeBreakdown extends StatelessWidget {
  const _FeeBreakdown({required this.receipt, required this.initiallyExpanded});

  final TransferReceipt receipt;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // The default expansion tile paints its own dividers, which would fight
      // the dashed rule above it.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(
          'Detail',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        children: [
          _Row(
            label: 'Transfer amount',
            value: receipt.nominal.formattedWithSymbol,
          ),
          _Row(
            label: 'Admin fee',
            value: receipt.adminFee.formattedWithSymbol,
          ),
          const SizedBox(height: Insets.xs),
          const DashedDivider(),
          const SizedBox(height: Insets.xs),
          _Row(
            label: 'Total debited',
            value: receipt.total.formattedWithSymbol,
            emphasise: true,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
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
              style: emphasise ? textTheme.titleMedium : textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
