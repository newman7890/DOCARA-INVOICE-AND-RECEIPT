import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../models/invoice.dart';
import '../services/supabase_service.dart';
import '../services/sync_queue_service.dart';
import 'package:uuid/uuid.dart';

class InvoiceProvider with ChangeNotifier {
  InvoiceProvider() {
    _init();
  }
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

  // Track IDs deleted locally so realtime re-merge doesn't re-add them
  final Set<String> _deletedIds = {};

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

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _stationName = prefs.getString('stationName') ?? 'Station 1';
    
    // Load cached data immediately so the app is usable while offline
    await _loadFromCache();
    
    // Then try to refresh from cloud if we have a business ID
    if (_businessId != null) {
      loadFromSupabase();
    }
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Load Staff
    final staffJson = prefs.getString('cached_staff');
    if (staffJson != null) {
      final List<dynamic> decoded = json.decode(staffJson);
      _staff.clear();
      _staff.addAll(decoded.map((item) => Staff.fromMap(item as Map<String, dynamic>)));
    }

    // 2. Load Products
    final productsJson = prefs.getString('cached_products');
    if (productsJson != null) {
      final List<dynamic> decoded = json.decode(productsJson);
      _products.clear();
      _products.addAll(decoded.map((item) => Product.fromMap(item as Map<String, dynamic>)));
    }

    // 3. Load Customers
    final customersJson = prefs.getString('cached_customers');
    if (customersJson != null) {
      final List<dynamic> decoded = json.decode(customersJson);
      _customers.clear();
      _customers.addAll(decoded.map((item) => Customer.fromMap(item as Map<String, dynamic>)));
    }

    // 4. Load active staff
    final activeId = prefs.getString('activeStaffId');
    if (activeId != null) {
      _activeStaff = _staff.cast<Staff?>().firstWhere((s) => s?.id == activeId, orElse: () => null);
    }
    
    // 5. Load Cached Invoices
    final invoicesJson = prefs.getString('cached_invoices');
    if (invoicesJson != null) {
      final List<dynamic> decoded = json.decode(invoicesJson);
      _invoices.clear();
      _invoices.addAll(decoded.map((item) => Invoice.fromMap(item as Map<String, dynamic>)));
    }

    // 6. Merge Offline Queue
    final pendingInvoices = await _syncQueue.getPendingInvoices();
    for (var item in pendingInvoices) {
      try {
        final inv = Invoice.fromMap(item['invoice'] as Map<String, dynamic>);
        if (!_invoices.any((i) => i.id == inv.id)) {
          _invoices.insert(0, inv);
        }
      } catch (e) {
        debugPrint('Error loading offline invoice in cache: $e');
      }
    }

    notifyListeners();
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

      // 1. Process and CACHE Staff
      final fetchedStaff = results[4] as List<Staff>;
      _staff.clear();
      _staff.addAll(fetchedStaff);
      
      // 2. Process and CACHE Products
      final fetchedProducts = results[1] as List<Product>;
      _products.clear();
      _products.addAll(fetchedProducts);

      // 3. Process and CACHE Customers
      final fetchedCustomers = results[2] as List<Customer>;
      _customers.clear();
      _customers.addAll(fetchedCustomers);

      // Save to SharedPreferences for next time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_staff', json.encode(_staff.map((s) => s.toMap()).toList()));
      await prefs.setString('cached_products', json.encode(_products.map((p) => p.toMap()).toList()));
      await prefs.setString('cached_customers', json.encode(_customers.map((c) => c.toMap()).toList()));
      await prefs.setString('cached_invoices', json.encode((results[0] as List<Invoice>).map((i) => i.toMap()).toList()));

      _invoices
        ..clear()
        ..addAll(results[0] as List<Invoice>);
      
      // Merge offline queue items into the UI list
      final pendingInvoices = await _syncQueue.getPendingInvoices();
      for (var item in pendingInvoices) {
        try {
          final inv = Invoice.fromMap(item['invoice'] as Map<String, dynamic>);
          if (!_invoices.any((i) => i.id == inv.id)) {
            _invoices.insert(0, inv);
          }
        } catch (e) {
          debugPrint('Error loading offline invoice: $e');
        }
      }
      
      _expenses
        ..clear()
        ..addAll(results[3] as List<Expense>);
      
      _hasPendingSync = await _syncQueue.hasPendingItems();

