import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/data/export/receipt_export.dart';
import 'package:newtronic_banking/data/export/widget_capture.dart';
import 'package:newtronic_banking/data/model/money.dart';
import 'package:newtronic_banking/data/model/transaction_model.dart';
import 'package:newtronic_banking/data/model/transfer_receipt.dart';
import 'package:newtronic_banking/presentation/screen/transactions/receipt_detail_screen.dart';
import 'package:newtronic_banking/presentation/screen/transactions/widgets/receipt_card.dart';
import 'package:newtronic_banking/presentation/screen/transactions/widgets/receipt_export_actions.dart';
import 'package:newtronic_banking/presentation/widget/app_widgets.dart';

import 'support/test_harness.dart';

final _receipt = TransferReceipt(
  userId: 7,
  recipientName: 'Siti Rahayu',
  bankName: 'Bank Danamon',
  bankImage: '',
  accountNumber: '123456789012',
  sourceAccountId: '001',
  sourceAccountName: 'BlueSky',
  nominal: const Money(250000),
  transactionType: 'BI-FAST',
  reference: '1696 2200 4022 5002',
  createdAt: DateTime(2026, 9, 11),
  note: 'Rent',
);

Widget _fallbackMarker(BuildContext context) =>
    const SizedBox(key: Key('fallback'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('PDF', () {
    test('produces a real PDF document', () async {
      final bytes = await ReceiptExporter.buildPdf(_receipt);

      expect(bytes, isNotEmpty);
      // Every PDF starts with the %PDF- magic bytes.
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('states every field the receipt shows', () {
      final rows = {
        for (final row in ReceiptExporter.documentRows(_receipt))
          row.label: row.value,
      };

      expect(rows, {
        'Recipient': 'Siti Rahayu',
        'Bank': 'Bank Danamon',
        'Account number': '1234 **** 9012',
        'From': 'BlueSky',
        'Transaction type': 'BI-FAST',
        'Reference': '1696 2200 4022 5002',
        'Date': '11 September 2026',
        'Note': 'Rent',
      });
    });

    test('breaks the money down to a total that includes the fee', () {
      final rows = ReceiptExporter.amountRows(_receipt);

      expect(
        rows.map((row) => (row.label, row.value)).toList(),
        [
          ('Transfer amount', 'Rp 250.000'),
          ('Admin fee', 'Rp 2.500'),
          ('Total debited', 'Rp 252.500'),
        ],
      );
      // Only the total is emphasised, so the figure that left the account is
      // the one that stands out.
      expect(rows.where((row) => row.isTotal).map((row) => row.label), [
        'Total debited',
      ]);
    });

    test('masks the recipient account number', () {
      final values = [
        for (final row in ReceiptExporter.documentRows(_receipt)) row.value,
      ];

      expect(values, contains('1234 **** 9012'));
      expect(values, isNot(contains('123456789012')));
    });

    test('omits the note row when there is no note', () {
      final noNote = TransferReceipt(
        userId: 7,
        recipientName: 'Budi',
        bankName: 'Bank Mandiri',
        bankImage: '',
        accountNumber: '999888777666',
        sourceAccountId: '001',
        sourceAccountName: 'BlueSky',
        nominal: const Money(1000),
        transactionType: 'BI-FAST',
        reference: '1111 2222 3333 4444',
        createdAt: DateTime(2026, 9, 11),
      );

      expect(
        ReceiptExporter.documentRows(noNote).map((row) => row.label),
        isNot(contains('Note')),
      );
    });

    test('compressing makes a smaller file than not', () async {
      final compressed = await ReceiptExporter.buildPdf(_receipt);
      final plain = await ReceiptExporter.buildPdf(_receipt, compress: false);
      expect(compressed.length, lessThan(plain.length));
    });

    test('still produces a document when the font download fails', () async {
      // Tests have no network, so this is the offline path: the font fetch
      // fails and the build falls back to Helvetica instead of throwing.
      final accented = TransferReceipt(
        userId: 7,
        recipientName: 'Zoë Müller-Nyström',
        bankName: 'Bank Danamon',
        bankImage: '',
        accountNumber: '123456789012',
        sourceAccountId: '001',
        sourceAccountName: 'BlueSky',
        nominal: const Money(250000),
        transactionType: 'BI-FAST',
        reference: '5555 6666 7777 8888',
        createdAt: DateTime(2026, 9, 11),
      );

      final bytes = await ReceiptExporter.buildPdf(accented);

      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });

    test('names the file after the reference, so two never collide', () {
      expect(
        ReceiptExporter.fileStem(_receipt),
        'receipt-1696220040225002',
      );

      final other = TransferReceipt(
        userId: 7,
        recipientName: 'Budi',
        bankName: 'Bank Mandiri',
        bankImage: '',
        accountNumber: '999888777666',
        sourceAccountId: '001',
        sourceAccountName: 'BlueSky',
        nominal: const Money(1000),
        transactionType: 'BI-FAST',
        reference: '1111 2222 3333 4444',
        createdAt: DateTime(2026, 9, 11),
      );
      expect(
        ReceiptExporter.fileStem(other),
        isNot(ReceiptExporter.fileStem(_receipt)),
      );
    });
  });

  group('PNG capture', () {
    testWidgets('rasterises the on-screen card', (tester) async {
      final key = GlobalKey();
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 360,
                child: ReceiptCard(receipt: _receipt),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // runAsync, because the engine completes the image future — awaiting it
      // on the test's fake clock never returns.
      final bytes = await tester.runAsync(
        () => WidgetCapture.png(key, pixelRatio: 1),
      );

      expect(bytes, isNotNull);
      expect(bytes, isNotEmpty);
      // PNG magic bytes.
      expect(bytes!.take(4), [0x89, 0x50, 0x4E, 0x47]);
    });

    testWidgets('returns null rather than a blank image when not mounted',
        (tester) async {
      // A key that was never attached to a RepaintBoundary: capturing would
      // otherwise silently produce an empty picture.
      final orphan = GlobalKey();
      expect(await WidgetCapture.png(orphan), isNull);
    });
  });

  group('remote image', () {
    testWidgets('an empty url never reaches the network', (tester) async {
      // The fetch path drags in the cache manager, which needs path_provider.
      // Skipping it for '' is what keeps a logo-less bank cheap — and what
      // lets the capture test below run at all.
      await tester.pumpWidget(const MaterialApp(
        home: RemoteImage(
          url: '',
          size: 44,
          fallback: _fallbackMarker,
        ),
      ));

      expect(find.byKey(const Key('fallback')), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });

    testWidgets('a payee without a picture shows their initial',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: InitialFallback(name: 'siti rahayu', size: 40),
      ));

      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('a nameless payee shows a question mark', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: InitialFallback(name: '   ', size: 40),
      ));

      expect(find.text('?'), findsOneWidget);
    });
  });

  group('export actions', () {
    testWidgets('both actions are offered with accessible labels',
        (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();
      final key = GlobalKey();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: Scaffold(
          body: Column(
            children: [
              RepaintBoundary(key: key, child: ReceiptCard(receipt: _receipt)),
              ReceiptExportActions(receipt: _receipt, captureKey: key),
            ],
          ),
        ),
      ));
      await tester.pump();

      expect(find.widgetWithText(AppButton, 'PDF'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Image'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Share this receipt as a PDF'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Share this receipt as an image'),
        findsOneWidget,
      );
    });
  });

  group('re-opening from history', () {
    test('a stored transfer rebuilds into a receipt', () {
      final stored = Transactions.fromReceipt(_receipt);
      final rebuilt = stored.toReceipt(7);

      expect(rebuilt, isNotNull);
      expect(rebuilt!.recipientName, 'Siti Rahayu');
      expect(rebuilt.reference, '1696 2200 4022 5002');
      expect(rebuilt.total, const Money(252500));
      expect(rebuilt.note, 'Rent');
    });

    test('a seeded entry has nothing to re-export', () {
      final seeded = Transactions(
        id: '1',
        name: 'Netflix',
        date: DateTime(2026, 9, 1),
        amount: const Money(181286),
        image: '',
      );
      expect(seeded.toReceipt(7), isNull);
    });

    testWidgets('the detail screen shows the receipt with export actions',
        (tester) async {
      useMobileSurface(tester);
      final backend = await createTestBackend();

      await tester.pumpWidget(wrapWithBackend(
        backend,
        child: ReceiptDetailScreen(receipt: _receipt),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ReceiptCard), findsOneWidget);
      expect(find.byType(ReceiptExportActions), findsOneWidget);
      expect(find.text('Rp 250.000'), findsWidgets);
      // Opened from history, so the detail starts expanded.
      expect(find.text('Total debited'), findsOneWidget);
    });
  });
}
