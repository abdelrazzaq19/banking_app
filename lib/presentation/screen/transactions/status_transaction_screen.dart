import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';
import 'package:newtronic_banking/presentation/screen/main/home_screen.dart';
import 'package:newtronic_banking/presentation/widget/components.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/styles/typography.dart';

class StatusTransactionScreen extends StatelessWidget {
  const StatusTransactionScreen({super.key, required this.receipt});
  static const routeName = '/status-transaction';

  final TransferReceipt receipt;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.colors.headerBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: SvgPicture.asset(
                    'lib/assets/images/success.svg',
                    height: 160,
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: _buildReceiptCard(context),
                  ),
                ),
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Container _buildReceiptCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: Radii.mdAll,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          customText(
            textValue: 'Transaction Nominal',
            textStyle: headline4.copyWith(color: context.colors.subtleText),
          ),
          customSpaceVertical(4),
          customText(
            textValue: formatRupiahWithSymbol(receipt.nominal),
            textStyle: numeric(headline3).copyWith(
              color: context.scheme.onSurface,
            ),
          ),
          customSpaceVertical(16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(80),
                child: CachedNetworkImage(
                  imageUrl: receipt.bankImage,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Image.asset(
                    'lib/assets/images/profile.jpg',
                    fit: BoxFit.cover,
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
              customSpaceHorizontal(8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    customText(
                      textValue: receipt.recipientName,
                      textStyle: subHeadline4.copyWith(
                        color: context.scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    customText(
                      textValue: '${receipt.bankName} - '
                          '${maskedBankNumber(receipt.accountNumber)}',
                      textStyle: bodyText2.copyWith(
                        color: context.colors.subtleText,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          _divider(),
          _detailRow(context, 'Transaction Type', receipt.transactionType),
          _divider(),
          _detailRow(context, 'Ref Number', receipt.reference),
          _divider(),
          _detailRow(context, 'Date', formattedTransactionDate(receipt.createdAt)),
          if (receipt.note != null) ...[
            _divider(),
            _detailRow(context, 'Note', receipt.note!),
          ],
          customSpaceVertical(10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: customText(
              textValue: 'Detail',
              textStyle: subHeadline5.copyWith(color: context.scheme.onSurface),
            ),
            children: [
              _detailRow(context, 'Source Account', receipt.sourceAccountName),
              _divider(),
              _detailRow(context, 'Transaction Nominal',
                  formatRupiahWithSymbol(receipt.nominal)),
              _divider(),
              _detailRow(context, 'Admin', formatRupiahWithSymbol(receipt.adminFee)),
              _divider(),
              _detailRow(
                context,
                'Total',
                formatRupiahWithSymbol(receipt.total),
                emphasise: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: Insets.xs),
        child: Divider(height: 1),
      );

  Row _detailRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasise = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        customText(
          textValue: label,
          textStyle: (emphasise ? subHeadline5 : bodyText2).copyWith(
            color: context.colors.subtleText,
          ),
        ),
        customSpaceHorizontal(16),
        Flexible(
          child: customText(
            textValue: value,
            textStyle: numeric(subHeadline5).copyWith(
              color: context.scheme.onSurface,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Column _buildActions(BuildContext context) {
    return Column(
      children: [
        customButton(
          buttonOnTap: () => showSuccessDialog(
            context,
            message: 'Success Saving Transaction',
            onAction: () => _goHome(context),
          ),
          buttonText: 'Save as Favorite',
          textColor: context.scheme.primary,
          buttonFirstGradientColor: context.scheme.surface,
          buttonSecondGradientColor: context.scheme.surface,
        ),
        customSpaceVertical(8),
        customButton(
          buttonOnTap: () => _goHome(context),
          buttonText: 'Done',
          textColor: context.scheme.onPrimary,
          buttonFirstGradientColor: context.scheme.primary,
          buttonSecondGradientColor: context.colors.accent,
        ),
      ],
    );
  }

  /// Returns to the account that actually made the transfer. This used to push
  /// `HomeScreen` with a hardcoded `arguments: 5`, silently switching users.
  void _goHome(BuildContext context) => Navigator.pushNamedAndRemoveUntil(
        context,
        HomeScreen.routeName,
        (route) => false,
        arguments: receipt.userId,
      );
}
