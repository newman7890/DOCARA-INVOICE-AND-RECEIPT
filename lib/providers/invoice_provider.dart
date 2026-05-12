import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../models/invoice.dart';
import '../services/supabase_service.dart';
import '../services/sync_queue_service.dart';
import 'package:uuid/uuid.dart';

class InvoiceProvider with ChangeNotifier {
  Invoice? _currentInvoice;
  final List<Customer> _customers = [];
  final List<Product> _products = [];
  final List<Invoice> _invoices = [];
  final List<Expense> _expenses = [];
  final List<Staff> _staff = [];
  Staff? _activeStaff;
  bool _isLoading = false;
  String? _businessId;
  String _stationName = 'Station 1';
  RealtimeChannel? _realtimeChannel;

  final _service = SupabaseService();
  final _syncQueue = SyncQueueService();
  bool _hasPendingSync = false;
  bool get hasPendingSync => _hasPendingSync;

  Invoice? get currentInvoice => _currentInvoice;
  List<Customer> get customers => _customers;
  List<Product> get products => _products;
  List<Invoice> get invoices => _invoices;
  List<Expense> get expenses => _expenses;
  List<Staff> get staff => _staff;
  Staff? get activeStaff => _activeStaff;
  bool get isLoading => _isLoading;
  String? get businessId => _businessId;

  // Called by main.dart via ProxyProvider whenever AuthProvider changes
  void updateBusinessConfig(String? businessId, String stationName) {
    final changed = _businessId != businessId || _stationName != stationName;
    _businessId = businessId;
    _stationName = stationName;
    if (changed && businessId != null) {
      loadFromSupabase();
      _subscribeRealtime();
    } else if (businessId == null) {
      _clearAll();
    }
  }

  Future<void> loadFromSupabase() async {
    if (_businessId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.getInvoices(_businessId!),
        _service.getProducts(_businessId!),
        _service.getCustomers(_businessId!),
        _service.getExpenses(_businessId!),
        _service.getStaff(_businessId!),
      ]);
      _invoices
        ..clear()
        ..addAll(results[0] as List<Invoice>);
      _products
        ..clear()
        ..addAll(results[1] as List<Product>);
      _customers
        ..clear()
        ..addAll(results[2] as List<Customer>);
      _expenses
        ..clear()
        ..addAll(results[3] as List<Expense>);
      _staff.clear();
      _staff.addAll(results[4] as List<Staff>);
      
      _hasPendingSync = await _syncQueue.hasPendingItems();

