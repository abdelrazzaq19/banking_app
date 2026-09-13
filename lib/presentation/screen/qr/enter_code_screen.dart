import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/qr/qris_payload.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';
import 'package:newtronic_banking/presentation/screen/transactions/add_transaction_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/transfer_args.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

/// Reads a payment code the user pastes or types in.
///
/// There is no camera here. `mobile_scanner` has no Windows support and
/// Windows is one of this app's two verification targets, so a scanner would
/// be a button that cannot be built on half the platforms it ships to. Paste
/// covers the case that actually happens on a desktop and on the web — a code
/// arriving in a chat message — and it is the fallback a camera would need
/// anyway, for a code that is scratched, badly lit, or on the same screen.
class EnterCodeScreen extends StatefulWidget {
  const EnterCodeScreen({super.key, required this.userId});

  static const routeName = '/enter-code';

  final int userId;

  @override
  State<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  final TextEditingController _controller = TextEditingController();

  /// What the pasted text currently decodes to, or null before anything is
  /// entered. Held in state so the screen shows what it read *before* the
  /// user commits to paying it.
  QrisDecodeResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _decode(String raw) {
    setState(() => _result = raw.trim().isEmpty ? null : QrisPayload.decode(raw));
  }

  Future<void> _pasteFromClipboard() async {
    String text;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      text = data?.text?.trim() ?? '';
    } catch (error) {
      // Reading the clipboard is not always allowed — a browser can refuse it
      // outright — and Flutter's own getData throws rather than returning null
      // when the platform answers with no text at all.
      debugPrint('Clipboard read failed: $error');
      if (mounted) _say('Could not read the clipboard. Paste into the field.');
      return;
    }

    if (!mounted) return;

    if (text.isEmpty) {
      _say('There is nothing on the clipboard.');
      return;
    }

    _controller.text = text;
    _decode(text);
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _continue(QrisPayload payload) {
    Navigator.pushReplacementNamed(
      context,
      AddTransactionScreen.routeName,
      arguments: TransferArgs(
        userId: widget.userId,
        prefill: TransferPrefill.fromQris(payload),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      backgroundColor: context.scheme.surface,
      appBar: AppBar(title: const Text('Enter a payment code')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: staggeredReveal([
            AppTextField(
              controller: _controller,
              hintText: 'Paste the code here',
              semanticLabel: 'Payment code',
              maxLines: 4,
              onChanged: _decode,
            ),
            const SizedBox(height: Insets.sm),
            AppButton(
              label: 'Paste from clipboard',
              icon: Icons.content_paste_rounded,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.medium,
              onPressed: _pasteFromClipboard,
            ),
            const SizedBox(height: Insets.lg),
            // Switched on rather than chained so a new failure case cannot be
            // added to the decoder without a decision about what is shown.
            ?switch (result) {
              null => null,
              QrisRejected(:final message) => _RejectedPanel(message: message),
              QrisDecoded(:final payload) => _DecodedPanel(
                  payload: payload,
                  onContinue: () => _continue(payload),
                ),
            },
          ]),
        ),
      ),
    );
  }
}

class _RejectedPanel extends StatelessWidget {
  const _RejectedPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: Radii.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              message,
              style: context.texts.bodyMedium
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the code says, shown before anything is paid.
class _DecodedPanel extends StatelessWidget {
  const _DecodedPanel({required this.payload, required this.onContinue});

  final QrisPayload payload;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This code asks you to pay', style: context.texts.bodySmall),
              const SizedBox(height: Insets.xxs),
              Text(payload.recipientName, style: context.texts.titleLarge),
              const SizedBox(height: Insets.md),
              _Row(label: 'Bank', value: payload.bankName),
              _Row(
                label: 'Account number',
                value: maskedBankNumber(payload.accountNumber),
              ),
              _Row(
                label: 'Amount',
                value: switch (payload.amount) {
                  final Money amount => amount.formattedWithSymbol,
                  // An open code is not a missing amount; say which it is.
                  null => 'You choose',
                },
              ),
              if (payload.note case final String note)
                _Row(label: 'Note', value: note),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        AppButton(
          label: 'Continue to transfer',
          icon: Icons.arrow_forward_rounded,
          semanticLabel: 'Continue to the transfer form with these details',
          onPressed: onContinue,
        ),
        const SizedBox(height: Insets.xs),
        Text(
          'Nothing is sent yet. The transfer form opens filled in so you can '
          'check it first.',
          style: context.texts.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: context.texts.bodySmall)),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: context.texts.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
