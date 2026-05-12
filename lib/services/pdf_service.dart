import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/invoice.dart';

class _CachedImage {
  final pw.MemoryImage image;
  final DateTime lastModified;
  _CachedImage(this.image, this.lastModified);
}

class PdfService {
  static const _navyBlue = PdfColor.fromInt(0xFF1E3A8A);
  static const _lightBlue = PdfColor.fromInt(0xFF3B82F6);
  static const _red = PdfColor.fromInt(0xFFEF4444);
  static const _darkText = PdfColor.fromInt(0xFF1E293B);
  static const _greyText = PdfColor.fromInt(0xFF64748B);
  static const _lightGrey = PdfColor.fromInt(0xFFF1F5F9);

  // Caches
  static pw.Font? _fontRegular;
  static pw.Font? _fontBold;
  static pw.Font? _fontSymbols;
  static final Map<String, _CachedImage> _imageCache = {};

  static Future<pw.MemoryImage?> _getImage(String? path) async {
    if (path == null || path.isEmpty) return null;
    
    // Check cache
    if (_imageCache.containsKey(path)) {
      return _imageCache[path]!.image;
    }

    try {
      if (path.startsWith('http')) {
        final response = await http.get(Uri.parse(path));
        if (response.statusCode == 200) {
          final image = pw.MemoryImage(response.bodyBytes);
          _imageCache[path] = _CachedImage(image, DateTime.now());
          return image;
        }
        return null;
      } else {
        final file = File(path);
        if (!file.existsSync()) return null;
        final modified = file.lastModifiedSync();
        final image = pw.MemoryImage(file.readAsBytesSync());
        _imageCache[path] = _CachedImage(image, modified);
        return image;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<Uint8List> generateInvoicePdf({
    required Invoice invoice,
    required BusinessInfo businessInfo,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    // Load Unicode-compatible fonts for currency symbols like ₵ (Cached locally)
    _fontRegular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    _fontBold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    _fontSymbols ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansSymbols2-Regular.ttf'));

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: _fontRegular,
        bold: _fontBold,
        fontFallback: [_fontSymbols!],
      ),
    );

    // Load Images from cache or disk
    final logoImage = await _getImage(businessInfo.logoPath);
    final watermarkImage = await _getImage(invoice.watermarkPath);
    final signatureImage = await _getImage(businessInfo.signaturePath);

    final currency = businessInfo.currency;
    final dateStr = 'DATE: ${DateFormat('dd MMM yyyy').format(invoice.date).toUpperCase()}';
    final docTitle = invoice.isEstimate ? 'ESTIMATE' : (invoice.type == InvoiceType.invoice ? 'INVOICE' : 'RECEIPT');

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          if (invoice.isPos || pageFormat == PdfPageFormat.roll80) {
            return _buildPosLayout(invoice, businessInfo, currency, dateStr, logoImage, docTitle);
          }
          
          switch (businessInfo.pdfTemplate) {
            case PdfTemplate.classic:
              return _buildClassicLayout(invoice, businessInfo, currency, dateStr, logoImage, docTitle, watermarkImage, signatureImage);
            case PdfTemplate.minimalist:
              return _buildMinimalistLayout(invoice, businessInfo, currency, dateStr, logoImage, docTitle, watermarkImage, signatureImage);
            case PdfTemplate.sidebar:
              return _buildSidebarLayout(invoice, businessInfo, currency, dateStr, logoImage, docTitle, watermarkImage, signatureImage);
          }
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSidebarLayout(
    Invoice invoice,
    BusinessInfo businessInfo,
    String currency,
    String dateStr,
    pw.MemoryImage? logoImage,
    String docTitle,
    pw.MemoryImage? watermarkImage,
    pw.MemoryImage? signatureImage,
  ) {
    final dueStr = invoice.dueDate != null ? 'DUE: ${DateFormat('dd MMM yyyy').format(invoice.dueDate!).toUpperCase()}' : '';
    
    return pw.Stack(
      children: [
        // Centered custom watermark
        if (watermarkImage != null)
          pw.Positioned.fill(
            child: pw.Center(
              child: pw.Opacity(
                opacity: invoice.watermarkOpacity,
                child: pw.Transform.rotate(
                  angle: invoice.watermarkRotation * 3.14159 / 180,
                  child: pw.Image(watermarkImage, width: 300),
                ),
              ),
            ),
          ),

        // Two-column layout
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ========== LEFT SIDEBAR ==========
            pw.Container(
              width: 155,
              decoration: const pw.BoxDecoration(color: _navyBlue),
              child: pw.Stack(
                children: [
                  // Tiled logo watermark in sidebar
                  if (logoImage != null)
                    pw.Positioned.fill(
                      child: pw.Opacity(
                        opacity: 0.08,
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                          children: List.generate(
                            7,
                            (_) => pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                              children: List.generate(
                                3,
                                (_) => pw.Image(logoImage, width: 38),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Sidebar content
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(18),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Logo box
                        if (logoImage != null)
                          pw.Container(
                            width: 72,
                            height: 72,
                            padding: const pw.EdgeInsets.all(6),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Image(logoImage),
                          )
                        else
                          pw.Container(
                            width: 72,
                            height: 72,
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white.shade(0.15),
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                businessInfo.name.isNotEmpty ? businessInfo.name[0] : 'B',
                                style: pw.TextStyle(color: PdfColors.white, fontSize: 28, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ),

                        pw.SizedBox(height: 14),
                        pw.Text(
                          businessInfo.name.toUpperCase(),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 16),

                        // Contact info
                        _sidebarLabel('CONTACT'),
                        pw.SizedBox(height: 3),
                        _sidebarValue(businessInfo.phone),
                        _sidebarValue(businessInfo.email),

                        pw.SizedBox(height: 12),
                        _sidebarLabel('ADDRESS'),
                        pw.SizedBox(height: 3),
                        _sidebarValue(businessInfo.address),

                        pw.Spacer(),

                        // Terms & Conditions at bottom of sidebar
                        if (businessInfo.terms != null && businessInfo.terms!.isNotEmpty) ...[
                          pw.Text(
                            businessInfo.pdfTermsLabel ?? 'TERMS & CONDITIONS',
                            style: pw.TextStyle(
                              color: PdfColor.fromInt(0xFFFFBF00),
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            businessInfo.terms!,
                            style: const pw.TextStyle(color: PdfColors.white, fontSize: 6.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ========== RIGHT MAIN CONTENT ==========
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // --- Header ---
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              docTitle,
                              style: pw.TextStyle(
                                fontSize: 32,
                                fontWeight: pw.FontWeight.bold,
                                color: _navyBlue,
                              ),
                            ),
                            pw.Text(
                              '#${invoice.id}',
                              style: const pw.TextStyle(fontSize: 10, color: _greyText),
                            ),
                            if (invoice.cashierName != null) 
                              pw.Text('Cashier: ${invoice.cashierName}', style: const pw.TextStyle(fontSize: 8, color: _greyText)),
                            if (invoice.stationName != null) 
                              pw.Text('Station: ${invoice.stationName}', style: const pw.TextStyle(fontSize: 8, color: _greyText)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(dateStr, style: const pw.TextStyle(fontSize: 8, color: _darkText)),
                            if (dueStr.isNotEmpty)
                              pw.Text(dueStr, style: const pw.TextStyle(fontSize: 8, color: _darkText)),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 20),

                    // --- BILL TO ---
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: _lightGrey,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BILL TO',
                            style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                              color: _lightBlue,
                              letterSpacing: 0.8,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            invoice.clientInfo.name.isNotEmpty ? invoice.clientInfo.name : '—',
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _darkText),
                          ),
                          if (invoice.clientInfo.address.isNotEmpty)
                            pw.Text(invoice.clientInfo.address, style: const pw.TextStyle(fontSize: 9, color: _greyText)),
                          if (invoice.clientInfo.contact.isNotEmpty)
                            pw.Text(invoice.clientInfo.contact, style: const pw.TextStyle(fontSize: 9, color: _greyText)),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 16),

                    // --- Items Table ---
                    pw.Table(
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3.5),
                        1: const pw.FlexColumnWidth(1),
                        2: const pw.FlexColumnWidth(1.5),
                        3: const pw.FlexColumnWidth(1.5),
                      },
                      children: [
                        // Table header
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: _navyBlue),
                          children: [
                            _tableHeader('Description'),
                            _tableHeader('Qty'),
                            _tableHeader('Unit Price'),
                            _tableHeader('Total'),
                          ],
                        ),
                        // Item rows
                        ...invoice.items.asMap().entries.map((entry) {
                          final i = entry.key;
                          final item = entry.value;
                          final isEven = i % 2 == 1;
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: isEven ? _lightGrey : PdfColors.white,
                            ),
                            children: [
                              _tableCell(item.name),
                              _tableCell(item.quantity.toString()),
                              _tableCell('$currency${item.sellingPrice.toStringAsFixed(2)}'),
                              _tableCell('$currency${item.total.toStringAsFixed(2)}'),
                            ],
                          );
                        }),
                      ],
                    ),

                    pw.SizedBox(height: 14),

                    // --- Totals ---
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            _totalRow('Subtotal:', '$currency${invoice.subtotal.toStringAsFixed(2)}'),
                            if (invoice.discountValue > 0)
                              _totalRow(
                                'Discount:',
                                '$currency${invoice.discountAmount.toStringAsFixed(2)}',
                              ),
                            if (invoice.taxValue > 0)
                              _totalRow(
                                'Tax (${invoice.taxValue.toStringAsFixed(0)}%):',
                                '+ $currency${invoice.taxAmount.toStringAsFixed(2)}',
                              ),
                            pw.SizedBox(height: 4),
                            // Grand Total row (blue bold)
                            pw.Row(
                              children: [
                                pw.SizedBox(
                                  width: 110,
                                  child: pw.Text(
                                    'GRAND TOTAL',
                                    style: pw.TextStyle(
                                      fontSize: 11,
                                      fontWeight: pw.FontWeight.bold,
                                      color: _lightBlue,
                                    ),
                                  ),
                                ),
                                pw.SizedBox(
                                  width: 80,
                                  child: pw.Text(
                                    '$currency${invoice.total.toStringAsFixed(2)}',
                                    textAlign: pw.TextAlign.right,
                                    style: pw.TextStyle(
                                      fontSize: 11,
                                      fontWeight: pw.FontWeight.bold,
                                      color: _lightBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Balance row (red)
                            pw.Row(
                              children: [
                                pw.SizedBox(
                                  width: 110,
                                  child: pw.Text(
                                    'BALANCE',
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: _red,
                                    ),
                                  ),
                                ),
                                pw.SizedBox(
                                  width: 80,
                                  child: pw.Text(
                                    '$currency${(invoice.total - invoice.amountPaid).toStringAsFixed(2)}',
                                    textAlign: pw.TextAlign.right,
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: _red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 6),
                            // Payment method
                            pw.Row(
                              children: [
                                pw.SizedBox(
                                  width: 110,
                                  child: pw.Text(
                                    'PAYMENT METHOD',
                                    style: const pw.TextStyle(fontSize: 8, color: _greyText),
                                  ),
                                ),
                                pw.SizedBox(
                                  width: 80,
                                  child: pw.Text(
                                    invoice.paymentMethod.name.toUpperCase(),
                                    textAlign: pw.TextAlign.right,
                                    style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold,
                                      color: _lightBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    pw.Spacer(),

                    // --- Footer: Signature + QR ---
                    pw.Divider(color: _lightGrey, thickness: 0.8),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        // Signature area
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (signatureImage != null)
                              pw.Image(signatureImage, width: 90, height: 36)
                            else
                              pw.SizedBox(height: 36),
                            pw.Container(width: 120, height: 0.5, color: _darkText),
                            pw.SizedBox(height: 2),
                            pw.Text(businessInfo.pdfSignatureLabel ?? 'Authorized Signature', style: const pw.TextStyle(fontSize: 7, color: _greyText)),
                          ],
                        ),

                        // QR Code
                        pw.Container(
                          width: 68,
                          height: 68,
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: _generateQrData(invoice),
                            drawText: false,
                          ),
                        ),

                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildClassicLayout(
    Invoice invoice,
    BusinessInfo businessInfo,
    String currency,
    String dateStr,
    pw.MemoryImage? logoImage,
    String docTitle,
    pw.MemoryImage? watermarkImage,
    pw.MemoryImage? signatureImage,
  ) {
    final dueStr = invoice.dueDate != null ? 'DUE: ${DateFormat('dd MMM yyyy').format(invoice.dueDate!).toUpperCase()}' : '';

    return pw.Stack(
      children: [
        // Watermark
        if (watermarkImage != null)
          pw.Positioned.fill(
            child: pw.Center(
              child: pw.Opacity(
                opacity: invoice.watermarkOpacity,
                child: pw.Transform.rotate(
                  angle: invoice.watermarkRotation * 3.14159 / 180,
                  child: pw.Image(watermarkImage, width: 350),
                ),
              ),
            ),
          ),

        pw.Padding(
          padding: const pw.EdgeInsets.all(40),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- Header: Business Info & Logo ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        businessInfo.name.toUpperCase(),
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _navyBlue),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(businessInfo.address, style: pw.TextStyle(fontSize: 9, color: _greyText)),
                      pw.Text('Tel: ${businessInfo.phone}', style: pw.TextStyle(fontSize: 9, color: _greyText)),
                      pw.Text(businessInfo.email, style: pw.TextStyle(fontSize: 9, color: _greyText)),
                    ],
                  ),
                  if (logoImage != null)
                    pw.Container(
                      width: 70,
                      height: 70,
                      child: pw.Image(logoImage),
                    ),
                ],
              ),

              pw.SizedBox(height: 30),
              pw.Divider(color: _lightGrey, thickness: 1),
              pw.SizedBox(height: 20),

              // --- Document Title & Meta ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        docTitle,
                        style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: _navyBlue),
                      ),
                      pw.Text('#${invoice.id}', style: pw.TextStyle(fontSize: 10, color: _greyText)),
                      if (invoice.cashierName != null) 
                        pw.Text('Cashier: ${invoice.cashierName}', style: pw.TextStyle(fontSize: 8, color: _greyText)),
                      if (invoice.stationName != null) 
                        pw.Text('Station: ${invoice.stationName}', style: pw.TextStyle(fontSize: 8, color: _greyText)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(dateStr, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _darkText)),
                      if (dueStr.isNotEmpty)
                        pw.Text(dueStr, style: pw.TextStyle(fontSize: 9, color: _red)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 25),

              // --- BILL TO ---
              pw.Text('BILL TO:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _greyText)),
              pw.SizedBox(height: 4),
              pw.Text(
                invoice.clientInfo.name.isNotEmpty ? invoice.clientInfo.name : '—',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _darkText),
              ),
              if (invoice.clientInfo.address.isNotEmpty)
                pw.Text(invoice.clientInfo.address, style: pw.TextStyle(fontSize: 9, color: _greyText)),
              if (invoice.clientInfo.contact.isNotEmpty)
                pw.Text(invoice.clientInfo.contact, style: pw.TextStyle(fontSize: 9, color: _greyText)),

              pw.SizedBox(height: 25),

              // --- Items Table ---
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _navyBlue, width: 2))),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child: pw.Text('Unit Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    ],
                  ),
                  ...invoice.items.map((item) => pw.TableRow(
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _lightGrey, width: 0.5))),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text(item.name, style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text(item.quantity.toString(), style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text('$currency${item.sellingPrice.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text('$currency${item.total.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
                    ],
                  )),
                ],
              ),

              pw.SizedBox(height: 20),

              // --- Totals ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        _classicTotalRow('Subtotal', '$currency${invoice.subtotal.toStringAsFixed(2)}'),
                        if (invoice.discountAmount > 0)
                          _classicTotalRow('Discount', '$currency${invoice.discountAmount.toStringAsFixed(2)}'),
                        if (invoice.taxAmount > 0)
                          _classicTotalRow('Tax (${invoice.taxValue.toStringAsFixed(0)}%)', '+$currency${invoice.taxAmount.toStringAsFixed(2)}'),
                        pw.Divider(color: _darkText),
                        _classicTotalRow('GRAND TOTAL', '$currency${invoice.total.toStringAsFixed(2)}', isBold: true, color: _navyBlue),
                        _classicTotalRow('Amount Paid', '$currency${invoice.amountPaid.toStringAsFixed(2)}'),
                        _classicTotalRow('Balance Due', '$currency${(invoice.total - invoice.amountPaid).toStringAsFixed(2)}', isBold: true, color: _red),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // --- Footer: Terms, Signature, QR ---
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (businessInfo.terms != null && businessInfo.terms!.isNotEmpty) ...[
                          pw.Text(businessInfo.pdfTermsLabel ?? 'Terms & Conditions', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _navyBlue)),
                          pw.SizedBox(height: 4),
                          pw.Text(businessInfo.terms!, style: pw.TextStyle(fontSize: 7, color: _greyText)),
                        ],
                        pw.SizedBox(height: 20),
                        pw.Container(width: 150, height: 0.5, color: _greyText),
                        pw.SizedBox(height: 4),
                        pw.Text(businessInfo.pdfSignatureLabel ?? 'Authorized Signature', style: pw.TextStyle(fontSize: 8, color: _greyText)),
                        if (signatureImage != null)
                          pw.Padding(padding: const pw.EdgeInsets.only(bottom: 5), child: pw.Image(signatureImage, width: 80, height: 30)),
                      ],
                    ),
                  ),
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 60,
                        height: 60,
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: _generateQrData(invoice),
                          drawText: false,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Scan to Verify', style: pw.TextStyle(fontSize: 6, color: _greyText)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildMinimalistLayout(
    Invoice invoice,
    BusinessInfo businessInfo,
    String currency,
    String dateStr,
    pw.MemoryImage? logoImage,
    String docTitle,
    pw.MemoryImage? watermarkImage,
    pw.MemoryImage? signatureImage,
  ) {
    return pw.Stack(
      children: [
        if (watermarkImage != null)
          pw.Positioned.fill(
            child: pw.Center(
              child: pw.Opacity(
                opacity: invoice.watermarkOpacity,
                child: pw.Transform.rotate(
                  angle: invoice.watermarkRotation * 3.14159 / 180,
                  child: pw.Image(watermarkImage, width: 350),
                ),
              ),
            ),
          ),

        pw.Padding(
          padding: const pw.EdgeInsets.all(50),
          child: pw.Column(
            children: [
              // --- Centered Header ---
              pw.Center(
                child: pw.Column(
                  children: [
                    if (logoImage != null)
                      pw.Container(width: 60, height: 60, child: pw.Image(logoImage)),
                    pw.SizedBox(height: 10),
                    pw.Text(businessInfo.name, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _navyBlue)),
                    pw.Text(businessInfo.address, style: pw.TextStyle(fontSize: 8, color: _greyText)),
                    pw.Text('${businessInfo.phone} | ${businessInfo.email}', style: pw.TextStyle(fontSize: 8, color: _greyText)),
                  ],
                ),
              ),

              pw.SizedBox(height: 40),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CLIENT', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _greyText, letterSpacing: 1.5)),
                      pw.SizedBox(height: 5),
                      pw.Text(invoice.clientInfo.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Text(invoice.clientInfo.address, style: pw.TextStyle(fontSize: 9, color: _greyText)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(docTitle, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _navyBlue)),
                      pw.Text('#${invoice.id}', style: pw.TextStyle(fontSize: 10, color: _greyText)),
                      if (invoice.cashierName != null) 
                        pw.Text('Cashier: ${invoice.cashierName}', style: pw.TextStyle(fontSize: 8, color: _greyText)),
                      if (invoice.stationName != null) 
                        pw.Text('Station: ${invoice.stationName}', style: pw.TextStyle(fontSize: 8, color: _greyText)),
                      pw.SizedBox(height: 5),
                      pw.Text(dateStr, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // --- Simple Table ---
              pw.Table(
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _navyBlue, width: 1))),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    ],
                  ),
                  ...invoice.items.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item.name, style: pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item.quantity.toString(), style: pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$currency${item.sellingPrice.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$currency${item.total.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9))),
                    ],
                  )),
                ],
              ),

