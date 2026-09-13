import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/model/balance_model.dart';
import 'package:newtronic_banking/presentation/screen/qr/enter_code_screen.dart';
import 'package:newtronic_banking/presentation/screen/qr/my_qr_screen.dart';
import 'package:newtronic_banking/state/account_store.dart';
import 'package:newtronic_banking/state/session_store.dart';
import 'package:provider/provider.dart';

/// The two halves of a payment code: show one, or read one.
///
/// A sheet rather than a screen because it is a fork, not a destination, and
/// rather than two separate buttons because the QRIS control is already one
/// button on a card with no room for a second.
///
/// Reads the accounts and the signed-in user from the stores instead of taking
/// them as arguments: every caller would otherwise have to look up the same
/// two things and could disagree about them.
Future<void> showQrActions(
  BuildContext context, {
  Balances? initialAccount,
}) async {
  final accounts = context.read<AccountStore>().accounts;
  final user = context.read<SessionStore>().currentUser;
  final userId = context.read<SessionStore>().userId;

  if (userId == null) return;

  final choice = await showModalBottomSheet<_QrChoice>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChoiceTile(
            icon: Icons.qr_code_2_rounded,
            title: 'My QR',
            subtitle: 'Show a code for someone to pay you',
            onTap: () => Navigator.pop(context, _QrChoice.show),
          ),
          _ChoiceTile(
            icon: Icons.content_paste_go_rounded,
            title: 'Enter a code',
            subtitle: 'Paste a payment code to fill in a transfer',
            onTap: () => Navigator.pop(context, _QrChoice.read),
          ),
          const SizedBox(height: Insets.sm),
        ],
      ),
    ),
  );

  if (choice == null || !context.mounted) return;

  switch (choice) {
    case _QrChoice.show:
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MyQrScreen(
            accounts: accounts,
            // Falls back to the account's own name rather than showing a code
            // labelled with nobody, which a payer could not check.
            holderName: user?.name ??
                initialAccount?.cardName ??
                (accounts.isEmpty ? 'This account' : accounts.first.cardName),
            initialAccount: initialAccount,
          ),
        ),
      );
    case _QrChoice.read:
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EnterCodeScreen(userId: userId)),
      );
  }
}

enum _QrChoice { show, read }

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.mutedFill,
          borderRadius: Radii.pillAll,
        ),
        child: Icon(icon),
      ),
      title: Text(title, style: context.texts.titleSmall),
      subtitle: Text(subtitle, style: context.texts.bodySmall),
      onTap: onTap,
    );
  }
}
