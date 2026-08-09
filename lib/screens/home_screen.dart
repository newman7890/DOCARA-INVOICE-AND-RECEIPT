import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../providers/invoice_provider.dart';
import '../services/supabase_service.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import 'invoice_editor_screen.dart';
import 'pdf_preview_screen.dart';
import 'expense_editor_dialog.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;
import 'staff_management_screen.dart';
import 'sync_settings_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'business_profile_screen.dart';
import 'help_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeTab = 0; // 0: Dashboard, 1: Documents, 2: Clients, 3: Inventory, 4: Expenses
  late PageController _pageController;
  String _searchQuery = '';
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _activeTab);
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    // Wait a moment for the screen to settle
    await Future.delayed(const Duration(seconds: 2));
    
    try {
      final service = SupabaseService();
      final latest = await service.getLatestVersion();
      
      if (latest == null) return;
      
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      
      final serverVersionString = latest['value'] as String;
      final serverBuildStr = serverVersionString.contains('+') 
          ? serverVersionString.split('+').last 
          : '0';
      final serverBuild = int.tryParse(serverBuildStr) ?? 0;
      
      final downloadUrl = latest['download_url'] as String?;

      if (serverBuild > currentBuild && downloadUrl != null) {
        if (!mounted) return;
        _showUpdateDialog(serverVersionString, downloadUrl);
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  void _showUpdateDialog(String newVersion, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Text('Update Available'),
          ],
        ),
        content: Text(
          'A new version ($newVersion) of Docara is available. Update now to get the latest features and fixes!',
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Download Now'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    _performTabChange(index);
  }

  void _performTabChange(int index) {
    setState(() {
      _activeTab = index;
      _searchQuery = '';
    });
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

    // If we are exiting, show a clean background to prevent "Admin Flash"
    if (_isExiting) {
      return const Scaffold(backgroundColor: Color(0xFFF8FAFC));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
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
          if (invoiceProvider.hasPendingSync)
            invoiceProvider.isLoading 
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent)),
                )
              : IconButton(
                  icon: const Icon(Icons.cloud_off, color: Colors.redAccent),
                  tooltip: 'Offline Receipts Pending Sync',
                  onPressed: () async {
                    final results = await invoiceProvider.syncOfflineInvoices();
                    if (!context.mounted) return;
                    
                    if (results['success'] == results['total'] && results['total']! > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All offline receipts synced successfully!'),
                          backgroundColor: Colors.green,
                        )
                      );
                    } else if (results['success']! > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Synced ${results['success']} of ${results['total']} receipts. Some failed.'),
                          backgroundColor: Colors.orange,
                        )
                      );
                    } else if (results['total']! > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sync failed: ${results['error'] ?? 'No internet'}'),
                          backgroundColor: Colors.red,
                        )
                      );
                    }
                  },
                ),
          IconButton(
            icon: const Icon(Icons.sync, color: Color(0xFF1E293B)),
            onPressed: () {
              if (invoiceProvider.activeStaff == null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncSettingsScreen()));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only Admin can access sync settings')));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF1E293B)),
            tooltip: 'User Guide',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF1E293B)),
            onPressed: () async {
              // 1. Instantly hide the UI
              setState(() => _isExiting = true);
              
              // 2. Perform logouts
              final authProv = context.read<AuthProvider>();
              final invoiceProv = context.read<InvoiceProvider>();
              
              await invoiceProv.setActiveStaff(null);
              await authProv.signOut();
              
              // 3. Navigate to login
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
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
                  _buildProfileCard(context, biz, invoiceProvider, settings),
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
          children: () {
            final activeStaff = invoiceProvider.activeStaff;
            final isManager = activeStaff?.role == 'Manager';
            
            if (activeStaff == null) {
              // Admin View (5 Tabs)
              return [
                _buildDashboard(invoiceProvider, settings),
                _buildTabWrapper(_buildInvoiceList(invoiceProvider.invoices)),
                _buildTabWrapper(_buildTabContentItems(2, invoiceProvider)),
                _buildTabWrapper(_buildTabContentItems(3, invoiceProvider)),
                _buildTabWrapper(_buildTabContentItems(4, invoiceProvider)),
              ];
            } else if (isManager) {
              // Manager View (3 Tabs)
              return [
                _buildDashboard(invoiceProvider, settings),
                _buildTabWrapper(_buildInvoiceList(invoiceProvider.invoices, viewOnly: true)),
                _buildTabWrapper(_buildTabContentItems(3, invoiceProvider)),
              ];
            } else {
              // Cashier View (2 Tabs)
              return [
                _buildDashboard(invoiceProvider, settings),
                _buildTabWrapper(_buildInvoiceList(
                  invoiceProvider.invoices
                    .where((i) => i.cashierName == activeStaff.name)
                    .toList(),
                  viewOnly: true,
                )),
              ];
            }
          }(),
        ),
      ),
      floatingActionButton: invoiceProvider.activeStaff != null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildAddButton(context, 'Create Invoice/Receipt', Icons.receipt_long, noPadding: true, onTap: () {
                    invoiceProvider.createNewInvoice(isPos: false);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceEditorScreen()));
                  }),
                  const SizedBox(height: 12),
                  _buildAddButton(context, 'New Sale (POS)', Icons.point_of_sale, noPadding: true, onTap: () {
                    invoiceProvider.createNewInvoice(isPos: true);
                    invoiceProvider.toggleType();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceEditorScreen()));
                  }),
                  const SizedBox(height: 12),
                  _buildAddButton(context, 'Barcode Scanner', Icons.qr_code_scanner, noPadding: true, onTap: () {
                    _scanProductBarcode(context);
                  }),
                ],
              ),
            )
          : _activeTab == 1
              ? _buildAddButton(context, 'Create Invoice', Icons.add)
              : _activeTab == 2
                  ? _buildAddButton(context, 'Add Customer', Icons.person_add_alt_1)
                  : _activeTab == 3
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
                      : _activeTab == 4
                          ? _buildAddButton(context, 'Add Expense', Icons.money_off, onTap: () async {
                              if (await _authorizeAdmin(context)) {
                                _showAddExpenseDialog();
                              }
                            })
                          : null,
    );
  }

  Widget _buildProfileCard(BuildContext context, dynamic biz, InvoiceProvider invoiceProvider, SettingsProvider settings) {
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: GestureDetector(
              onTap: () {
                if (invoiceProvider.activeStaff == null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessProfileScreen()));
                }
              },
              child: biz?.logoPath != null && File(biz!.logoPath!).existsSync()
                  ? ClipOval(
                      child: Image.file(File(biz!.logoPath!), fit: BoxFit.cover),
                    )
                  : const Icon(Icons.business, color: Color(0xFF1E3A8A), size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    if (invoiceProvider.activeStaff == null) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessProfileScreen()));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only Admin can edit business profile')));
                    }
                  },
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          biz?.name ?? 'Company Name',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (invoiceProvider.activeStaff == null) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.edit, color: Colors.white.withValues(alpha: 0.6), size: 14),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    if (invoiceProvider.activeStaff == null) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffManagementScreen()));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only Admin can manage staff')));
                    }
                  },
                  child: Row(
                    children: [
                      Icon(Icons.person_pin, color: Colors.white.withValues(alpha: 0.7), size: 12),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${invoiceProvider.activeStaff?.role ?? "Admin"}: ${invoiceProvider.activeStaff?.name ?? "Admin"}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.computer, color: Colors.white.withValues(alpha: 0.6), size: 12),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        settings.stationName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (invoiceProvider.activeStaff == null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                        child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Icon(Icons.cloud_done, color: Colors.white.withValues(alpha: 0.6), size: 11),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                  onPressed: () => _showBarcodeStudio(context),
                  tooltip: 'Barcode Scanner',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
                Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.3)),
                IconButton(
                  icon: const Icon(Icons.point_of_sale, color: Colors.white, size: 20),
                  onPressed: () {
                    invoiceProvider.createNewInvoice(isPos: true);
                    invoiceProvider.toggleType();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceEditorScreen()));
                  },
                  tooltip: 'New POS Sale',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildTabs() {
    final activeStaff = context.read<InvoiceProvider>().activeStaff;
    final isStaff = activeStaff != null;
    final isManager = activeStaff?.role == 'Manager';

    if (isStaff) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _tabItem(0, Icons.dashboard_outlined, 'Dashboard'),
            _tabItem(1, Icons.receipt_long_outlined, isManager ? 'All Documents' : 'My Documents'),
            if (isManager) _tabItem(2, Icons.inventory_2_outlined, 'Inventory'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _tabItem(0, Icons.dashboard_outlined, 'Dashboard'),
          _tabItem(1, Icons.description_outlined, 'Documents'),
          _tabItem(2, Icons.people_outline, 'Clients'),
          _tabItem(3, Icons.inventory_2_outlined, 'Inventory'),
          _tabItem(4, Icons.money_off_outlined, 'Expenses'),
        ],
      ),
    );
  }

  Widget _tabItem(int index, IconData icon, String label) {
    bool isActive = _activeTab == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.transparent,
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
    );
  }

  Widget _buildTabContentItems(int tabIndex, InvoiceProvider provider) {
    String message = '';
    IconData icon = Icons.info_outline;
    List<dynamic> sourceItems = [];

    if (tabIndex == 2) {
      message = 'No customers saved yet.';
      icon = Icons.people_outline;
      sourceItems = provider.customers;
    } else if (tabIndex == 3) {
      message = 'No products saved yet.';
      icon = Icons.inventory_2_outlined;
      sourceItems = provider.products;
    } else if (tabIndex == 4) {
      message = 'No expenses recorded yet.';
      icon = Icons.money_off_outlined;
      sourceItems = provider.expenses;
    }

    if (sourceItems.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Icon(icon, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      );
    }

    // Apply search filter
    List<dynamic> items = sourceItems;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      items = items.where((item) {
        if (item is Customer) {
          return item.name.toLowerCase().contains(query);
        } else if (item is Product) {
          return item.name.toLowerCase().contains(query) || (item.barcode?.toLowerCase().contains(query) ?? false);
        } else if (item is Expense) {
          return item.description.toLowerCase().contains(query);
        }
        return false;
      }).toList();
    }

    final searchBar = Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search...',
          prefixIcon: const Icon(Icons.search),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        searchBar,
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Text('No results found for "$_searchQuery"', style: TextStyle(color: Colors.grey[600])),
            ),
          )
        else
          ListView.separated(
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
                      subtitle: Text('Spent: ${context.watch<SettingsProvider>().businessInfo?.currency ?? "₵"}${item.totalSpent.toStringAsFixed(2)} • ${item.invoiceCount} invoices', style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                );
              } else if (item is Product) {
                final currency = context.watch<SettingsProvider>().businessInfo?.currency ?? '₵';
                bool isLowStock = item.stockQuantity <= item.minStockLevel;
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
                        backgroundColor: isLowStock ? const Color(0xFFFEF2F2) : const Color(0xFFFEF3C7),
                        child: Icon(Icons.shopping_bag, color: isLowStock ? Colors.red : const Color(0xFFD97706)),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                          if (item.barcode != null) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.qr_code, size: 14, color: Colors.grey),
                          ],
                        ],
                      ),
                      subtitle: Text('Stock: ${item.stockQuantity} units', style: TextStyle(color: isLowStock ? Colors.red : Colors.grey, fontSize: 11, fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal)),
                      trailing: Text('$currency${item.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                    ),
                  ),
                );
              } else if (item is Expense) {
                return _buildExpenseItem(item);
              }
              return const SizedBox();
            },
          ),
      ],
    );
  }

  void _showCustomerOptions(BuildContext context, Customer customer) {
    final invoiceProvider = context.read<InvoiceProvider>();
    final activeStaff = invoiceProvider.activeStaff;
    final isAdmin = activeStaff == null;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final outerContext = context;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_outlined, color: Color(0xFF0284C7)),
              ),
              title: const Text('View Invoices', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetContext);
                _showCustomerInvoicesList(outerContext, customer);
              },
            ),
            const Divider(indent: 72),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A)),
              ),
              title: const Text('Edit Customer', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAddCustomerDialog(outerContext, existingCustomer: customer);
              },
            ),
            const Divider(indent: 72),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.refresh_outlined, color: Color(0xFF22C55E)),
              ),
              title: const Text('Recalculate Stats', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Fixes incorrect spent totals/counts', style: TextStyle(fontSize: 10)),
              onTap: () async {
                Navigator.pop(sheetContext);
                await invoiceProvider.recalculateCustomerStats(customer.name);
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Statistics recalculated for ${customer.name}')),
                );
              },
            ),
            if (isAdmin) ...[
              const Divider(indent: 72),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                ),
                title: const Text('Delete Customer', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeletion(outerContext, 'Delete Customer?', 'Are you sure you want to delete ${customer.name}?', () async {
                    await invoiceProvider.deleteCustomer(customer.id);
                    return true;
                  }, scaffoldMessenger: scaffoldMessenger);
                },
              ),
            ] else 
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Only Admin can delete customers', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  void _showCustomerInvoicesList(BuildContext context, Customer customer) {
    final outerContext = context;
    final invoiceProvider = context.read<InvoiceProvider>();
    final customerInvoices = invoiceProvider.invoices.where((inv) => inv.clientInfo.name == customer.name).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFEEF2FF),
                    child: const Icon(Icons.person, color: Color(0xFF1E3A8A), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('${customerInvoices.length} Invoices Found', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: customerInvoices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No invoices for this customer', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: customerInvoices.length,
                      itemBuilder: (context, index) {
                        final inv = customerInvoices[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _showInvoiceOptions(outerContext, inv, viewOnly: true);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[100]!),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: inv.type == InvoiceType.receipt ? const Color(0xFFF0FDF4) : const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      inv.type == InvoiceType.receipt ? Icons.check_circle_outline : Icons.description_outlined,
                                      color: inv.type == InvoiceType.receipt ? const Color(0xFF16A34A) : const Color(0xFF1E3A8A),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('#${inv.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        Text(DateFormat('dd MMM yyyy').format(inv.date), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (inv.amountPaid > 0 && inv.amountPaid < inv.total) ...[
                                        Text(
                                          '${context.watch<SettingsProvider>().businessInfo?.currency ?? "₵"}${inv.amountPaid.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFF59E0B)),
                                        ),
                                        Text(
                                          'of ${context.watch<SettingsProvider>().businessInfo?.currency ?? "₵"}${inv.total.toStringAsFixed(2)}',
                                          style: TextStyle(color: Colors.grey[400], fontSize: 9),
                                        ),
                                      ] else ...[
                                        Text(
                                          '${context.watch<SettingsProvider>().businessInfo?.currency ?? "₵"}${inv.total.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E3A8A)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductOptions(BuildContext context, Product product) {
    final invoiceProvider = context.read<InvoiceProvider>();
    final activeStaff = invoiceProvider.activeStaff;
    final isAdmin = activeStaff == null;
    final isManager = activeStaff?.role == 'Manager';
    final canEdit = isAdmin || isManager;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final outerContext = context;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Container(
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
                  Navigator.pop(sheetContext);
                  _viewBarcode(outerContext, product);
                },
              ),
              const Divider(indent: 72),
            ],
            if (canEdit) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A)),
                ),
                title: const Text('Edit Product', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddProductDialog(outerContext, existingProduct: product);
                },
              ),
              if (isAdmin) ...[
                const Divider(indent: 72),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                  ),
                  title: const Text('Delete Product', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDeletion(outerContext, 'Delete Product?', 'Are you sure you want to delete ${product.name}?', () async {
                      await invoiceProvider.deleteProduct(product.id);
                      return true;
                    }, scaffoldMessenger: scaffoldMessenger);
                  },
                ),
              ],
            ] else 
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Only Admin/Manager can edit products', style: TextStyle(color: Colors.grey, fontSize: 12)),
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

    final activeStaff = context.read<InvoiceProvider>().activeStaff;
    final isAdmin = activeStaff == null;
    final isManager = activeStaff?.role == 'Manager';
    final canUseQuickMode = isAdmin || isManager;

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
                        if (canUseQuickMode)
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

  void _confirmDeletion(
    BuildContext context,
    String title,
    String message,
    Future<bool> Function() onConfirm, {
    ScaffoldMessengerState? scaffoldMessenger,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await onConfirm();
              if (!success) {
                scaffoldMessenger?.showSnackBar(
                  const SnackBar(
                    content: Text('Note: Removed locally. Cloud deletion failed or not found on server.'),
                    backgroundColor: Colors.orange,
                  )
                );
              }
            }, 
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showInvoiceOptions(BuildContext context, Invoice inv, {bool viewOnly = false}) {
    final isAdmin = context.read<InvoiceProvider>().activeStaff == null;
    // Cashiers in viewOnly mode can ONLY view/preview — no edit, no delete, no void
    final canEdit = !viewOnly && (isAdmin || inv.isEstimate);
    final canDelete = !viewOnly && isAdmin;
    final canVoid = !viewOnly && !inv.isEstimate;

    // Capture provider and scaffold BEFORE entering the bottom sheet builder
    // to avoid the BuildContext shadowing issue (builder: (context) shadows outer context)
    final invoiceProvider = context.read<InvoiceProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final outerContext = context;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 24),
            physics: const ClampingScrollPhysics(),
            children: [
              Center(
                child: Text(
                  inv.id,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                ),
              ),
              if (viewOnly) ...[  
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('View Only', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
              const SizedBox(height: 24),
              if (canEdit) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A)),
                  ),
                  title: const Text('Edit Document', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Modify items, client info or details'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    invoiceProvider.updateInvoice(inv);
                    Navigator.push(
                      outerContext,
                      MaterialPageRoute(builder: (_) => const InvoiceEditorScreen()),
                    );
                  },
                ),
                const Divider(indent: 72),
              ],
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.visibility_outlined, color: Color(0xFF22C55E)),
                ),
                title: const Text('View / Preview', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('View and share PDF document'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  invoiceProvider.updateInvoice(inv);
                  Navigator.push(
                    outerContext,
                    MaterialPageRoute(builder: (_) => const PdfPreviewScreen()),
                  );
                },
              ),
              if (canVoid) ...[
                const Divider(indent: 72),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.undo, color: Colors.orange),
                  ),
                  title: const Text('Void / Refund', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange)),
                  subtitle: const Text('Cancel this transaction and restore stock'),
                  onTap: () async {
                    if (await _authorizeAdmin(sheetContext)) {
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      _confirmDeletion(outerContext, 'Void Document?', 'This will cancel the sale and restore stock. Continue?', () async {
                        return await invoiceProvider.deleteInvoice(inv.id, restoreStock: true);
                      }, scaffoldMessenger: scaffoldMessenger);
                    }
                  },
                ),
              ],
              if (canDelete) ...[
                const Divider(indent: 72),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                  ),
                  title: const Text('Delete Document', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                  subtitle: const Text('Permanently remove this document'),
                  onTap: () async {
                    if (await _authorizeAdmin(sheetContext)) {
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      _confirmDeletion(outerContext, 'Delete Document?', 'Are you sure you want to delete ${inv.id}?\n\nThis will NOT restore the stock.', () async {
                        return await invoiceProvider.deleteInvoice(inv.id, restoreStock: false);
                      }, scaffoldMessenger: scaffoldMessenger);
                    }
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
}


  Widget _buildInvoiceList(List<Invoice> invoices, {bool viewOnly = false}) {
    if (invoices.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.description_outlined, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            viewOnly ? 'No documents created yet.' : 'No documents yet.',
            style: TextStyle(color: Colors.grey[400]),
          ),
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
        final isPaid = inv.type == InvoiceType.receipt || (inv.amountPaid >= inv.total && inv.total > 0);
        final isPartial = !isPaid && inv.amountPaid > 0;
        final isOverdue = !isPaid && !isPartial && !inv.isEstimate && inv.dueDate != null && inv.dueDate!.isBefore(DateTime.now());

        return GestureDetector(
          onTap: () => _showInvoiceOptions(context, inv, viewOnly: viewOnly),
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
                    color: isPaid ? const Color(0xFFECFDF5) : (isPartial ? const Color(0xFFFFF7ED) : const Color(0xFFEEF2FF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    inv.isEstimate ? Icons.assignment : (inv.type == InvoiceType.receipt ? Icons.receipt_long : Icons.description),
                    color: isPaid ? const Color(0xFF10B981) : (isPartial ? const Color(0xFFF59E0B) : const Color(0xFF1E3A8A)),
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
                          Flexible(
                            child: Text(
                              '#${inv.id}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
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
                          if (!inv.isSynced) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PENDING',
                                style: TextStyle(color: Color(0xFFEF4444), fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
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
                              : (isPartial ? const Color(0xFFFFF7ED) : (isOverdue ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC))),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPaid ? 'PAID' : (isPartial ? 'STILL OWING' : (isOverdue ? 'OVERDUE' : 'UNPAID')),
                          style: TextStyle(
                          color: isPaid ? const Color(0xFF10B981) : (isPartial ? const Color(0xFFF59E0B) : (isOverdue ? const Color(0xFFEF4444) : Colors.grey[600])),
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
                    if (isPartial) ...[
                      Text(
                        '$currency${inv.amountPaid.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFF59E0B)),
                      ),
                      Text(
                        'of $currency${inv.total.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 10),
                      ),
                    ] else ...[
                      Text(
                        '$currency${inv.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E3A8A)),
                      ),
                    ],
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

  Widget _buildAddButton(BuildContext context, String label, IconData icon, {bool noPadding = false, VoidCallback? onTap}) {
    final invoiceProvider = context.read<InvoiceProvider>();
    final isAdmin = invoiceProvider.activeStaff == null;

    final button = ElevatedButton.icon(
      onPressed: () {
        if (onTap != null) {
          // Check for Admin only actions passed via onTap
          if (label == 'Add Expense' && !isAdmin) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only Admin can add expenses')));
            return;
          }
          onTap();
          return;
        }

        if (_activeTab == 1) { // Documents
          invoiceProvider.createNewInvoice();
          Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceEditorScreen()));
        } else if (_activeTab == 2) { // Clients
          _showAddCustomerDialog(context);
        } else if (_activeTab == 3) { // Inventory
          final activeStaff = invoiceProvider.activeStaff;
          final isAdmin = activeStaff == null;
          final isManager = activeStaff?.role == 'Manager';

          if (isAdmin || isManager) {
            _showAddProductDialog(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only Admin/Manager can add products')));
          }
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

  void _showAddExpenseDialog({Expense? existingExpense}) async {
    final expense = await showDialog<Expense>(
      context: context,
      builder: (context) => ExpenseEditorDialog(existingExpense: existingExpense),
    );
    
    if (expense != null && mounted) {
      if (existingExpense != null) {
        context.read<InvoiceProvider>().updateExpense(expense);
      } else {
        context.read<InvoiceProvider>().addExpense(expense);
      }
    }
  }

  Widget _buildExpenseItem(Expense expense) {
    final currency = context.watch<SettingsProvider>().businessInfo?.currency ?? '₵';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[100]!),
      ),
      child: ListTile(
        onTap: () => _showExpenseOptions(expense),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.money_off, color: Colors.orange, size: 20),
        ),
        title: Text(expense.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('${expense.category.name.toUpperCase()} • ${DateFormat('dd MMM').format(expense.date)}', style: const TextStyle(fontSize: 11)),
        trailing: Text('$currency${expense.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
      ),
    );
  }

  void _showExpenseOptions(Expense expense) {
    final invoiceProvider = context.read<InvoiceProvider>();
    final isAdmin = invoiceProvider.activeStaff == null;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final outerContext = context;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 24),
          physics: const ClampingScrollPhysics(),
          children: [
          if (isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Expense'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAddExpenseDialog(existingExpense: expense);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Expense', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDeletion(outerContext, 'Delete Expense?', 'Delete this expense record?', () async {
                  await invoiceProvider.deleteExpense(expense.id);
                  return true;
                }, scaffoldMessenger: scaffoldMessenger);
              },
            ),
          ] else 
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Only Admin can edit or delete expenses', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

  Future<bool> _authorizeAdmin(BuildContext context, {bool force = false}) async {
    final invoiceProvider = context.read<InvoiceProvider>();
    if (invoiceProvider.activeStaff == null && !force) return true; // Already admin and not a forced check

    final passController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin Authorization Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter Admin Password to authorize this action.'),
            const SizedBox(height: 16),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Admin Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final managerPin = context.read<SettingsProvider>().businessInfo?.managerPin ?? '1234';
              if (passController.text == managerPin) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Manager PIN')));
              }
            },
            child: const Text('Authorize'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildDashboard(InvoiceProvider provider, SettingsProvider settings) {
    final currency = settings.businessInfo?.currency ?? '₵';
    final revenueGoal = settings.businessInfo?.revenueGoal ?? 1000.0;
    final activeStaff = provider.activeStaff;
    final isAdmin = activeStaff == null;
    final isManager = activeStaff?.role == 'Manager';
    final progress = (provider.totalSalesRevenue / revenueGoal).clamp(0.0, 1.0);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAdmin) ...[
            _buildRevenueGoalCard(provider.totalSalesRevenue, revenueGoal, currency, progress),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _dashboardStatCard('Revenue', '$currency${provider.totalSalesRevenue.toStringAsFixed(0)}', Icons.payments, Colors.blue)),
                const SizedBox(width: 16),
                Expanded(child: _dashboardStatCard('Net Profit', '$currency${provider.netProfit.toStringAsFixed(0)}', Icons.trending_up, Colors.green)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _dashboardStatCard('Expenses', '$currency${provider.totalExpensesValue.toStringAsFixed(0)}', Icons.money_off, Colors.orange)),
                const SizedBox(width: 16),
                Expanded(child: _dashboardStatCard('Unpaid', '$currency${(provider.totalSalesRevenue - provider.totalPaidAmount).toStringAsFixed(0)}', Icons.timer, Colors.red)),
              ],
            ),
          ] else ...[
            // Safe Cashier Dashboard
            _buildPersonalPerformanceCard(provider, currency),
          ],
          const SizedBox(height: 24),
          if (isAdmin) ...[
            _buildSectionHeader('Revenue Trends', Icons.bar_chart),
            const SizedBox(height: 16),
            _buildRevenueChart(provider, currency),
            const SizedBox(height: 24),
          ],
          if (isAdmin || isManager) ...[
            if (provider.lowStockProducts.isNotEmpty) ...[
              _buildSectionHeader('Low Stock Alerts', Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(height: 16),
              _buildLowStockList(provider.lowStockProducts),
              const SizedBox(height: 24),
            ],
          ],
          // Only admins see business-wide staff/station performance
          if (isAdmin) ...[
            _buildSectionHeader('Staff Performance', Icons.leaderboard_outlined),
            const SizedBox(height: 16),
            _buildStaffPerformance(provider),
            const SizedBox(height: 24),
            _buildSectionHeader('Station Performance', Icons.computer_outlined, color: Colors.purple),
            const SizedBox(height: 16),
            _buildStationPerformance(provider),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildRevenueGoalCard(double current, double goal, String currency, double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF1E3A8A).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly Revenue Goal', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$currency${current.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
            ),
          ),
          const SizedBox(height: 12),
          Text('Goal: $currency${goal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _dashboardStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? const Color(0xFF1E3A8A)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildRevenueChart(InvoiceProvider provider, String currency) {
    final revenueData = provider.getChartData(false, false);
    final profitData = provider.getChartData(true, false);
    final lastRevenueData = provider.getChartData(false, true);

    final List<FlSpot> revenueSpots = revenueData.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList()..sort((a,b) => a.x.compareTo(b.x));
    final List<FlSpot> profitSpots = profitData.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList()..sort((a,b) => a.x.compareTo(b.x));
    final List<FlSpot> lastRevenueSpots = lastRevenueData.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList()..sort((a,b) => a.x.compareTo(b.x));

    if (revenueSpots.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey[100]!)),
        child: const Center(child: Text('Not enough data for chart', style: TextStyle(fontSize: 12, color: Colors.grey))),
      );
    }

    double maxY = 0;
    for (var s in revenueSpots) {
      if (s.y > maxY) maxY = s.y;
    }
    for (var s in lastRevenueSpots) {
      if (s.y > maxY) maxY = s.y;
    }
    
    final yInterval = maxY == 0 ? 100.0 : maxY;
    final chartMaxY = maxY * 1.3;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey[50]!),
      ),
      child: Column(
        children: [
          // Header with Period Selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Analytics Trends', 
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: ChartPeriod.values.map((period) {
                    final isSelected = provider.chartPeriod == period;
                    return GestureDetector(
                      onTap: () => provider.setChartPeriod(period),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1E3A8A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          period == ChartPeriod.daily ? 'Dy' : (period == ChartPeriod.weekly ? 'Wk' : (period == ChartPeriod.monthly ? 'Mo' : 'Yr')),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.grey[600],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            children: [
              _buildLegendItem('Revenue', const Color(0xFF1E3A8A), false),
              const SizedBox(width: 16),
              _buildLegendItem('Profit', Colors.green, false),
              const SizedBox(width: 16),
              _buildLegendItem('Last Period', Colors.grey[300]!, true),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[100]!, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final val = value.toInt();
                        if (provider.chartPeriod == ChartPeriod.daily) {
                          if (val % 4 != 0) return const SizedBox.shrink();
                          return SideTitleWidget(meta: meta, child: Text('${val}h', style: TextStyle(color: Colors.grey[400], fontSize: 9)));
                        }
                        if (provider.chartPeriod == ChartPeriod.yearly) {
                          if (val < 1 || val > 12 || val % 3 != 0) return const SizedBox.shrink();
                          const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          return SideTitleWidget(meta: meta, child: Text(months[val], style: TextStyle(color: Colors.grey[400], fontSize: 9)));
                        }
                        if (val % 5 != 0 && val != 1 && val != revenueSpots.last.x.toInt()) return const SizedBox.shrink();
                        return SideTitleWidget(meta: meta, child: Text(val.toString(), style: TextStyle(color: Colors.grey[400], fontSize: 9)));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: yInterval / 2 > 0 ? yInterval / 2 : 100,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            value >= 1000 ? '${(value/1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
                            style: TextStyle(color: Colors.grey[400], fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                      reservedSize: 32,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: provider.chartPeriod == ChartPeriod.daily ? 0 : 1,
                maxX: provider.chartPeriod == ChartPeriod.daily ? 23 : revenueSpots.last.x,
                minY: 0,
                maxY: chartMaxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => const Color(0xFF1E3A8A).withValues(alpha: 0.9),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isProfitLine = spot.barIndex == 1;
                        final isLastPeriodLine = spot.barIndex == 2;
                        final label = isProfitLine ? 'Profit' : (isLastPeriodLine ? 'Prev' : 'Revenue');
                        return LineTooltipItem(
                          '$label: $currency${spot.y.toStringAsFixed(0)}',
                          const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  // Revenue (Main)
                  LineChartBarData(
                    spots: revenueSpots,
                    isCurved: true,
                    color: const Color(0xFF1E3A8A),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [const Color(0xFF1E3A8A).withValues(alpha: 0.2), const Color(0xFF1E3A8A).withValues(alpha: 0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                  ),
                  // Profit
                  LineChartBarData(
                    spots: profitSpots,
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Last Period (Dotted)
                  LineChartBarData(
                    spots: lastRevenueSpots,
                    isCurved: true,
                    color: Colors.grey[300]!,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dashArray: [5, 5],
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDotted) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: isDotted ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: isDotted 
            ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(width: 4, height: 3, color: color), Container(width: 4, height: 3, color: color)]) 
            : null,
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLowStockList(List<Product> lowStock) {
    return Column(
      children: lowStock.take(3).map((p) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.inventory_2, color: Colors.red, size: 16),
            const SizedBox(width: 12),
            Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)))),
            Text('${p.stockQuantity} left', style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B))),
          ],
        ),
      )).toList(),
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
      // Product doesn't exist, check authorization before opening Add Product dialog
      Future.microtask(() async {
        if (!mounted) return;
        if (await _authorizeAdmin(context)) {
          if (!mounted) return;
          _showAddProductDialog(context, initialBarcode: code);
        }
      });
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
    final costController = TextEditingController(text: existingProduct?.costPrice?.toString());
    final stockController = TextEditingController(text: (existingProduct?.stockQuantity ?? 100).toString());
    final minStockController = TextEditingController(text: (existingProduct?.minStockLevel ?? 10).toString());
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
                      Row(
                        children: [
                          Expanded(
                            child: _buildStyledTextField(
                              controller: priceController,
                              hint: 'Sell Price',
                              icon: Icons.payments_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStyledTextField(
                              controller: costController,
                              hint: 'Cost Price',
                              icon: Icons.shopping_cart_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      _buildInputLabel('STOCK MANAGEMENT'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStyledTextField(
                              controller: stockController,
                              hint: 'Current Stock',
                              icon: Icons.inventory_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStyledTextField(
                              controller: minStockController,
                              hint: 'Min Level',
                              icon: Icons.notifications_active_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      
                      _buildInputLabel('BARCODE (OPTIONAL)'),
                      const SizedBox(height: 8),
                      _buildStyledTextField(
                        controller: barcodeController,
                        hint: 'Scan or enter code',
                        icon: Icons.qr_code_outlined,
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
                                costPrice: double.tryParse(costController.text),
                                stockQuantity: int.tryParse(stockController.text) ?? 0,
                                minStockLevel: int.tryParse(minStockController.text) ?? 0,
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
  Widget _buildStaffPerformance(InvoiceProvider provider) {
    final stats = provider.salesByStaff;
    if (stats.isEmpty) return const SizedBox.shrink();

    final settings = context.watch<SettingsProvider>();
    final currency = settings.businessInfo?.currency ?? '₵';

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
          ...stats.entries.map((entry) {
            final total = stats.values.reduce((a, b) => a + b);
            final progress = total == 0 ? 0.0 : entry.value / total;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      Text(
                        '$currency${entry.value.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      entry.key == 'Admin' ? const Color(0xFF64748B) : const Color(0xFF3B82F6),
                    ),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStationPerformance(InvoiceProvider provider) {
    final stats = provider.salesByStation;
    if (stats.isEmpty) return const SizedBox.shrink();

    final settings = context.watch<SettingsProvider>();
    final currency = settings.businessInfo?.currency ?? '₵';

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
          ...stats.entries.map((entry) {
            final total = stats.values.reduce((a, b) => a + b);
            final progress = total == 0 ? 0.0 : entry.value / total;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.computer, size: 14, color: Color(0xFF475569)),
                          const SizedBox(width: 6),
                          Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                      Text(
                        '$currency${entry.value.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPersonalPerformanceCard(InvoiceProvider provider, String currency) {
    final mySales = provider.invoices.where((i) => i.cashierName == provider.activeStaff?.name);
    final total = mySales.fold(0.0, (sum, i) => sum + i.total);
    final count = mySales.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back, ${provider.activeStaff?.name}!', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          const Text('Your Sales Today', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              _perfStat('Total', '$currency${total.toStringAsFixed(2)}', Icons.payments),
              const SizedBox(width: 24),
              _perfStat('Invoices', '$count', Icons.description),
            ],
          ),
        ],
      ),
    );
  }

  Widget _perfStat(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white60, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTabWrapper(Widget content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          content,
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