              pw.SizedBox(height: 20),

              // --- Totals Row ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _minimalTotalRow('Subtotal', '$currency${invoice.subtotal.toStringAsFixed(2)}'),
                      if (invoice.discountAmount > 0)
                        _minimalTotalRow('Discount', '$currency${invoice.discountAmount.toStringAsFixed(2)}'),
                      _minimalTotalRow('Total', '$currency${invoice.total.toStringAsFixed(2)}', isBold: true),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // --- Signature & Footer ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (signatureImage != null)
                        pw.Image(signatureImage, width: 70, height: 25),
                      pw.Container(width: 100, height: 0.5, color: _greyText),
                      pw.SizedBox(height: 3),
                      pw.Text(businessInfo.pdfSignatureLabel ?? 'Signature', style: pw.TextStyle(fontSize: 7, color: _greyText)),
                    ],
                  ),
                  pw.Text('Generated by Docara', style: pw.TextStyle(fontSize: 6, color: _lightGrey)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _minimalTotalRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _greyText)),
          pw.SizedBox(width: 20),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static pw.Widget _classicTotalRow(String label, String value, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? _greyText)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? _darkText)),
        ],
      ),
    );
  }

  static pw.Widget _sidebarLabel(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        color: PdfColor.fromInt(0xFFFFBF00),
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  static pw.Widget _sidebarValue(String text) {
    return pw.Text(
      text,
      style: const pw.TextStyle(color: PdfColors.white, fontSize: 7.5),
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9, color: _darkText),
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _greyText)),
          ),
          pw.SizedBox(
            width: 80,
            child: pw.Text(value, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9, color: _darkText)),
          ),
        ],
      ),
    );
  }

  static String _generateQrData(Invoice invoice) {
    return 'Docara Invoice & Receipt\nID: ${invoice.id}\nTotal: ${invoice.total.toStringAsFixed(2)}\nItems: ${invoice.items.length}\nPayment: ${invoice.paymentMethod.name}';
  }

  static pw.Widget _buildPosLayout(
    Invoice invoice, 
    BusinessInfo businessInfo, 
    String currency, 
    String dateStr, 
    pw.MemoryImage? logoImage, 
    String docTitle
  ) {
    final timeStr = DateFormat('hh:mm a').format(invoice.date);
    final rawDateStr = DateFormat('dd MMM yyyy').format(invoice.date);

    return pw.Padding(
      padding: const pw.EdgeInsets.all(10), // Small margin for 80mm roll
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logoImage != null) ...[
            pw.Image(logoImage, width: 40, height: 40),
            pw.SizedBox(height: 5),
          ],
          pw.Text(
            businessInfo.name.toUpperCase(),
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _darkText),
            textAlign: pw.TextAlign.center,
          ),
          if ((businessInfo.posSubtitle ?? businessInfo.terms) != null && (businessInfo.posSubtitle ?? businessInfo.terms)!.isNotEmpty)
            pw.Text(
              businessInfo.posSubtitle ?? businessInfo.terms!,
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: _darkText),
              textAlign: pw.TextAlign.center,
            ),
          pw.SizedBox(height: 5),
          if (businessInfo.address.isNotEmpty)
            pw.Text(businessInfo.address, style: const pw.TextStyle(fontSize: 10, color: _darkText), textAlign: pw.TextAlign.center),
          if (businessInfo.phone.isNotEmpty)
            pw.Text('Tel: ${businessInfo.phone}', style: const pw.TextStyle(fontSize: 10, color: _darkText), textAlign: pw.TextAlign.center),
          
          pw.SizedBox(height: 8),
          pw.Divider(color: _darkText, thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 8),

          // Meta Data block
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Date:', style: const pw.TextStyle(fontSize: 10, color: _darkText)),
              pw.Text(rawDateStr, style: const pw.TextStyle(fontSize: 10, color: _darkText)),
            ]
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Time:', style: const pw.TextStyle(fontSize: 10, color: _darkText)),
              pw.Text(timeStr, style: const pw.TextStyle(fontSize: 10, color: _darkText)),
            ]
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Receipt #:', style: const pw.TextStyle(fontSize: 10, color: _darkText)),
              pw.Text(invoice.id, style: const pw.TextStyle(fontSize: 10, color: _darkText)),
            ]
          ),
          if (invoice.cashierName != null && invoice.cashierName!.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Cashier:', style: const pw.TextStyle(fontSize: 10, color: _darkText)),
                pw.Text(invoice.cashierName!, style: const pw.TextStyle(fontSize: 10, color: _darkText)),
              ]
            ),
          ],
          if (invoice.stationName != null && invoice.stationName!.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Station:', style: const pw.TextStyle(fontSize: 10, color: _darkText)),
                pw.Text(invoice.stationName!, style: const pw.TextStyle(fontSize: 10, color: _darkText)),
              ]
            ),
          ],
          if (invoice.clientInfo.name.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Customer:', style: const pw.TextStyle(fontSize: 10, color: _darkText)),
                pw.Text(invoice.clientInfo.name, style: const pw.TextStyle(fontSize: 10, color: _darkText)),
              ]
            ),
          ],

          pw.SizedBox(height: 8),
          pw.Divider(color: _darkText, thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 8),

          // Items Header
          pw.Row(
            children: [
              pw.Expanded(flex: 4, child: pw.Text('ITEM', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _darkText))),
              pw.Expanded(flex: 1, child: pw.Text('QTY', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _darkText))),
              pw.Expanded(flex: 2, child: pw.Text('PRICE', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _darkText))),
              pw.Expanded(flex: 2, child: pw.Text('TOTAL', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _darkText))),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: _darkText, thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 4),

          // Items
          ...invoice.items.map((item) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(flex: 4, child: pw.Text(item.name, style: const pw.TextStyle(fontSize: 10, color: _darkText))),
                  pw.Expanded(flex: 1, child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10, color: _darkText))),
                  pw.Expanded(flex: 2, child: pw.Text('$currency${item.sellingPrice.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10, color: _darkText))),
                  pw.Expanded(flex: 2, child: pw.Text('$currency${item.total.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10, color: _darkText))),
                ],
              ),
            );
          }),

          pw.SizedBox(height: 8),
          pw.Divider(color: _darkText, thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 8),

          // Subtotals
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('SUBTOTAL', style: const pw.TextStyle(fontSize: 10, color: _darkText)),
            pw.Text('$currency${invoice.subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10, color: _darkText)),
          ]),
          if (invoice.discountAmount > 0) ...[
            pw.SizedBox(height: 2),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('DISCOUNT', style: const pw.TextStyle(fontSize: 10, color: _darkText)),
              pw.Text('$currency${invoice.discountAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10, color: _darkText)),
            ]),
          ],
          if (invoice.taxAmount > 0) ...[
            pw.SizedBox(height: 2),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TAX (${invoice.taxValue.toStringAsFixed(0)}%)', style: const pw.TextStyle(fontSize: 10, color: _darkText)),
              pw.Text('$currency${invoice.taxAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10, color: _darkText)),
            ]),
          ],

          pw.SizedBox(height: 8),
          pw.Divider(color: _darkText, thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 8),

          // Totals
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('TOTAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _darkText)),
            pw.Text('$currency${invoice.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _darkText)),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('PAID', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _darkText)),
            pw.Text('$currency${invoice.amountPaid.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10, color: _darkText)),
          ]),
          pw.SizedBox(height: 2),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('CHANGE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _darkText)),
            pw.Text('$currency${(invoice.amountPaid > invoice.total ? invoice.amountPaid - invoice.total : 0.0).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10, color: _darkText)),
          ]),

          pw.SizedBox(height: 8),
          pw.Divider(color: _darkText, thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 12),

          // Footer message
          if ((businessInfo.posFooterMessage ?? '').isNotEmpty)
            pw.Text(businessInfo.posFooterMessage!, style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: _darkText), textAlign: pw.TextAlign.center)
          else ...[
            pw.Text('Thank you for shopping with us!', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: _darkText), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 2),
            pw.Text('Please come again.', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: _darkText), textAlign: pw.TextAlign.center),
          ],
          
          pw.SizedBox(height: 15),
          
          // QR Code
          pw.Container(
            width: 80,
            height: 80,
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: _generateQrData(invoice),
              drawText: false,
            ),
          ),
          pw.SizedBox(height: 15),

          // Website or email if available
          if ((businessInfo.posEmail ?? businessInfo.email).isNotEmpty) ...[
            pw.Text(businessInfo.posEmail ?? businessInfo.email, style: const pw.TextStyle(fontSize: 9, color: _darkText), textAlign: pw.TextAlign.center),
          ]
        ],
      ),
    );
  }
}