      // Restore active staff from local prefs
      final prefs = await SharedPreferences.getInstance();
      final activeId = prefs.getString('activeStaffId');
      if (activeId != null) {
        _activeStaff = _staff.cast<Staff?>().firstWhere((s) => s?.id == activeId, orElse: () => null);
      } else {
        _activeStaff = null;
      }
    } catch (e) {
      debugPrint('Error loading from Supabase: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  void _subscribeRealtime() {
    _realtimeChannel?.unsubscribe();
    if (_businessId == null) return;
    _realtimeChannel = _service.subscribeToInvoices(_businessId!, () async {
      if (_businessId == null) return;
      final updated = await _service.getInvoices(_businessId!);
      _invoices
        ..clear()
        ..addAll(updated);
      notifyListeners();
    });
  }

  void _clearAll() {
    _invoices.clear();
    _products.clear();
    _customers.clear();
    _expenses.clear();
    _staff.clear();
    _activeStaff = null;
    _currentInvoice = null;
    notifyListeners();
  }

  // ─── Customer Methods ──────────────────────────────────────
  Future<void> addCustomer(Customer customer) async {
    _customers.add(customer);
    notifyListeners();
    if (_businessId != null) await _service.upsertCustomer(_businessId!, customer);
  }

  Future<void> updateCustomer(Customer customer) async {
    final i = _customers.indexWhere((c) => c.id == customer.id);
    if (i != -1) {
      _customers[i] = customer;
      notifyListeners();
      if (_businessId != null) await _service.upsertCustomer(_businessId!, customer);
    }
  }

  Future<void> deleteCustomer(String id) async {
    _customers.removeWhere((c) => c.id == id);
    notifyListeners();
    await _service.deleteCustomer(id);
  }

  // ─── Product Methods ───────────────────────────────────────
  Future<void> addProduct(Product product) async {
    _products.add(product);
    notifyListeners();
    if (_businessId != null) await _service.upsertProduct(_businessId!, product);
  }

  Future<void> updateProduct(Product product) async {
    final i = _products.indexWhere((p) => p.id == product.id);
    if (i != -1) {
      _products[i] = product;
      notifyListeners();
      if (_businessId != null) await _service.upsertProduct(_businessId!, product);
    }
  }

  Future<void> deleteProduct(String id) async {
    _products.removeWhere((p) => p.id == id);
    notifyListeners();
    await _service.deleteProduct(id);
  }

  // ─── Expense Methods ───────────────────────────────────────
  Future<void> addExpense(Expense expense) async {
    _expenses.insert(0, expense);
    notifyListeners();
    if (_businessId != null) await _service.saveExpense(_businessId!, expense);
  }

  String generateUniqueId() => const Uuid().v4();

  Future<void> updateExpense(Expense expense) async {
    final i = _expenses.indexWhere((e) => e.id == expense.id);
    if (i != -1) {
      _expenses[i] = expense;
      notifyListeners();
      if (_businessId != null) await _service.saveExpense(_businessId!, expense);
    }
  }

  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    await _service.deleteExpense(id);
  }

  // ─── Staff Methods ─────────────────────────────────────────
  Future<void> addStaff(Staff s) async {
    _staff.add(s);
    notifyListeners();
    if (_businessId != null) await _service.addStaff(_businessId!, s);
  }

  Future<void> updateStaff(Staff s) async {
    final index = _staff.indexWhere((staff) => staff.id == s.id);
    if (index != -1) {
      _staff[index] = s;
      if (_activeStaff?.id == s.id) _activeStaff = s;
      notifyListeners();
      await _service.updateStaff(s);
    }
  }


  Future<void> deleteStaff(String id) async {
    _staff.removeWhere((s) => s.id == id);
    if (_activeStaff?.id == id) _activeStaff = null;
    notifyListeners();
    await _service.deleteStaff(id);
  }

  Future<void> setActiveStaff(Staff? s) async {
    _activeStaff = s;
    final prefs = await SharedPreferences.getInstance();
    if (s != null) {
      await prefs.setString('activeStaffId', s.id);
    } else {
      await prefs.remove('activeStaffId');
    }
    notifyListeners();
  }

  // ─── Invoice Methods ───────────────────────────────────────
  Future<void> deleteInvoice(String invoiceId) async {
    final invIndex = _invoices.indexWhere((inv) => inv.id == invoiceId);
    if (invIndex != -1) {
      final inv = _invoices[invIndex];
      // Restore stock if it was a real sale
      if (!inv.isEstimate) {
        for (var item in inv.items) {
          final pi = _products.indexWhere((p) => p.name == item.name);
          if (pi != -1) {
            final updated = _products[pi].copyWith(stockQuantity: _products[pi].stockQuantity + item.quantity);
            _products[pi] = updated;
            if (_businessId != null) {
              try {
                // Atomic increment (decrement negative)
                await _service.decrementProductStock(_products[pi].id, -item.quantity);
              } catch (e) {
                debugPrint('Failed to restore stock online: $e');
              }
            }
          }
        }
      }
      _invoices.removeAt(invIndex);
      notifyListeners();
      await _service.deleteInvoice(invoiceId);
    }
  }

  Future<void> saveCurrentInvoice() async {
    if (_currentInvoice == null) return;

    if (_activeStaff != null) {
      _currentInvoice = _currentInvoice!.copyWith(cashierName: _activeStaff!.name);
    }
    _currentInvoice = _currentInvoice!.copyWith(stationName: _stationName);

    // Update stock locally and attempt atomic decrement
    for (var item in _currentInvoice!.items) {
      final pi = _products.indexWhere((p) => p.name == item.name);
      if (pi != -1) {
        final updated = _products[pi].copyWith(stockQuantity: _products[pi].stockQuantity - item.quantity);
        _products[pi] = updated;
        
        if (_businessId != null) {
          try {
            await _service.decrementProductStock(_products[pi].id, item.quantity);
          } catch (e) {
            debugPrint('Failed to decrement stock online: $e');
            // We still update locally, but we might want to queue this too if it's critical
          }
        }
      }
    }

    // Update customer stats locally
    final ci = _customers.indexWhere((c) => c.name == _currentInvoice!.clientInfo.name);
    if (ci != -1) {
      final updated = _customers[ci].copyWith(
        totalSpent: _customers[ci].totalSpent + _currentInvoice!.total,
        invoiceCount: _customers[ci].invoiceCount + 1,
      );
      _customers[ci] = updated;
      if (_businessId != null) {
        try {
          await _service.upsertCustomer(_businessId!, updated);
        } catch (e) {
          debugPrint('Failed to update customer online: $e');
        }
      }
    }

    final i = _invoices.indexWhere((inv) => inv.id == _currentInvoice!.id);
    if (i != -1) {
      _invoices[i] = _currentInvoice!;
    } else {
      _invoices.insert(0, _currentInvoice!);
    }

    notifyListeners();

    if (_businessId != null) {
      try {
        await _service.saveInvoice(_businessId!, _currentInvoice!, _stationName);
      } catch (e) {
        debugPrint('Saving invoice offline: $e');
        await _syncQueue.queueInvoice(_currentInvoice!, _stationName);
        _hasPendingSync = true;
        notifyListeners();
      }
    }
  }

  Future<void> syncOfflineInvoices() async {
    if (_businessId == null) return;
    
    final pending = await _syncQueue.getPendingInvoices();
    if (pending.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    for (var item in pending) {
      try {
        final invMap = item['invoice'] as Map<String, dynamic>;
        final sName = item['stationName'] as String;
        final invoice = Invoice.fromMap(invMap);
        
        await _service.saveInvoice(_businessId!, invoice, sName);
        await _syncQueue.removeInvoiceFromQueue(invoice.id);
      } catch (e) {
        debugPrint('Failed to sync invoice ${item['invoice']['id']}: $e');
      }
    }

    _hasPendingSync = await _syncQueue.hasPendingItems();
    _isLoading = false;
    notifyListeners();
  }

  void createNewInvoice({bool isEstimate = false, bool isPos = false}) {
    // Generate a human-readable ID with station prefix to prevent sync collisions
    // Format: S1-1715241234 (StationPrefix-TimestampSuffix)
    final stationPrefix = _stationName.split(' ').map((e) => e[0]).join().toUpperCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    final uniqueId = '$stationPrefix$timestamp';

    _currentInvoice = Invoice(
      id: uniqueId,
      date: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 7)),
      type: InvoiceType.invoice,
      clientInfo: ClientInfo(name: '', address: '', contact: ''),
      items: [],
      discountValue: 0.0,
      discountType: DiscountType.fixed,
      paymentMethod: PaymentMethod.cash,
      isEstimate: isEstimate,
      isPos: isPos,
    );
    notifyListeners();
  }

  void updateInvoice(Invoice invoice) {
    _currentInvoice = invoice;
    notifyListeners();
  }

  void toggleType() {
    if (_currentInvoice == null) return;
    _currentInvoice = _currentInvoice!.copyWith(
      type: _currentInvoice!.type == InvoiceType.invoice ? InvoiceType.receipt : InvoiceType.invoice,
    );
    notifyListeners();
  }

  void addItem(InvoiceItem item) {
    if (_currentInvoice == null) return;
    final items = List<InvoiceItem>.from(_currentInvoice!.items);
    final ei = items.indexWhere((i) => i.name == item.name && i.sellingPrice == item.sellingPrice);
    if (ei != -1) {
      items[ei] = items[ei].copyWith(quantity: items[ei].quantity + item.quantity);
    } else {
      items.add(item);
    }
    _currentInvoice = _copyInvoice(items: items);
    notifyListeners();
  }

  void removeItem(int index) {
    if (_currentInvoice == null) return;
    final items = List<InvoiceItem>.from(_currentInvoice!.items)..removeAt(index);
    _currentInvoice = _copyInvoice(items: items);
    notifyListeners();
  }

  void updateClientInfo(ClientInfo info) {
    if (_currentInvoice == null) return;
    _currentInvoice = _copyInvoice(clientInfo: info);
    notifyListeners();
  }

  void updateDiscount(double value, DiscountType type) {
    if (_currentInvoice == null) return;
    _currentInvoice = _copyInvoice(discountValue: value, discountType: type);
    notifyListeners();
  }

  void updateTax(double value) {
    if (_currentInvoice == null) return;
    _currentInvoice = _copyInvoice(taxValue: value);
    notifyListeners();
  }

  void updateAmountPaid(double value) {
    if (_currentInvoice == null) return;
    _currentInvoice = _copyInvoice(amountPaid: value);
    notifyListeners();
  }

  void updatePaymentMethod(PaymentMethod method) {
    if (_currentInvoice == null) return;
    _currentInvoice = _copyInvoice(paymentMethod: method);
    notifyListeners();
  }

  void updateCashierName(String name) {
    if (_currentInvoice == null) return;
    _currentInvoice = _copyInvoice(cashierName: name);
    notifyListeners();
  }

  void updateWatermark({String? path, double? opacity, double? rotation}) {
    if (_currentInvoice == null) return;
    _currentInvoice = _copyInvoice(
      watermarkPath: path ?? _currentInvoice!.watermarkPath,
      watermarkOpacity: opacity ?? _currentInvoice!.watermarkOpacity,
      watermarkRotation: rotation ?? _currentInvoice!.watermarkRotation,
    );
    notifyListeners();
  }

  Invoice _copyInvoice({
    String? id, DateTime? date, DateTime? dueDate, InvoiceType? type,
    ClientInfo? clientInfo, List<InvoiceItem>? items, double? discountValue,
    DiscountType? discountType, double? taxValue, double? amountPaid,
    PaymentMethod? paymentMethod, String? watermarkPath, double? watermarkOpacity,
    double? watermarkRotation, bool? isEstimate, bool? isPos, String? cashierName,
  }) {
    return _currentInvoice!.copyWith(
      id: id, date: date, dueDate: dueDate, type: type, clientInfo: clientInfo,
      items: items, discountValue: discountValue, discountType: discountType,
      taxValue: taxValue, amountPaid: amountPaid, paymentMethod: paymentMethod,
      watermarkPath: watermarkPath, watermarkOpacity: watermarkOpacity,
      watermarkRotation: watermarkRotation, isEstimate: isEstimate, isPos: isPos,
      cashierName: cashierName,
    );
  }

  // ─── Analytics ─────────────────────────────────────────────
  double get totalSalesRevenue =>
      _invoices.where((i) => !i.isEstimate).fold(0, (s, i) => s + i.total);

  double get totalCOGS {
    double cogs = 0;
    for (var inv in _invoices.where((i) => !i.isEstimate)) {
      for (var item in inv.items) {
        cogs += (item.costPrice ?? 0) * item.quantity;
      }
    }
    return cogs;
  }

  double get totalExpensesValue => _expenses.fold(0, (s, e) => s + e.amount);
  
  double get totalPaidAmount {
    return _invoices.where((i) => !i.isEstimate).fold(0.0, (s, i) {
      if (i.type == InvoiceType.receipt) return s + i.total;
      return s + i.amountPaid;
    });
  }
  
  double get netProfit => totalSalesRevenue - totalCOGS - totalExpensesValue;

  Map<DateTime, double> get dailyRevenue {
    final Map<DateTime, double> data = {};
    for (var inv in _invoices.where((i) => !i.isEstimate)) {
      final d = DateTime(inv.date.year, inv.date.month, inv.date.day);
      data[d] = (data[d] ?? 0) + inv.total;
    }
    return data;
  }

  List<Product> get lowStockProducts =>
      _products.where((p) => p.stockQuantity <= p.minStockLevel).toList();

  Map<String, double> get salesByStaff {
    final Map<String, double> stats = {};
    for (var inv in _invoices.where((i) => !i.isEstimate)) {
      final name = inv.cashierName ?? 'Admin';
      stats[name] = (stats[name] ?? 0) + inv.total;
    }
    return stats;
  }

  Map<String, double> get salesByStation {
    final Map<String, double> stats = {};
    for (var inv in _invoices.where((i) => !i.isEstimate)) {
      final station = inv.stationName ?? 'Unknown Station';
      stats[station] = (stats[station] ?? 0) + inv.total;
    }
    return stats;
  }

  void loadFromBackup(Map<String, dynamic> data) {
    if (data['customers'] != null) {
      _customers.clear();
      _customers.addAll((data['customers'] as List).map((x) => Customer.fromMap(x)));
    }
    if (data['products'] != null) {
      _products.clear();
      _products.addAll((data['products'] as List).map((x) => Product.fromMap(x)));
    }
    if (data['invoices'] != null) {
      _invoices.clear();
      _invoices.addAll((data['invoices'] as List).map((x) => Invoice.fromMap(x)));
    }
    notifyListeners();
  }
}
