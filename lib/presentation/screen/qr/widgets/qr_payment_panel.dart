import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/qr/qris_payload.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The bank name a code from this app carries.
///
/// The seed bank list is other institutions to pay; an account held here is
/// this one, and the code has to name it for the payer's form to fill in.
const String ownBankName = 'Newtronic Banking';

/// The card that is both shown on screen and captured for sharing.
///
/// Public, and holding its [payload], because that is the only way to check
/// what the rendered code actually says: `QrImageView` keeps its data private,
/// so a test cannot read the string back out of the image.
class QrPaymentPanel extends StatelessWidget {
  const QrPaymentPanel({
    super.key,
    required this.payload,
    required this.accountName,
    required this.accountNumber,
  });

  final QrisPayload payload;
  final String accountName;
  final String accountNumber;

  @override
  Widget build(BuildContext context) {
    final texts = context.texts;

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        // Deliberately not a glass surface: a QR needs a plain, opaque,
        // high-contrast ground or a scanner struggles with it. This is also
        // why the code stays black-on-white in dark mode.
        color: Colors.white,
        borderRadius: Radii.lgAll,
        border: Border.all(color: context.colors.mutedBorder),
      ),
      child: Column(
        children: [
          Text(
            payload.recipientName,
            style: texts.titleMedium?.copyWith(color: Colors.black),
            textAlign: TextAlign.center,
          ),
          Text(
            '$accountName · ${maskedBankNumber(accountNumber)}',
            style: texts.bodySmall?.copyWith(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Insets.md),
          QrImageView(
            data: payload.encode(),
            version: QrVersions.auto,
            size: 240,
            backgroundColor: Colors.white,
            // Medium recovers from about 15% damage, which is the level a
            // printed or screenshotted code realistically needs.
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            semanticsLabel: 'Payment code for ${payload.recipientName}',
          ),
          const SizedBox(height: Insets.md),
          if (payload.amount case final Money amount)
            Text(
              amount.formattedWithSymbol,
              style: texts.headlineSmall?.copyWith(color: Colors.black),
            )
          else
            Text(
              'Any amount',
              style: texts.bodyMedium?.copyWith(color: Colors.black54),
            ),
          Text(
            ownBankName,
            style: texts.labelSmall?.copyWith(color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
