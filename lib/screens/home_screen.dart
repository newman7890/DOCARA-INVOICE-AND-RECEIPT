import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
import '../providers/invoice_provider.dart';
import '../providers/settings_provider.dart';
import 'invoice_editor_screen.dart';
import 'business_profile_screen.dart';
import 'pdf_preview_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;
import 'package:permission_handler/permission_handler.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeTab = 0; // 0: Documents, 1: Customers, 2: Products
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _activeTab);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _activeTab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = context.watch<InvoiceProvider>();
    final settings = context.watch<SettingsProvider>();
    final biz = settings.businessInfo;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text(
          'Docara POS receipt and invoice',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Color(0xFF1E293B), size: 28),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessProfileScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _buildProfileCard(context, biz, invoiceProvider),
                  const SizedBox(height: 20),
                  _buildStatCards(context),
                  const SizedBox(height: 20),
                  _buildRevenueGoal(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildTabs()),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ],
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _activeTab = index);
          },
          children: [
            // Documents Page
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildInvoiceList(invoiceProvider.invoices),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            // Customers Page
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildTabContentItems(1, invoiceProvider),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            // Products Page
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildTabContentItems(2, invoiceProvider),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _activeTab == 0
          ? _buildAddButton(context, 'Create Invoice', Icons.add)
          : _activeTab == 1
              ? _buildAddButton(context, 'Add Customer', Icons.person_add_alt_1)
              : _activeTab == 2
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 20, right: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildScanButton(context, noPadding: true),
                          const SizedBox(height: 12),
                          _buildAddButton(context, 'Add Product', Icons.add_shopping_cart, noPadding: true),
                        ],
                      ),
                    )
                  : null,
    );
  }

  Widget _buildProfileCard(BuildContext context, dynamic biz, InvoiceProvider invoiceProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: biz?.logoPath != null && File(biz!.logoPath!).existsSync()
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(biz!.logoPath!), fit: BoxFit.cover),
                  )
                : const Icon(Icons.business, color: Color(0xFF1E3A8A)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              biz?.name ?? 'Company Name',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _actionIcon(context, Icons.qr_code_scanner, 'BARCODE', () {
            _showBarcodeStudio(context);
          }),
          const SizedBox(width: 15),
          _actionIcon(context, Icons.point_of_sale, 'POS', () {
            invoiceProvider.createNewInvoice(isPos: true);
            invoiceProvider.toggleType(); // Switch to receipt
            Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceEditorScreen()));
          }),
        ],
      ),
    );
  }

  Widget _actionIcon(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();
    final settings = context.watch<SettingsProvider>();
    final currency = settings.businessInfo?.currency ?? '₵';

    double totalPaid = 0;
    double outstanding = 0;
    int overdueCount = 0;

    for (var inv in provider.invoices) {
      if (inv.isEstimate) continue;
      
      if (inv.type == InvoiceType.receipt) {
        totalPaid += inv.total;
      } else {
        outstanding += inv.total;
        if (inv.dueDate != null && inv.dueDate!.isBefore(DateTime.now())) {
          overdueCount++;
        }
      }
    }

    return Row(
      children: [
        Expanded(
          child: _statCard(
            context,
            'TOTAL PAID',
            '$currency${totalPaid.toStringAsFixed(0)}',
            Icons.check_circle,
            const Color(0xFF10B981),
            null,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _statCard(
            context,
            'OUTSTANDING',
            '$currency${outstanding.toStringAsFixed(0)}',
            Icons.warning_amber_rounded,
            const Color(0xFFF59E0B),
            overdueCount > 0 ? '$overdueCount OVERDUE' : null,
          ),
        ),
      ],
    );
  }

  Widget _statCard(BuildContext context, String label, String value, IconData icon, Color color, String? subtext) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          if (subtext != null) ...[
            const SizedBox(height: 4),
            Text(
              subtext,
              style: TextStyle(
                fontSize: 9,
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRevenueGoal(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();
    final settings = context.watch<SettingsProvider>();
    final biz = settings.businessInfo;
    final currency = biz?.currency ?? '₵';
    final goal = biz?.revenueGoal ?? 0.0;

    double currentRevenue = 0;
    final now = DateTime.now();
    for (var inv in provider.invoices) {
      if (!inv.isEstimate && 
          inv.date.month == now.month && 
          inv.date.year == now.year &&
          inv.type == InvoiceType.receipt) {
        currentRevenue += inv.total;
      }
    }

    double progress = goal > 0 ? (currentRevenue / goal).clamp(0.0, 1.0) : 0.0;
    int percentage = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MONTHLY REVENUE GOAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[400],
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$currency${currentRevenue.toStringAsFixed(0)} of $currency${goal.toStringAsFixed(0)} this month',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _tabItem(0, Icons.description_outlined, 'Documents'),
        _tabItem(1, Icons.people_outline, 'Customers'),
        _tabItem(2, Icons.inventory_2_outlined, 'Products'),
      ],
    );
  }

  Widget _tabItem(int index, IconData icon, String label) {
    bool isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        child: Container(
          color: Colors.transparent, // Improve tap area
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF1E3A8A) : Colors.grey[400],
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? const Color(0xFF1E293B) : Colors.grey[400],
                ),
              ),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isActive ? 40 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContentItems(int tabIndex, InvoiceProvider provider) {
    String message = '';
    IconData icon = Icons.info_outline;
    List<dynamic> items = [];

    if (tabIndex == 1) {
      message = 'No customers saved yet.';
      icon = Icons.people_outline;
      items = provider.customers;
    } else if (tabIndex == 2) {
      message = 'No products saved yet.';
      icon = Icons.inventory_2_outlined;
      items = provider.products;
    }

    if (items.isNotEmpty) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is Customer) {
            return GestureDetector(
              onTap: () => _showCustomerOptions(context, item),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey[100]!),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEEF2FF),
                    child: const Icon(Icons.person, color: Color(0xFF1E3A8A)),
                  ),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(item.contact, style: const TextStyle(fontSize: 12)),
                ),
              ),
            );
          } else if (item is Product) {
            final currency = context.watch<SettingsProvider>().businessInfo?.currency ?? '₵';
            return GestureDetector(
              onTap: () => _showProductOptions(context, item),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey[100]!),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFEF3C7),
                    child: const Icon(Icons.shopping_bag, color: Color(0xFFD97706)),
                  ),
                  title: Row(
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (item.barcode != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.qr_code, size: 14, color: Colors.grey),
                      ],
                    ],
                  ),
                  trailing: Text('$currency${item.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                ),
              ),
            );
          }
          return const SizedBox();
        },
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        Icon(icon, size: 64, color: Colors.grey[100]),
        const SizedBox(height: 16),
        Text(
          message,
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
      ],
    );
  }

  // Removed _buildSubToggle and _subToggleItem as the feature was requested to be removed.

  void _showCustomerOptions(BuildContext context, Customer customer) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A)),
              ),
              title: const Text('Edit Customer', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _showAddCustomerDialog(context, existingCustomer: customer);
              },
            ),
            const Divider(indent: 72),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
              ),
              title: const Text('Delete Customer', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
              onTap: () {
                Navigator.pop(context);
                _confirmDeletion(context, 'Delete Customer?', 'Are you sure you want to delete ${customer.name}?', () {
                  context.read<InvoiceProvider>().deleteCustomer(customer.name);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProductOptions(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            if (product.barcode != null) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.qr_code_2_outlined, color: Color(0xFF22C55E)),
                ),
                title: const Text('View Barcode', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _viewBarcode(context, product);
                },
              ),
              const Divider(indent: 72),
            ],
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A)),
              ),
              title: const Text('Edit Product', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _showAddProductDialog(context, existingProduct: product);
              },
            ),
            const Divider(indent: 72),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
              ),
              title: const Text('Delete Product', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
              onTap: () {
                Navigator.pop(context);
                _confirmDeletion(context, 'Delete Product?', 'Are you sure you want to delete ${product.name}?', () {
                  context.read<InvoiceProvider>().deleteProduct(product.name);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBarcodeStudio(BuildContext context) {
    final products = context.read<InvoiceProvider>().products;
    String customData = '';
    String customName = '';
    String customPrice = '';
    Product? selectedProduct;
    bool isCustomMode = false;

    final List<Map<String, dynamic>> barcodeTypes = [
      {'name': 'Code 128 (Standard)', 'type': Barcode.code128(), 'icon': Icons.view_column_outlined},
      {'name': 'QR Code (Digital)', 'type': Barcode.qrCode(), 'icon': Icons.qr_code_2},
      {'name': 'EAN 13 (International)', 'type': Barcode.ean13(), 'icon': Icons.numbers},
      {'name': 'Code 39 (Simple)', 'type': Barcode.code39(), 'icon': Icons.barcode_reader},
      {'name': 'UPC A (Retail)', 'type': Barcode.upcA(), 'icon': Icons.shopping_cart_outlined},
      {'name': 'Data Matrix', 'type': Barcode.dataMatrix(), 'icon': Icons.grid_on},
    ];

    Barcode selectedType = barcodeTypes[0]['type'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStudioState) {
          final data = isCustomMode ? customData : (selectedProduct?.barcode ?? '');
          bool isValid = true;
          String errorMsg = '';
          
          if (data.isEmpty) {
            isValid = false;
            errorMsg = 'Enter data or select product';
          } else {
            try {
              selectedType.verify(data);
            } catch (e) {
              isValid = false;
              final msg = e.toString().toLowerCase();
              if (msg.contains('digits')) {
                errorMsg = 'Numeric digits only';
              } else if (selectedType.name.toLowerCase().contains('ean')) {
                errorMsg = 'EAN-13 needs 12 or 13 digits';
              } else if (selectedType.name.toLowerCase().contains('upc')) {
                errorMsg = 'UPC-A needs 11 or 12 digits';
              } else {
                errorMsg = 'Incompatible format';
              }
            }
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.qr_code_scanner, color: Color(0xFF1E3A8A)),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DEDICATED TOOL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                            Text('Barcode Studio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), style: IconButton.styleFrom(backgroundColor: Colors.grey[200])),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Mode Toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setStudioState(() => isCustomMode = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isCustomMode ? const Color(0xFF1E3A8A) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('Product Mode', textAlign: TextAlign.center, style: TextStyle(color: !isCustomMode ? Colors.white : Colors.black54, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setStudioState(() => isCustomMode = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isCustomMode ? const Color(0xFF1E3A8A) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('Quick Mode', textAlign: TextAlign.center, style: TextStyle(color: isCustomMode ? Colors.white : Colors.black54, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isCustomMode) ...[
                          const Text('SELECT PRODUCT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Product>(
                                hint: const Text('Choose a product...', style: TextStyle(fontSize: 14)),
                                value: selectedProduct,
                                isExpanded: true,
                                items: products.where((p) => p.barcode != null).map((p) => DropdownMenuItem(value: p, child: Text(p.name, style: const TextStyle(fontSize: 14)))).toList(),
                                onChanged: (p) => setStudioState(() => selectedProduct = p),
                              ),
                            ),
                          ),
                        ] else ...[
                          const Text('LABEL DETAILS (OPTIONAL)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          _buildStyledTextField(
                            controller: TextEditingController(text: customName)..selection = TextSelection.fromPosition(TextPosition(offset: customName.length)),
                            hint: 'Product Name (e.g. Milk)',
                            icon: Icons.label_outline,
                            onChanged: (val) => setStudioState(() => customName = val),
                          ),
                          const SizedBox(height: 12),
                          _buildStyledTextField(
                            controller: TextEditingController(text: customPrice)..selection = TextSelection.fromPosition(TextPosition(offset: customPrice.length)),
                            hint: 'Price (e.g. 10.00)',
                            icon: Icons.payments_outlined,
                            keyboardType: TextInputType.number,
                            onChanged: (val) => setStudioState(() => customPrice = val),
                          ),
                          const SizedBox(height: 20),
                          const Text('BARCODE CONTENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStyledTextField(
                                  controller: TextEditingController(text: customData)..selection = TextSelection.fromPosition(TextPosition(offset: customData.length)),
                                  hint: 'Type ID or generate...',
                                  icon: Icons.edit_note,
                                  onChanged: (val) => setStudioState(() => customData = val),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  setStudioState(() {
                                    // Generate a 12-digit numeric string as requested
                                    customData = DateTime.now().millisecondsSinceEpoch.toString().substring(1, 13);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.auto_fix_high, color: Colors.white, size: 24),
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        const Text('SELECT FORMAT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: barcodeTypes.length,
                            itemBuilder: (context, index) {
                              final item = barcodeTypes[index];
                              final isSelected = selectedType == item['type'];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(item['name'].split(' ')[0]),
                                  selected: isSelected,
                                  onSelected: (val) => setStudioState(() => selectedType = item['type']),
                                  selectedColor: const Color(0xFF1E3A8A),
                                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        const Text('PREVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey[200]!)),
                          child: Column(
                            children: [
                              if (isValid)
                                BarcodeWidget(barcode: selectedType, data: data, width: double.infinity, height: 120, drawText: true)
                              else
                                Column(
                                  children: [
                                    const Icon(Icons.qr_code_2, color: Colors.grey, size: 48),
                                    const SizedBox(height: 12),
                                    Text(errorMsg, style: TextStyle(color: data.isEmpty ? Colors.grey : Colors.red, fontSize: 12)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: ElevatedButton.icon(
                    onPressed: isValid ? () {
                      final printProduct = selectedProduct ?? Product(
                        id: 'custom',
                        name: customName.isEmpty ? 'Custom Product' : customName,
                        price: double.tryParse(customPrice) ?? 0.0,
                        barcode: data,
                      );
                      _printBarcode(printProduct, selectedType);
                    } : null,
                    icon: const Icon(Icons.print),
                    label: const Text('Print Barcode', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _viewBarcode(BuildContext context, Product product) {
    // Keep the existing simplified _viewBarcode for quick viewing from product list
    final List<Map<String, dynamic>> barcodeTypes = [
      {'name': 'Code 128', 'type': Barcode.code128()},
      {'name': 'QR Code', 'type': Barcode.qrCode()},
    ];
    Barcode selectedType = barcodeTypes[0]['type'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BarcodeWidget(barcode: selectedType, data: product.barcode!, width: 200, height: 100, drawText: true),
            const SizedBox(height: 20),
            Text('ID: ${product.barcode}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
          ElevatedButton(onPressed: () => _printBarcode(product, selectedType), child: const Text('PRINT')),
        ],
      ),
    );
  }

  Future<void> _printBarcode(Product product, Barcode barcodeType) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(product.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.BarcodeWidget(
                    barcode: barcodeType,
                    data: product.barcode!,
                    width: 150,
                    height: 80,
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(product.barcode!, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            );
          },
        ),
      );
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      debugPrint('Error printing barcode: $e');
    }
  }

  void _confirmDeletion(BuildContext context, String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            }, 
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showInvoiceOptions(BuildContext context, Invoice inv) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                inv.id,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A)),
                ),
                title: const Text('Edit Document', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Modify items, client info or details'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<InvoiceProvider>().updateInvoice(inv);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InvoiceEditorScreen()),
                  );
                },
              ),
              const Divider(indent: 72),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.visibility_outlined, color: Color(0xFF22C55E)),
                ),
                title: const Text('View / Preview', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('View and share PDF document'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<InvoiceProvider>().updateInvoice(inv);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PdfPreviewScreen()),
                  );
                },
              ),
              const Divider(indent: 72),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                ),
                title: const Text('Delete Document', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                subtitle: const Text('Permanently remove this document'),
                onTap: () {
                   Navigator.pop(context);
                   _confirmDeletion(context, 'Delete Document?', 'Are you sure you want to delete ${inv.id}?', () {
                     context.read<InvoiceProvider>().deleteInvoice(inv.id);
                   });
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvoiceList(List<Invoice> invoices) {
    if (invoices.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.description_outlined, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text('No documents yet.', style: TextStyle(color: Colors.grey[400])),
        ],
      );
    }

    final settings = context.watch<SettingsProvider>();
    final currency = settings.businessInfo?.currency ?? '₵';

    final filtered = invoices;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final inv = filtered[index];
        final isPaid = inv.type == InvoiceType.receipt;
        final isOverdue = !isPaid && !inv.isEstimate && inv.dueDate != null && inv.dueDate!.isBefore(DateTime.now());

        return GestureDetector(
          onTap: () => _showInvoiceOptions(context, inv),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    inv.isEstimate ? Icons.assignment : (inv.type == InvoiceType.receipt ? Icons.receipt_long : Icons.description),
                    color: isPaid ? const Color(0xFF10B981) : const Color(0xFF1E3A8A),
                    size: 20
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${inv.id}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            inv.isEstimate ? 'ESTIMATE' : (inv.type == InvoiceType.invoice ? 'INVOICE' : 'RECEIPT'),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${inv.clientInfo.name} • ${inv.date.day} ${_getMonthName(inv.date.month)}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      if (!inv.isEstimate)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPaid 
                              ? const Color(0xFFECFDF5) 
                              : (isOverdue ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPaid ? 'PAID' : (isOverdue ? 'OVERDUE' : 'UNPAID'),
                          style: TextStyle(
                            color: isPaid ? const Color(0xFF10B981) : (isOverdue ? const Color(0xFFEF4444) : Colors.grey[600]),
                            fontSize: 8,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$currency${inv.total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),

                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildAddButton(BuildContext context, String label, IconData icon, {bool noPadding = false}) {
    final button = ElevatedButton.icon(
      onPressed: () {
        if (_activeTab == 0) {
          context.read<InvoiceProvider>().createNewInvoice();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const InvoiceEditorScreen(),
            ),
          );
        } else if (_activeTab == 1) {
          _showAddCustomerDialog(context);
        } else if (_activeTab == 2) {
          _showAddProductDialog(context);
        }
      },
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    if (noPadding) return button;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20, right: 10),
      child: button,
    );
  }

  Widget _buildScanButton(BuildContext context, {bool noPadding = false}) {
    final button = ElevatedButton.icon(
      onPressed: () => _scanProductBarcode(context),
      icon: const Icon(Icons.qr_code_scanner, size: 20),
      label: const Text('Scan', style: TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    if (noPadding) return button;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20, right: 10),
      child: button,
    );
  }

  Future<void> _scanProductBarcode(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required to scan. Please enable it in settings.')),
      );
      return;
    }

    if (!status.isGranted) return;
    if (!context.mounted) return;

    final controller = ms.MobileScannerController(
      detectionSpeed: ms.DetectionSpeed.noDuplicates,
      facing: ms.CameraFacing.back,
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
                    ms.MobileScanner(
                      controller: controller,
                      onDetect: (capture) {
                        final List<ms.Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final String? code = barcodes.first.rawValue;
                          if (code != null) {
                            controller.dispose();
                            Navigator.pop(context);
                            _handleScannedProduct(code);
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

  void _handleScannedProduct(String code) {
    final provider = context.read<InvoiceProvider>();
    final products = provider.products;
    
    // Check if product already exists
    final product = products.cast<Product?>().firstWhere(
      (p) => p?.barcode == code || p?.id == code, 
      orElse: () => null
    );

    if (product != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} already exists in the catalog!')),
      );
    } else {
      // Product doesn't exist, open Add Product dialog pre-filled
      _showAddProductDialog(context, initialBarcode: code);
    }
  }

  void _showAddCustomerDialog(BuildContext context, {Customer? existingCustomer}) {
    final nameController = TextEditingController(text: existingCustomer?.name);
    final addressController = TextEditingController(text: existingCustomer?.address);
    final contactController = TextEditingController(text: existingCustomer?.contact);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingCustomer == null ? 'Add New Customer' : 'Edit Customer'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Customer Name')),
              const SizedBox(height: 8),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 8),
              TextField(controller: contactController, decoration: const InputDecoration(labelText: 'Contact (Phone/Email)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final customer = Customer(
                  id: existingCustomer?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  address: addressController.text,
                  contact: contactController.text,
                );
                if (existingCustomer == null) {
                  context.read<InvoiceProvider>().addCustomer(customer);
                } else {
                  context.read<InvoiceProvider>().updateCustomer(customer);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(BuildContext context, {Product? existingProduct, String? initialBarcode}) {
    final nameController = TextEditingController(text: existingProduct?.name);
    final priceController = TextEditingController(text: existingProduct?.price.toString());
    final barcodeController = TextEditingController(text: existingProduct?.barcode ?? initialBarcode);
    final currency = context.read<SettingsProvider>().businessInfo?.currency ?? '₵';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_shopping_cart, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          existingProduct == null ? 'Add New Product' : 'Edit Product',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(backgroundColor: Colors.grey[200]),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputLabel('PRODUCT NAME'),
                      const SizedBox(height: 8),
                      _buildStyledTextField(
                        controller: nameController,
                        hint: 'e.g. Fresh Milk',
                        icon: Icons.inventory_2_outlined,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      _buildInputLabel('PRICE ($currency)'),
                      const SizedBox(height: 8),
                      _buildStyledTextField(
                        controller: priceController,
                        hint: '0.00',
                        icon: Icons.payments_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      _buildInputLabel('BARCODE (OPTIONAL)'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStyledTextField(
                              controller: barcodeController,
                              hint: 'Scan or enter code',
                              icon: Icons.qr_code_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                              final product = Product(
                                id: existingProduct?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                                name: nameController.text,
                                price: double.tryParse(priceController.text) ?? 0.0,
                                barcode: barcodeController.text.isNotEmpty ? barcodeController.text : null,
                              );
                              if (existingProduct == null) {
                                context.read<InvoiceProvider>().addProduct(product);
                              } else {
                                context.read<InvoiceProvider>().updateProduct(product);
                              }
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('Save Product', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
      ),
    );
  }
}

