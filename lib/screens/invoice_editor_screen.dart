import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/invoice.dart';
import '../providers/invoice_provider.dart';
import '../providers/settings_provider.dart';
import 'pdf_preview_screen.dart';

class InvoiceEditorScreen extends StatefulWidget {
  final bool isEstimate;
  const InvoiceEditorScreen({super.key, this.isEstimate = false});

  @override
  State<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _InvoiceEditorScreenState extends State<InvoiceEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for client
  late TextEditingController _clientNameController;
  late TextEditingController _clientAddressController;
  late TextEditingController _clientContactController;
  
  // Controllers for metadata
  late TextEditingController _invoiceIdController;
  late TextEditingController _cashierNameController;
  
  @override
  void initState() {
    super.initState();
    final invoice = context.read<InvoiceProvider>().currentInvoice!;
    _invoiceIdController = TextEditingController(text: invoice.id);
    _clientNameController = TextEditingController(text: invoice.clientInfo.name);
    _clientAddressController = TextEditingController(text: invoice.clientInfo.address);
    _clientContactController = TextEditingController(text: invoice.clientInfo.contact);
    _cashierNameController = TextEditingController(text: invoice.cashierName);
  }

  @override
  void dispose() {
    _invoiceIdController.dispose();
    _clientNameController.dispose();
    _clientAddressController.dispose();
    _clientContactController.dispose();
    _cashierNameController.dispose();
    super.dispose();
  }

