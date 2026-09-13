import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/data/export/receipt_export.dart';
import 'package:newtronic_banking/data/export/widget_capture.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Share and save actions for a receipt.
///
/// [captureKey] must wrap the on-screen receipt in a `RepaintBoundary`; the
/// image export rasterises exactly what is shown rather than re-laying it out,
/// so the picture cannot drift from the card.
class ReceiptExportActions extends StatefulWidget {
  const ReceiptExportActions({
    super.key,
    required this.receipt,
    required this.captureKey,
  });

  final TransferReceipt receipt;
  final GlobalKey captureKey;

  @override
  State<ReceiptExportActions> createState() => _ReceiptExportActionsState();
}

class _ReceiptExportActionsState extends State<ReceiptExportActions> {
  bool _isBusyPdf = false;
  bool _isBusyImage = false;

  void _report(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? Theme.of(context).colorScheme.errorContainer : null,
      ),
    );
  }

  Future<void> _sharePdf() async {
    setState(() => _isBusyPdf = true);
    try {
      final bytes = await ReceiptExporter.buildPdf(widget.receipt);
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${ReceiptExporter.fileStem(widget.receipt)}.pdf',
      );
    } catch (error, stackTrace) {
      debugPrint('Receipt PDF export failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _report('Could not create the PDF.', isError: true);
    } finally {
      if (mounted) setState(() => _isBusyPdf = false);
    }
  }

  Future<void> _shareImage() async {
    setState(() => _isBusyImage = true);
    try {
      final bytes = await WidgetCapture.png(widget.captureKey);
      if (!mounted) return;

      if (bytes == null) {
        _report('Could not capture the receipt.', isError: true);
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: '${ReceiptExporter.fileStem(widget.receipt)}.png',
            ),
          ],
          fileNameOverrides: [
            '${ReceiptExporter.fileStem(widget.receipt)}.png',
          ],
          subject: 'Transfer receipt ${widget.receipt.reference}',
        ),
      );
    } catch (error, stackTrace) {
      // Sharing is not available everywhere — a browser without the Web Share
      // API, for instance — so this says so rather than failing silently.
      debugPrint('Receipt image share failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _report('Sharing an image is not available here.', isError: true);
    } finally {
      if (mounted) setState(() => _isBusyImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: 'PDF',
            icon: Icons.picture_as_pdf_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.medium,
            isLoading: _isBusyPdf,
            semanticLabel: 'Share this receipt as a PDF',
            onPressed: _sharePdf,
          ),
        ),
        const SizedBox(width: Insets.xs),
        Expanded(
          child: AppButton(
            label: 'Image',
            icon: Icons.image_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.medium,
            isLoading: _isBusyImage,
            semanticLabel: 'Share this receipt as an image',
            onPressed: _shareImage,
          ),
        ),
      ],
    );
  }
}
