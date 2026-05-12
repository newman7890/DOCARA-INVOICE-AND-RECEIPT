import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/settings_provider.dart';
import '../services/pdf_service.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;

enum PreviewFormat {
  a4('A4 Portrait'),
  a4Landscape('A4 Landscape'),
  a5('A5 Portrait'),
  a5Landscape('A5 Landscape'),
  pos80('80mm POS Receipt');

  final String label;
  const PreviewFormat(this.label);

  PdfPageFormat get format {
    switch (this) {
      case PreviewFormat.a4:
        return PdfPageFormat.a4;
      case PreviewFormat.a4Landscape:
        return PdfPageFormat.a4.landscape;
      case PreviewFormat.a5:
        return PdfPageFormat.a5;
      case PreviewFormat.a5Landscape:
        return PdfPageFormat.a5.landscape;
      case PreviewFormat.pos80:
        return PdfPageFormat.roll80;
    }
  }
}

class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({super.key});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  PreviewFormat _selectedFormat = PreviewFormat.a4;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final invoice = context.read<InvoiceProvider>().currentInvoice;
      if (invoice != null && invoice.isPos) {
        _selectedFormat = PreviewFormat.pos80;
      }
      _initialized = true;
    }
  }

  Future<void> _showToast(BuildContext context, String message, {bool isError = false}) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade800,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static Uint8List? _convertPngToJpg(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    return Uint8List.fromList(img.encodeJpg(image, quality: 90));
  }

  @override
  Widget build(BuildContext context) {
    final invoice = context.read<InvoiceProvider>().currentInvoice;
    final businessInfo = context.read<SettingsProvider>().businessInfo;

    if (invoice == null || businessInfo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('PDF Preview')),
        body: const Center(child: Text('Error loading invoice data')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8ECF0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A8A)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'PDF Preview',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          // Finish and Go Home
          IconButton(
            tooltip: 'Go Home',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.home_outlined, color: Color(0xFF1E3A8A), size: 18),
            ),
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
          ),
          const SizedBox(width: 4),
          // Format Selector
          PopupMenuButton<PreviewFormat>(
            tooltip: 'Change Page Format',
            initialValue: _selectedFormat,
            onSelected: (PreviewFormat format) {
              setState(() {
                _selectedFormat = format;
              });
            },
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.layers_outlined, color: Color(0xFF1E3A8A), size: 18),
            ),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<PreviewFormat>>[
              for (final format in PreviewFormat.values)
                PopupMenuItem<PreviewFormat>(
                  value: format,
                  child: Text(
                    format.label,
                    style: TextStyle(
                      fontWeight: _selectedFormat == format ? FontWeight.bold : FontWeight.normal,
                      color: _selectedFormat == format ? const Color(0xFF1E3A8A) : Colors.black87,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),


          // Save to Gallery
          IconButton(
            tooltip: 'Save to Gallery',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image_outlined, color: Color(0xFF1E3A8A), size: 18),
            ),
            onPressed: () async {
              try {
                final pdfBytes = await PdfService.generateInvoicePdf(
                  invoice: invoice,
                  businessInfo: businessInfo,
                  pageFormat: _selectedFormat.format,
                );
                
                // Rasterize PDF to image and save to gallery
                await for (var page in Printing.raster(pdfBytes, pages: [0], dpi: 300)) {
                  final pngBytes = await page.toPng();
                  
                  // Convert PNG to JPG in background isolate
                  final jpgBytes = await compute(_convertPngToJpg, pngBytes);

                  if (jpgBytes != null) {
                    await Gal.putImageBytes(jpgBytes);
                  }
                  break; // Only save first page
                }
                
                if (context.mounted) _showToast(context, 'Saved to gallery successfully!');
              } catch (e) {
                if (context.mounted) _showToast(context, 'Failed to save to gallery', isError: true);
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: PdfPreview(
        initialPageFormat: _selectedFormat.format,
        build: (format) => PdfService.generateInvoicePdf(
          invoice: invoice,
          businessInfo: businessInfo,
          pageFormat: _selectedFormat.format,
        ),
        onPrinted: (ctx) => _showToast(context, 'Printed successfully!'),
        onShared: (ctx) => _showToast(context, 'Thank you for using Docara!'),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: '${invoice.id}.pdf',
      ),
    );
  }
}