  void _addItem() {
    final currency = context.read<SettingsProvider>().businessInfo?.currency ?? '₵';
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        currency: currency,
        onAdd: (item) {
          context.read<InvoiceProvider>().addItem(item);
        },
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required to scan. Please enable it in settings.')),
      );
      return;
    }

    if (!status.isGranted) return;

    if (!mounted) return;

    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Scan Product Barcode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.flash_on, color: Colors.white),
                          onPressed: () => controller.toggleTorch(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: controller,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final String? code = barcodes.first.rawValue;
                          if (code != null) {
                            controller.dispose();
                            Navigator.pop(context);
                            _onBarcodeScanned(code);
                          }
                        }
                      },
                    ),
                    // Custom Overlay
                    Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: 230,
                                height: 1,
                                color: Colors.red.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Darken outside area
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.5),
                        BlendMode.srcOut,
                      ),
                      child: Stack(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              backgroundBlendMode: BlendMode.dstOut,
                            ),
                          ),
                          Center(
                            child: Container(
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Align barcode within the frame', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => controller.dispose());
  }

  void _onBarcodeScanned(String code) {
    final provider = context.read<InvoiceProvider>();
    final products = provider.products;
    
    // Try to find product by barcode or ID
    final product = products.cast<Product?>().firstWhere(
      (p) => p?.barcode == code || p?.id == code, 
      orElse: () => null
    );

    if (product != null) {
      provider.addItem(InvoiceItem(
        name: product.name,
        quantity: 1,
        sellingPrice: product.price,
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added: ${product.name}')),
      );
    } else {
      // Show "Product Not Found" and allow adding to catalog
      showDialog(
        context: context,
        builder: (context) {
          final nameController = TextEditingController();
          final priceController = TextEditingController();
          final currency = context.read<SettingsProvider>().businessInfo?.currency ?? '₵';

          return AlertDialog(
            title: const Text('Product Not Found'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No product found with barcode:\n$code', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 16),
                  const Text('Add to Catalog:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Product Name', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController, 
                    keyboardType: TextInputType.number, 
                    decoration: InputDecoration(labelText: 'Price ($currency)', isDense: true)
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                    final newProduct = Product(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text,
                      price: double.tryParse(priceController.text) ?? 0.0,
                      barcode: code,
                    );
                    // Add to catalog
                    provider.addProduct(newProduct);
                    // Add to current invoice
                    provider.addItem(InvoiceItem(
                      name: newProduct.name,
                      quantity: 1,
                      sellingPrice: newProduct.price,
                    ));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added ${newProduct.name} to catalog and invoice')),
                    );
                  }
                }, 
                child: const Text('SAVE')
              ),
            ],
          );
        },
      );
    }
  }



  void _preview() {
    // Update client info and ID in provider before navigating
    final provider = context.read<InvoiceProvider>();
    provider.updateClientInfo(
      ClientInfo(
        name: _clientNameController.text,
        address: _clientAddressController.text,
        contact: _clientContactController.text,
      )
    );
    // Update ID if changed
    if (provider.currentInvoice?.id != _invoiceIdController.text) {
      provider.updateInvoice(provider.currentInvoice!.copyWith(id: _invoiceIdController.text));
    }
    provider.saveCurrentInvoice();
    
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfPreviewScreen()));
  }

  void _showCatalog() {
    final provider = context.read<InvoiceProvider>();
    final products = provider.products;
    final currency = context.read<SettingsProvider>().businessInfo?.currency ?? '₵';

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products in catalog. Add some from the home screen.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Product Catalog', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: products.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final p = products[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text('$currency${p.price.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
                    onTap: () {
                      provider.addItem(InvoiceItem(name: p.name, quantity: 1, sellingPrice: p.price));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${p.name}')));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = context.watch<InvoiceProvider>();
    final invoice = invoiceProvider.currentInvoice;
    if (invoice == null) return const Scaffold();

    final settings = context.watch<SettingsProvider>();
    final currency = settings.businessInfo?.currency ?? '₵';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A8A)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          invoice.isPos ? 'Point of Sale' : (invoice.isEstimate ? 'Create Estimate' : (invoice.type == InvoiceType.invoice ? 'Create Invoice' : 'Create Receipt')),
          style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              
              if (!invoice.isPos) ...[
                // Mode Toggles
                _buildModeToggles(invoiceProvider, invoice),
                
                const SizedBox(height: 16),
                

                
                // Document Details
                const Text('Document Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 12),
                _buildDocumentDetailsCard(invoiceProvider, invoice),

                const SizedBox(height: 24),
                
                // Client Information
                const Text('Client Information', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 12),
                _buildClientCard(context, invoiceProvider),
                const SizedBox(height: 20),
              ],
              
              if (invoice.isPos) _buildCashierField(invoiceProvider),
              const SizedBox(height: 12),
              
              // Items List Header
              Row(
                children: [
                  const Text('Items List', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const Spacer(),
                  _buildActionIcon(Icons.inventory_2_outlined, 'Catalog', _showCatalog),
                  const SizedBox(width: 16),
                  _buildActionIcon(Icons.qr_code_scanner, 'Scan', _scanBarcode),
                  const SizedBox(width: 16),
                  _buildActionIcon(Icons.add_circle_outline, 'Add Item', _addItem),
                ],
              ),
              const SizedBox(height: 16),
              _buildItemsList(invoiceProvider, currency),

              const SizedBox(height: 32),
              _buildSummaryCard(invoiceProvider, invoice, currency),
              
              if (invoice.isPos) ...[
                 const SizedBox(height: 32),
                 const Text('POS Receipt Customization', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                 const SizedBox(height: 12),
                 _buildPosSettingsCard(context),
              ],

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(invoice, currency),
    );
  }

  Widget _buildModeToggles(InvoiceProvider provider, Invoice invoice) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildToggleRow(
            Icons.receipt_long_outlined,
            'Receipt Mode',
            'Toggle between Invoice and Receipt',
            invoice.type == InvoiceType.receipt,
            (v) => provider.toggleType(),
          ),
          const Divider(height: 1, indent: 60),
          _buildToggleRow(
            Icons.description_outlined,
            'Estimate Mode',
            'Save as a Quote/Estimate (Not an Invoice)',
            invoice.isEstimate,
            (v) => provider.updateInvoice(invoice.copyWith(isEstimate: v)),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(IconData icon, String title, String subtitle, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: const Color(0xFF1E3A8A), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF1E3A8A),
          ),
        ],
      ),
    );
  }


  Widget _buildDocumentDetailsCard(InvoiceProvider provider, Invoice invoice) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Number', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                _buildSimpleField('Invoice No.', _invoiceIdController),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Date', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: invoice.date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      provider.updateInvoice(invoice.copyWith(date: picked));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(invoice.date),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashierField(InvoiceProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cashier Name', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: TextFormField(
              controller: _cashierNameController,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline, size: 18),
                hintText: 'Enter cashier name',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) => provider.updateCashierName(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(BuildContext context, InvoiceProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildSimpleField('Client Name', _clientNameController)),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _selectCustomer,
                icon: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSimpleField('Client Address', _clientAddressController),
          const SizedBox(height: 12),
          _buildSimpleField('Contact (Phone/Email)', _clientContactController),
        ],
      ),
    );
  }

  void _selectCustomer() {
    final customers = context.read<InvoiceProvider>().customers;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No customers saved yet')));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final c = customers[index];
          return ListTile(
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(c.contact),
            onTap: () {
              setState(() {
                _clientNameController.text = c.name;
                _clientAddressController.text = c.address;
                _clientContactController.text = c.contact;
              });
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Widget _buildSimpleField(String hint, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1E3A8A)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildItemsList(InvoiceProvider provider, String currency) {
    final items = provider.currentInvoice!.items;
    if (items.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text('No items added yet.', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            Text('Tap "Add Item" to start.', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('${item.quantity} x $currency${item.sellingPrice.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              Text('$currency${item.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => provider.removeItem(index)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(InvoiceProvider provider, Invoice invoice, String currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _summaryRow('Subtotal:', '$currency${invoice.subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text('Discount:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 60,
                child: TextFormField(
                  initialValue: invoice.discountValue.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  onChanged: (v) => provider.updateDiscount(double.tryParse(v) ?? 0, invoice.discountType),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    _toggleItem('%', invoice.discountType == DiscountType.percentage, () => provider.updateDiscount(invoice.discountValue, DiscountType.percentage)),
                    _toggleItem(currency, invoice.discountType == DiscountType.fixed, () => provider.updateDiscount(invoice.discountValue, DiscountType.fixed)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text('Tax/VAT:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 60,
                child: TextFormField(
                  initialValue: invoice.taxValue.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  onChanged: (v) => provider.updateTax(double.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              const Text('%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
            ],
          ),
          const Divider(height: 32),
          _summaryRow('Total:', '$currency${invoice.total.toStringAsFixed(2)}', valueStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A))),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text('Amount Paid:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: invoice.amountPaid.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  onChanged: (v) => provider.updateAmountPaid(double.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Payment Method', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildPaymentToggle(provider, invoice),
        ],
      ),
    );
  }

  Widget _toggleItem(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFC7D2FE) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF1E3A8A) : Colors.grey)),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        Text(value, style: valueStyle ?? const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPaymentToggle(InvoiceProvider provider, Invoice invoice) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _paymentToggleItem('Cash', Icons.check, invoice.paymentMethod == PaymentMethod.cash, () => provider.updatePaymentMethod(PaymentMethod.cash)),
          _paymentToggleItem('MoMo', Icons.phone_android, invoice.paymentMethod == PaymentMethod.momo, () => provider.updatePaymentMethod(PaymentMethod.momo)),
          _paymentToggleItem('Transfer', Icons.account_balance_outlined, invoice.paymentMethod == PaymentMethod.transfer, () => provider.updatePaymentMethod(PaymentMethod.transfer)),
        ],
      ),
    );
  }

  Widget _paymentToggleItem(String label, IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE0E7FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              size: 16, 
              color: isActive ? const Color(0xFF1E3A8A) : Colors.grey
            ),
            const SizedBox(width: 8),
            Text(
              label, 
              style: TextStyle(
                fontSize: 13, 
                fontWeight: FontWeight.bold, 
                color: isActive ? const Color(0xFF1E3A8A) : Colors.grey
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(Invoice invoice, String currency) {
    bool isPaid = invoice.amountPaid >= invoice.total && invoice.total > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GRAND TOTAL', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Text('$currency${invoice.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                  const SizedBox(width: 8),
                  if (isPaid)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(4)),
                    child: const Text('PAID', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _preview,
            icon: const Icon(Icons.visibility_outlined, size: 20),
            label: const Text('PREVIEW PDF', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosSettingsCard(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final biz = settings.businessInfo;
    if (biz == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsField(
            'Subtitle / Terms',
            biz.posSubtitle ?? biz.terms ?? '',
            'e.g. Thank you for your business!',
            (v) => settings.updateBusinessInfo(biz.copyWith(posSubtitle: v)),
          ),
          const SizedBox(height: 16),
          _buildSettingsField(
            'Footer Message',
            biz.posFooterMessage ?? 'Thank you for shopping with us! Please come again.',
            'Displayed above QR code',
            (v) => settings.updateBusinessInfo(biz.copyWith(posFooterMessage: v)),
          ),
          const SizedBox(height: 16),
          _buildSettingsField(
            'Contact Email',
            biz.posEmail ?? biz.email,
            'Support email',
            (v) => settings.updateBusinessInfo(biz.copyWith(posEmail: v)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsField(String label, String value, String hint, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          onChanged: (v) => onChanged(v),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  final String currency;
  final Function(InvoiceItem) onAdd;
  const _AddItemDialog({required this.onAdd, required this.currency});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Item Name')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _priceController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Price (${widget.currency})'))),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text;
            final qty = int.tryParse(_qtyController.text) ?? 1;
            final price = double.tryParse(_priceController.text) ?? 0;
            if (name.isNotEmpty && price > 0) {
              widget.onAdd(InvoiceItem(name: name, quantity: qty, sellingPrice: price));
              Navigator.pop(context);
            }
          },
          child: const Text('ADD'),
        ),
      ],
    );
  }
}

