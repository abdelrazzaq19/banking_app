import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/model/balance_model.dart';
import 'package:newtronic_banking/presentation/screen/main/widgets/balance_card.dart';
import 'package:newtronic_banking/presentation/screen/qr/qr_actions.dart';
import 'package:newtronic_banking/presentation/screen/transactions/add_transaction_screen.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

/// Where a balance card lands when tapped.
///
/// The card itself flies in as a [Hero] from the home carousel, so the account
/// stays continuous across the navigation rather than the screen cutting to an
/// unrelated layout.
class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({
    super.key,
    required this.balance,
    required this.label,
    required this.userId,
  });

  final Balances balance;
  final String label;
  final int userId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amount = balance.balance;

    return Scaffold(
      backgroundColor: colors.headerBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.onHeader,
        title: Text(
          balance.cardName,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: colors.onHeader),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Hero(
                tag: balanceCardHeroTag(balance),
                // Flutter rebuilds the child inside its own overlay during the
                // flight, where it has no Material ancestor; supplying one keeps
                // text and ink from asserting mid-animation.
                flightShuttleBuilder: (_, _, _, _, _) => Material(
                  color: Colors.transparent,
                  child: BalanceCard(
                    balance: balance,
                    label: label,
                    showActions: false,
                    animateBalance: false,
                    height: context.scaledHeight(200),
                  ),
                ),
                child: BalanceCard(
                  balance: balance,
                  label: label,
                  showActions: false,
                  animateBalance: false,
                  height: context.scaledHeight(200),
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: Radii.sheetTop,
                  color: colors.sheetBackground,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(Insets.lg),
                  children: staggeredReveal([
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Transfer',
                            icon: Icons.send_rounded,
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AddTransactionScreen.routeName,
                              arguments: userId,
                            ),
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: AppButton(
                            label: 'QRIS',
                            icon: Icons.qr_code_rounded,
                            variant: AppButtonVariant.secondary,
                            onPressed: () =>
                                showQrActions(context, initialAccount: balance),
                          ),
                        ),
                      ],
                    ),
                    const SectionHeader(
                      title: 'Account details',
                      padding: EdgeInsets.only(
                        top: Insets.xl,
                        bottom: Insets.xs,
                      ),
                    ),
                    _DetailRow(
                      label: 'Account name',
                      value: balance.cardName,
                    ),
                    _DetailRow(
                      label: 'Account number',
                      value: balance.cardNumber,
                    ),
                    _DetailRow(label: 'Type', value: label),
                    _DetailRow(label: 'Expires', value: balance.expiryDate),
                    _DetailRow(
                      label: 'Available balance',
                      value: amount.formattedWithSymbol,
                      emphasise: true,
                    ),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
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
              style: emphasise
                  ? textTheme.titleMedium
                  : textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
