import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/presentation/screen/transactions/widgets/receipt_card.dart';
import 'package:newtronic_banking/presentation/screen/transactions/widgets/receipt_export_actions.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

/// A past transfer, reopened from the history.
///
/// Separate from the success screen: this one is a record you came back to,
/// not news you were just given, so it has a back button, no celebration, and
/// the detail already open.
class ReceiptDetailScreen extends StatelessWidget {
  ReceiptDetailScreen({super.key, required this.receipt});

  final TransferReceipt receipt;

  /// Wraps the card so the image export captures exactly what is on screen.
  final GlobalKey _captureKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: context.scheme.primary,
        ),
        title: Text(
          'Receipt',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Insets.lg),
              children: staggeredReveal([
                RepaintBoundary(
                  key: _captureKey,
                  child: ReceiptCard(
                    receipt: receipt,
                    initiallyExpanded: true,
                  ),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              0,
              Insets.lg,
              Insets.md,
            ),
            child: ReceiptExportActions(
              receipt: receipt,
              captureKey: _captureKey,
            ),
          ),
        ],
      ),
    );
  }
}
