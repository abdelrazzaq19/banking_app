import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/model/balance_model.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

/// Hero tag for an account's card, shared between the carousel and the detail
/// screen so the card flies rather than cuts.
String balanceCardHeroTag(Balances balance) => 'balance-card-${balance.id}';

/// One account, as a frosted gradient card.
///
/// Used at two sizes: in the home carousel, and enlarged on the detail screen.
/// [showActions] is what differs — the detail screen has its own action row.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    required this.label,
    this.onTap,
    this.onMove,
    this.onQris,
    this.showActions = true,
    this.height,
    this.animateBalance = true,
  });

  final Balances balance;

  /// "Account" or "Card", depending on which tab is showing.
  final String label;

  final VoidCallback? onTap;
  final VoidCallback? onMove;
  final VoidCallback? onQris;
  final bool showActions;
  final double? height;

  /// Counting up is right on arrival, wrong when the card is already on screen
  /// as a Hero destination — there it should simply be at its value.
  final bool animateBalance;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amount = balance.balance;

    return GlassCard(
      height: height,
      onTap: onTap,
      semanticLabel: '${balance.cardName} $label, '
          'balance ${amount.formattedWithSymbol}',
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${balance.cardName} $label',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: colors.onCard),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Insets.xxs),
                    Text(
                      balance.cardNumber,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.onCard),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.contactless_rounded,
                color: colors.onCard.withValues(alpha: 0.8),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Balance',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.onCard.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: Insets.xxs),
              if (animateBalance)
                AnimatedBalance(
                  amount: amount.rupiah,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: colors.onCard),
                )
              else
                Text(
                  amount.formattedWithSymbol,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: colors.onCard),
                ),
            ],
          ),
          if (showActions)
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'MOVE',
                    icon: Icons.wallet_rounded,
                    variant: AppButtonVariant.onCard,
                    size: AppButtonSize.medium,
                    onPressed: onMove,
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: AppButton(
                    label: 'QRIS',
                    icon: Icons.qr_code_rounded,
                    variant: AppButtonVariant.onCard,
                    size: AppButtonSize.medium,
                    onPressed: onQris,
                  ),
                ),
              ],
            )
          else
            Text(
              'Exp ${balance.expiryDate}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.onCard),
            ),
        ],
      ),
    );
  }
}
