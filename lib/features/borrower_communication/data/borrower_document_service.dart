import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/formatters.dart';
import '../../loans/domain/models/payment.dart';
import '../domain/borrower_communication_context.dart';

enum BorrowerDocumentType { schedule, receipt, statement }

/// Creates privacy-minimized borrower PDFs entirely from local domain data.
class BorrowerDocumentService {
  const BorrowerDocumentService({this.directoryProvider});

  final Future<Directory> Function()? directoryProvider;

  Future<File> generate(
    BorrowerDocumentType type,
    BorrowerCommunicationContext context,
  ) async {
    final loan = context.loan;
    if (loan == null) {
      throw const BorrowerDocumentException('Loan information is unavailable.');
    }
    if (type == BorrowerDocumentType.receipt && context.payment == null) {
      throw const BorrowerDocumentException('No payment receipt is selected.');
    }

    final document = pw.Document(
      title: _title(type),
      author: 'Lending Nelson',
      creator: 'Lending Nelson Android',
    );
    final generatedAt = DateTime.now();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (pageContext) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            pw.Text(
              'Private borrower document',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.Text(
              'Page ${pageContext.pageNumber} of ${pageContext.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
        build: (_) => <pw.Widget>[
          pw.Text(
            'Lending Nelson',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _title(type),
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          _details(<String, String>{
            'Generated': generatedAt.toLocal().toString().split('.').first,
            'Borrower': context.borrower.fullName,
            'Loan reference': loan.requestId,
            'Original principal': _pdfCurrency(loan.originalPrincipal),
            'Remaining balance': _pdfCurrency(loan.outstandingPrincipal),
          }),
          pw.SizedBox(height: 16),
          if (type == BorrowerDocumentType.schedule)
            _scheduleTable(context)
          else if (type == BorrowerDocumentType.receipt)
            _receipt(context.payment!)
          else
            _statement(context),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Text(
            'Privacy notice: This document is intended only for the named '
            'borrower. It contains limited loan information. Please store and '
            'share it securely.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    final directory = directoryProvider == null
        ? await getTemporaryDirectory()
        : await directoryProvider!();
    final safeReference = _safeSegment(loan.requestId);
    final file = File(
      path.join(
        directory.path,
        'lending-nelson_${type.name}_$safeReference.pdf',
      ),
    );
    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }

  pw.Widget _scheduleTable(BorrowerCommunicationContext context) {
    final rows = context.loan!.installments
        .map(
          (item) => <String>[
            item.installmentNumber.toString(),
            formatDateShort(item.dueDate),
            _pdfCurrency(item.expectedPayment),
            _pdfCurrency(item.paidAmount),
            item.status,
          ],
        )
        .toList();
    return pw.TableHelper.fromTextArray(
      headers: const <String>['#', 'Due date', 'Expected', 'Paid', 'Status'],
      data: rows,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.all(5),
    );
  }

  pw.Widget _receipt(LoanPayment payment) => _details(<String, String>{
    'Payment amount': _pdfCurrency(payment.amount),
    'Payment date': formatDateShort(payment.effectiveDate),
    'Reference number': payment.requestId,
    'Applied to interest': _pdfCurrency(payment.allocation.appliedInterest),
    'Applied to principal': _pdfCurrency(payment.allocation.appliedPrincipal),
    'Remaining balance': _pdfCurrency(payment.allocation.principalAfter),
  });

  pw.Widget _statement(BorrowerCommunicationContext context) {
    final reversed = context.payments
        .map((item) => item.reversalOfPaymentId)
        .whereType<String>()
        .toSet();
    final payments = context.payments
        .where(
          (item) => item.entryType == 'Payment' && !reversed.contains(item.id),
        )
        .toList();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          'Payment transactions',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (payments.isEmpty)
          pw.Text('No effective payments are recorded.')
        else
          pw.TableHelper.fromTextArray(
            headers: const <String>['Date', 'Reference', 'Amount', 'Balance'],
            data: payments
                .map(
                  (item) => <String>[
                    formatDateShort(item.effectiveDate),
                    item.requestId,
                    _pdfCurrency(item.amount),
                    _pdfCurrency(item.allocation.principalAfter),
                  ],
                )
                .toList(),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.all(5),
          ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Remaining balance: '
          '${_pdfCurrency(context.loan!.outstandingPrincipal)}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _details(Map<String, String> values) => pw.Table(
    columnWidths: const <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(1),
      1: pw.FlexColumnWidth(2),
    },
    children: values.entries
        .map(
          (entry) => pw.TableRow(
            children: <pw.Widget>[
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Text(
                  entry.key,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Text(entry.value),
              ),
            ],
          ),
        )
        .toList(),
  );

  String _pdfCurrency(String value) =>
      formatCurrency(value).replaceFirst('₱', 'PHP ');
  String _safeSegment(String value) {
    final safe = value.replaceAll(RegExp('[^A-Za-z0-9_-]'), '-');
    return safe.isEmpty ? 'local' : safe.substring(0, safe.length.clamp(0, 32));
  }

  String _title(BorrowerDocumentType type) => switch (type) {
    BorrowerDocumentType.schedule => 'Payment Schedule',
    BorrowerDocumentType.receipt => 'Payment Receipt',
    BorrowerDocumentType.statement => 'Loan Statement',
  };
}

class BorrowerDocumentException implements Exception {
  const BorrowerDocumentException(this.message);
  final String message;
}

final borrowerDocumentServiceProvider = Provider<BorrowerDocumentService>((
  ref,
) {
  return const BorrowerDocumentService();
});
