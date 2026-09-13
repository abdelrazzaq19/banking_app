import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/export/widget_capture.dart';
import 'package:newtronic_banking/data/model/balance_model.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/qr/qris_payload.dart';
import 'package:newtronic_banking/data/utils/currency_input_formatter.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';
import 'package:newtronic_banking/presentation/screen/qr/widgets/qr_payment_panel.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';
import 'package:share_plus/share_plus.dart';

/// A payment code for one of the user's own accounts.
///
/// Two modes, because both are real: a fixed-amount code for "pay me this",
/// and an open code for "pay me" where the payer types the figure. The amount
/// is optional rather than required so the screen is useful before the user
/// knows what they are owed.
class MyQrScreen extends StatefulWidget {
  const MyQrScreen({
    super.key,
    required this.accounts,
    required this.holderName,
    this.initialAccount,
  });

  static const routeName = '/my-qr';

  final List<Balances> accounts;

  /// Whose name the payer sees. A code that names an account number and
  /// nobody is one a payer has no way to check.
  final String holderName;

  final Balances? initialAccount;

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  final GlobalKey _captureKey = GlobalKey();
  final TextEditingController _amountController = TextEditingController();

  late Balances? _account = widget.initialAccount ??
      (widget.accounts.isEmpty ? null : widget.accounts.first);

  bool _isSharing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Whole rupiah asked for, or null for an open code.
  Money? get _amount {
    final parsed = parseRupiah(_amountController.text);
    return parsed == null || parsed <= 0 ? null : Money(parsed);
  }

  QrisPayload? get _payload {
    final account = _account;
    if (account == null) return null;

    return QrisPayload(
      bankName: ownBankName,
      // The stored number is grouped for display; a code carries digits.
      accountNumber: account.cardNumber.replaceAll(RegExp(r'\D'), ''),
      recipientName: widget.holderName,
      amount: _amount,
    );
  }

  Future<void> _pickAccount() async {
    final picked = await showPickerSheet<Balances>(
      context: context,
      title: 'Receive into',
      items: widget.accounts,
      searchHint: 'Search your accounts',
      matches: (account, query) =>
          account.cardName.toLowerCase().contains(query) ||
          account.cardNumber.replaceAll(' ', '').contains(query),
      itemBuilder: (context, account, query) => ListTile(
        title: HighlightedText(text: account.cardName, query: query),
        subtitle: Text(maskedBankNumber(account.cardNumber)),
      ),
    );

    if (picked != null && mounted) setState(() => _account = picked);
  }

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      final bytes = await WidgetCapture.png(_captureKey);
      if (!mounted) return;

      if (bytes == null) {
        _report('Could not capture the code.', isError: true);
        return;
      }

      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'image/png', name: 'my-qr.png'),
        ],
        fileNameOverrides: ['my-qr.png'],
        subject: 'Pay ${widget.holderName}',
      ));
    } catch (error) {
      debugPrint('QR share failed: $error');
      _report('Sharing is not available here.', isError: true);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _report(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor:
          isError ? Theme.of(context).colorScheme.errorContainer : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;

    return Scaffold(
      backgroundColor: context.scheme.surface,
      appBar: AppBar(title: const Text('My QR')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: staggeredReveal([
            if (payload == null)
              const EmptyState(
                icon: Icons.qr_code_rounded,
                title: 'No account to receive into',
                message: 'A payment code needs an account for the money to '
                    'land in.',
              )
            else
              RepaintBoundary(
                key: _captureKey,
                child: QrPaymentPanel(
                  payload: payload,
                  accountName: _account!.cardName,
                  accountNumber: _account!.cardNumber,
                ),
              ),
            const SizedBox(height: Insets.lg),
            if (widget.accounts.length > 1)
              _PickerRow(
                label: 'Receive into',
                value: _account?.cardName ?? 'Pick an account',
                onTap: _pickAccount,
              ),
            const SizedBox(height: Insets.md),
            AppTextField(
              controller: _amountController,
              hintText: 'Amount (optional)',
              semanticLabel: 'Amount to request',
              keyboardType: TextInputType.number,
              useTabularFigures: true,
              inputFormatters: const [ThousandsSeparatorInputFormatter()],
              helperText: 'Leave empty to let the payer decide',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Insets.lg),
            AppButton(
              label: 'Share code',
              icon: Icons.ios_share_rounded,
              isLoading: _isSharing,
              semanticLabel: 'Share this payment code as an image',
              onPressed: payload == null ? null : _share,
            ),
          ]),
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.mutedFill,
      borderRadius: Radii.mdAll,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: Radii.mdAll),
        title: Text(label, style: context.texts.bodySmall),
        subtitle: Text(value, style: context.texts.titleSmall),
        trailing: const Icon(Icons.expand_more_rounded),
        onTap: onTap,
      ),
    );
  }
}
