import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/presentation/screen/main/home_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/widgets/receipt_card.dart';
import 'package:newtronic_banking/presentation/screen/transactions/widgets/receipt_export_actions.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';
import 'package:newtronic_banking/state/favourite_store.dart';
import 'package:provider/provider.dart';

/// Where a completed transfer lands.
///
/// Deliberately a dead end for the back gesture: the transfer has happened, so
/// returning to the form would invite a duplicate. Both actions lead home.
class StatusTransactionScreen extends StatefulWidget {
  const StatusTransactionScreen({super.key, required this.receipt});
  static const routeName = '/status-transaction';

  final TransferReceipt receipt;

  @override
  State<StatusTransactionScreen> createState() =>
      _StatusTransactionScreenState();
}

class _StatusTransactionScreenState extends State<StatusTransactionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _successController = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );

  /// Wraps the card so the image export captures exactly what is on screen.
  final GlobalKey _captureKey = GlobalKey();


  @override
  void initState() {
    super.initState();
    _successController.forward();
  }

  @override
  void dispose() {
    _successController.dispose();
    super.dispose();
  }

  /// Returns to the account that actually made the transfer. This used to push
  /// `HomeScreen` with a hardcoded `arguments: 5`, silently switching users.
  void _goHome() => Navigator.pushNamedAndRemoveUntil(
        context,
        HomeScreen.routeName,
        (route) => false,
        arguments: widget.receipt.userId,
      );

  Future<void> _saveAsFavourite() async {
    await context.read<FavouriteStore>().saveReceipt(widget.receipt);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.receipt.recipientName} saved to favourites'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.headerBackground,
        body: SafeArea(
          child: Column(
            children: [
              _buildSuccessMark(context),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: Radii.sheetTop,
                    color: colors.sheetBackground,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(Insets.lg),
                          children: staggeredReveal([
                            RepaintBoundary(
                              key: _captureKey,
                              child: ReceiptCard(receipt: widget.receipt),
                            ),
                            const SizedBox(height: Insets.md),
                            ReceiptExportActions(
                              receipt: widget.receipt,
                              captureKey: _captureKey,
                            ),
                          ]),
                        ),
                      ),
                      _buildActions(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessMark(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: SizedBox(
        height: 132,
        child: Lottie.asset(
          'lib/assets/lotties/lottieSuccess.json',
          controller: _successController,
          fit: BoxFit.contain,
          // Play once and hold on the final frame: a success mark that loops
          // keeps drawing the eye back after the news has landed.
          onLoaded: (composition) {
            _successController
              ..duration = composition.duration
              ..forward();
          },
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    // Read from the store rather than a local flag, so the button reflects
    // what is actually saved — including a recipient saved on an earlier
    // transfer.
    final isSaved = context.watch<FavouriteStore>().containsReceipt(
          widget.receipt,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.xs,
        Insets.lg,
        Insets.md,
      ),
      child: Column(
        children: [
          AppButton(
            label: isSaved ? 'Saved to favourites' : 'Save as Favorite',
            icon: isSaved ? Icons.star_rounded : Icons.star_border_rounded,
            variant: AppButtonVariant.secondary,
            // Disabled once saved, so the state of the action is visible
            // rather than the same button quietly doing nothing twice.
            onPressed: isSaved ? null : _saveAsFavourite,
          ),
          const SizedBox(height: Insets.xs),
          AppButton(
            label: 'Done',
            onPressed: _goHome,
          ),
        ],
      ),
    );
  }
}