      // Ensure active staff is still correct
      final activeId = prefs.getString('activeStaffId');
      if (activeId != null) {
        _activeStaff = _staff.cast<Staff?>().firstWhere((s) => s?.id == activeId, orElse: () => null);
      }
    } catch (e) {
      debugPrint('Error loading from Supabase: $e');
      // Offline fallback: reload from local cache so data isn't empty
      await _loadFromCache();
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

      // Merge offline queue items after realtime update (skip deleted ones)
      final pendingInvoices = await _syncQueue.getPendingInvoices();
      for (var item in pendingInvoices) {
        try {
          final inv = Invoice.fromMap(item['invoice'] as Map<String, dynamic>);
          if (!_deletedIds.contains(inv.id) && !_invoices.any((i) => i.id == inv.id)) {
            _invoices.insert(0, inv);
          }
        } catch (e) {
          debugPrint('Error loading offline invoice from queue: $e');
        }
      }
      notifyListeners();
    });
  }

  void _clearAll() {
    _invoices.clear();
    _expenses.clear();
    // We don't clear _staff, _products, or _customers here 
    // because we want them to remain available for the login screen 
    // and offline use even after a logout. They will be refreshed 
    // from the cloud the next time an Admin logs in.
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
  Future<bool> deleteInvoice(String invoiceId, {bool restoreStock = true}) async {
    final invIndex = _invoices.indexWhere((inv) => inv.id == invoiceId);
    if (invIndex == -1) return false;

    // 1. Mark as deleted so realtime re-merge skips it
    _deletedIds.add(invoiceId);

    final inv = _invoices[invIndex];

    // 1.5 Update customer stats locally
    final ci = _customers.indexWhere((c) => c.name == inv.clientInfo.name);
    if (ci != -1) {
      final updated = _customers[ci].copyWith(
        totalSpent: (_customers[ci].totalSpent - inv.total).clamp(0.0, double.infinity),
        invoiceCount: (_customers[ci].invoiceCount - 1).clamp(0, 999999),
      );
      _customers[ci] = updated;
      if (_businessId != null) {
        try {
          await _service.upsertCustomer(_businessId!, updated);
        } catch (e) {
          debugPrint('Failed to update customer online during deletion: $e');
        }
      }
    }

    // Restore stock ONLY if it was actually reduced AND we want to restore it
    if (inv.stockReduced && restoreStock) {
      for (var item in inv.items) {
        int pi = -1;
        if (item.productId != null) {
          pi = _products.indexWhere((p) => p.id == item.productId);
        }
        if (pi == -1) {
          pi = _products.indexWhere((p) => p.name == item.name);
        }

        if (pi != -1) {
          final updated = _products[pi].copyWith(stockQuantity: _products[pi].stockQuantity + item.quantity);
          _products[pi] = updated;
          if (_businessId != null) {
            try {
              final rpcSuccess = await _service.decrementProductStock(_products[pi].id, -item.quantity);
              if (!rpcSuccess) {
                await _service.updateProductStockOnly(_products[pi].id, _products[pi].stockQuantity);
              }
            } catch (e) {
              debugPrint('Failed to restore stock online: $e');
            }
          }
        }
      }
    }

    // 2. Remove from local list immediately
    _invoices.removeAt(invIndex);
    notifyListeners();

    try {
      // 3. Remove from offline queue FIRST (before Supabase delete)
      //    so the realtime event can't re-add it
      await _syncQueue.removeInvoiceFromQueue(invoiceId);
      _hasPendingSync = await _syncQueue.hasPendingItems();

      // 4. Delete from Supabase
      if (_businessId != null) {
        await _service.deleteInvoice(invoiceId);
      }
      return true;
    } catch (e) {
      debugPrint('Error during deletion sync: $e');
      return false;
    }
  }

  Future<void> saveCurrentInvoice() async {
    if (_currentInvoice == null) return;

    if (_activeStaff != null) {
      _currentInvoice = _currentInvoice!.copyWith(cashierName: _activeStaff!.name);
    }
    _currentInvoice = _currentInvoice!.copyWith(stationName: _stationName);

    // ONLY reduce stock if it's NOT an estimate AND hasn't been reduced yet
    if (!_currentInvoice!.isEstimate && !_currentInvoice!.stockReduced) {
      for (var item in _currentInvoice!.items) {
        int pi = -1;
        if (item.productId != null) {
          pi = _products.indexWhere((p) => p.id == item.productId);
        }
        if (pi == -1) {
          pi = _products.indexWhere((p) => p.name == item.name);
        }

        if (pi != -1) {
          final updated = _products[pi].copyWith(stockQuantity: _products[pi].stockQuantity - item.quantity);
          _products[pi] = updated;
          
          if (_businessId != null) {
            final String pId = _products[pi].id;
            final int pStock = _products[pi].stockQuantity;
            final int qty = item.quantity;
            () async {
              try {
                final rpcSuccess = await _service.decrementProductStock(pId, qty);
                if (!rpcSuccess) {
                  // Fallback to absolute stock update if RPC fails
                  await _service.updateProductStockOnly(pId, pStock);
                }
              } catch (e) {
                debugPrint('Failed to decrement stock online: $e');
              }
            }();
          }
        }
      }
      // Mark as reduced so we don't do it again
      _currentInvoice = _currentInvoice!.copyWith(stockReduced: true);
    }

    // Find if we are editing an existing invoice
    final i = _invoices.indexWhere((inv) => inv.id == _currentInvoice!.id);
    Invoice? oldInvoice;
    if (i != -1) {
      oldInvoice = _invoices[i];
    }

    // Update customer stats (Handle both New and Edit)
    if (oldInvoice != null) {
      // 1. Revert stats for the old customer (in case customer was changed or total was different)
      final oldCi = _customers.indexWhere((c) => c.name == oldInvoice!.clientInfo.name);
      if (oldCi != -1) {
        _customers[oldCi] = _customers[oldCi].copyWith(
          totalSpent: (_customers[oldCi].totalSpent - oldInvoice.total).clamp(0.0, double.infinity),
          invoiceCount: (_customers[oldCi].invoiceCount - 1).clamp(0, 999999),
        );
        if (_businessId != null) {
          final String oldCustId = _customers[oldCi].id;
          final double oldTotal = oldInvoice.total;
          () async {
            try { 
              await _service.incrementCustomerStats(oldCustId, -oldTotal, -1); 
            } catch (e) {
              debugPrint('Failed to revert customer stats: $e');
            }
          }();
        }
      }
    }

    // 2. Apply stats for the current customer
    final ci = _customers.indexWhere((c) => c.name == _currentInvoice!.clientInfo.name);
    if (ci != -1) {
      _customers[ci] = _customers[ci].copyWith(
        totalSpent: _customers[ci].totalSpent + _currentInvoice!.total,
        invoiceCount: _customers[ci].invoiceCount + 1,
      );
      if (_businessId != null) {
        final String currentCustId = _customers[ci].id;
        final double currentTotal = _currentInvoice!.total;
        () async {
          try {
            await _service.incrementCustomerStats(currentCustId, currentTotal, 1);
          } catch (e) {
            debugPrint('Failed to update customer online: $e');
          }
        }();
      }
    }

    if (i != -1) {
      // oldInvoice is already set above
      
      // If editing an invoice that already reduced stock (and still shouldn't be an estimate)
      if (oldInvoice!.stockReduced && !_currentInvoice!.isEstimate) {
        // 1. Revert old items
        for (var item in oldInvoice.items) {
          int pi = _products.indexWhere((p) => p.id == item.productId || p.name == item.name);
          if (pi != -1) {
            _products[pi] = _products[pi].copyWith(stockQuantity: _products[pi].stockQuantity + item.quantity);
            if (_businessId != null) {
              final String pId = _products[pi].id;
              final int pStock = _products[pi].stockQuantity;
              final int qty = -item.quantity;
              () async {
                try {
                  final rpcSuccess = await _service.decrementProductStock(pId, qty);
                  if (!rpcSuccess) {
                    await _service.updateProductStockOnly(pId, pStock);
                  }
                } catch (e) { debugPrint('Offline revert failed: $e'); }
              }();
            }
          }
        }
        // 2. Apply new items
        for (var item in _currentInvoice!.items) {
          int pi = _products.indexWhere((p) => p.id == item.productId || p.name == item.name);
          if (pi != -1) {
            _products[pi] = _products[pi].copyWith(stockQuantity: _products[pi].stockQuantity - item.quantity);
            if (_businessId != null) {
              final String pId = _products[pi].id;
              final int pStock = _products[pi].stockQuantity;
              final int qty = item.quantity;
              () async {
                try {
                  final rpcSuccess = await _service.decrementProductStock(pId, qty);
                  if (!rpcSuccess) {
                    await _service.updateProductStockOnly(pId, pStock);
                  }
                } catch (e) { debugPrint('Offline decrement failed: $e'); }
              }();
            }
          }
        }
      }

      _invoices[i] = _currentInvoice!;
    } else {
      _invoices.insert(0, _currentInvoice!);
    }

    notifyListeners();

    if (_businessId != null) {
      final Invoice invoiceToSave = _currentInvoice!;
      final String bId = _businessId!;
      final String sName = _stationName;
      
      () async {
        try {
          await _service.saveInvoice(bId, invoiceToSave, sName);
        } catch (e) {
          debugPrint('Saving invoice offline: $e');
          await _syncQueue.queueInvoice(invoiceToSave.copyWith(isSynced: false), sName);
          
          // Update local list to show the "pending" version
          final idx = _invoices.indexWhere((inv) => inv.id == invoiceToSave.id);
          if (idx != -1) {
            _invoices[idx] = invoiceToSave.copyWith(isSynced: false);
          }
          _hasPendingSync = true;
          notifyListeners();
        }
      }();
    }
  }

  Future<Map<String, dynamic>> syncOfflineInvoices() async {
    if (_businessId == null) return {'success': 0, 'total': 0};
    
    final pending = await _syncQueue.getPendingInvoices();
    if (pending.isEmpty) return {'success': 0, 'total': 0};

    _isLoading = true;
    notifyListeners();

    int successCount = 0;
    String? lastError;
    
    final List<Invoice> toSync = [];
    final List<String> toRemove = [];

    for (var item in pending) {
      try {
        final invMap = item['invoice'] as Map<String, dynamic>;
        final invoice = Invoice.fromMap(invMap);
        toSync.add(invoice.copyWith(isSynced: true));
        toRemove.add(invoice.id);
      } catch (e) {
        debugPrint('Parsing error during sync: $e');
      }
    }

    if (toSync.isNotEmpty) {
      try {
        await _service.saveInvoicesBatch(_businessId!, toSync, _stationName);
        
        for (var invoice in toSync) {
          // Still need to handle stock for each
          if (invoice.stockReduced) {
            for (var invItem in invoice.items) {
              String? pId = invItem.productId;
              if (pId == null) {
                final pIndex = _products.indexWhere((p) => p.name == invItem.name);
                if (pIndex != -1) pId = _products[pIndex].id;
              }
              if (pId != null) {
                try {
                  final rpcSuccess = await _service.decrementProductStock(pId, invItem.quantity);
                  if (!rpcSuccess) {
                    final pIdx = _products.indexWhere((p) => p.id == pId);
                    if (pIdx != -1) {
                      await _service.updateProductStockOnly(pId, _products[pIdx].stockQuantity);
                    }
                  }
                } catch (e) {
                  debugPrint('Stock sync error during batch: $e');
                }
              }
            }
          }
          
          // Handle stats for offline invoices during sync
          // We need to find the customer ID from our local list to update them on the cloud
          final cIdx = _customers.indexWhere((c) => c.name == invoice.clientInfo.name);
          if (cIdx != -1) {
            try {
              await _service.incrementCustomerStats(_customers[cIdx].id, invoice.total, 1);
            } catch (e) {
              debugPrint('Stats sync error during batch for ${invoice.id}: $e');
              // We don't block the invoice sync if stats fail, 
              // but we've logged it for monitoring.
            }
          }
          
          await _syncQueue.removeInvoiceFromQueue(invoice.id);
          final idx = _invoices.indexWhere((inv) => inv.id == invoice.id);
          if (idx != -1) {
            _invoices[idx] = _invoices[idx].copyWith(isSynced: true);
          }
          successCount++;
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('Batch sync failed: $e');
      }
    }

    _hasPendingSync = await _syncQueue.hasPendingItems();
    _isLoading = false;
    notifyListeners();
    
    return {
      'success': successCount, 
      'total': pending.length,
      'error': lastError,
    };
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
    // Match by productId if available, otherwise by name
    final ei = items.indexWhere((i) => 
      (item.productId != null && i.productId == item.productId) || 
      (item.productId == null && i.name == item.name && i.sellingPrice == item.sellingPrice)
    );
    if (ei != -1) {
      items[ei] = items[ei].copyWith(quantity: items[ei].quantity + item.quantity);
    } else {
      items.add(item);
    }
    _currentInvoice = _copyInvoice(items: items);
    notifyListeners();
  }

  void updateItemQuantity(int index, int newQuantity) {
    if (_currentInvoice == null || index < 0 || index >= _currentInvoice!.items.length) return;
    if (newQuantity <= 0) {
      removeItem(index);
      return;
    }
    final items = List<InvoiceItem>.from(_currentInvoice!.items);
    items[index] = items[index].copyWith(quantity: newQuantity);
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
  ChartPeriod _chartPeriod = ChartPeriod.monthly;
  ChartPeriod get chartPeriod => _chartPeriod;

  void setChartPeriod(ChartPeriod period) {
    _chartPeriod = period;
    notifyListeners();
  }

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

  Map<DateTime, double> get dailyProfit {
    final Map<DateTime, double> data = {};
    for (var inv in _invoices.where((i) => !i.isEstimate)) {
      final d = DateTime(inv.date.year, inv.date.month, inv.date.day);
      double profit = inv.total;
      for (var item in inv.items) {
        profit -= (item.costPrice ?? 0) * item.quantity;
      }
      data[d] = (data[d] ?? 0) + profit;
    }
    return data;
  }

  // --- Multi-Period Chart Data ---

  Map<int, double> getChartData(bool isProfit, bool isLastPeriod) {
    final now = DateTime.now();
    DateTime start;
    DateTime lastStart;
    int itemsCount;

    switch (_chartPeriod) {
      case ChartPeriod.daily:
        start = DateTime(now.year, now.month, now.day);
        lastStart = start.subtract(const Duration(days: 1));
        itemsCount = 24;
        break;
      case ChartPeriod.weekly:
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        lastStart = start.subtract(const Duration(days: 7));
        itemsCount = 7;
        break;
      case ChartPeriod.monthly:
        start = DateTime(now.year, now.month, 1);
        lastStart = DateTime(now.year, now.month - 1, 1);
        itemsCount = DateTime(now.year, now.month + 1, 0).day;
        break;
      case ChartPeriod.yearly:
        start = DateTime(now.year, 1, 1);
        lastStart = DateTime(now.year - 1, 1, 1);
        itemsCount = 12;
        break;
    }

    final targetStart = isLastPeriod ? lastStart : start;
    final Map<int, double> result = {};

    for (var inv in _invoices.where((i) => !i.isEstimate)) {
      bool inRange = false;
      int key = 0;

      if (_chartPeriod == ChartPeriod.yearly) {
        if (inv.date.year == targetStart.year) {
          inRange = true;
          key = inv.date.month;
        }
      } else if (_chartPeriod == ChartPeriod.monthly) {
        if (inv.date.year == targetStart.year && inv.date.month == targetStart.month) {
          inRange = true;
          key = inv.date.day;
        }
      } else if (_chartPeriod == ChartPeriod.weekly) {
        final diff = inv.date.difference(targetStart).inDays;
        if (diff >= 0 && diff < 7) {
          inRange = true;
          key = diff + 1;
        }
      } else if (_chartPeriod == ChartPeriod.daily) {
        if (inv.date.year == targetStart.year && inv.date.month == targetStart.month && inv.date.day == targetStart.day) {
          inRange = true;
          key = inv.date.hour;
        }
      }

      if (inRange) {
        double val = inv.total;
        if (isProfit) {
          for (var item in inv.items) {
            val -= (item.costPrice ?? 0) * item.quantity;
          }
        }
        result[key] = (result[key] ?? 0) + val;
      }
    }

    // Fill missing keys with 0
    final startKey = (_chartPeriod == ChartPeriod.daily) ? 0 : 1;
    final endKey = (_chartPeriod == ChartPeriod.daily) ? 23 : itemsCount;
    for (int i = startKey; i <= endKey; i++) {
      result[i] ??= 0;
    }

    return result;
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

  Future<void> recalculateCustomerStats(String customerName) async {
    final ci = _customers.indexWhere((c) => c.name == customerName);
    if (ci == -1) return;

    // 1. Filter all non-estimate invoices for this customer
    final customerInvoices = _invoices.where((inv) => inv.clientInfo.name == customerName && !inv.isEstimate).toList();
    
    // 2. Calculate actual totals
    double totalSpent = 0.0;
    for (var inv in customerInvoices) {
      totalSpent += inv.total;
    }
    
    // 3. Update customer locally
    final updated = _customers[ci].copyWith(
      totalSpent: totalSpent,
      invoiceCount: customerInvoices.length,
    );
    _customers[ci] = updated;
    notifyListeners();

    // 4. Sync to cloud
    if (_businessId != null) {
      try {
        await _service.upsertCustomer(_businessId!, updated);
      } catch (e) {
        debugPrint('Failed to sync recalculated customer: $e');
      }
    }
  }
}
