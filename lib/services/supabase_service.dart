import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _sb => Supabase.instance.client;

  // ─── Auth ───────────────────────────────────────────────
  User? get currentUser => _sb.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Future<AuthResponse> signIn(String email, String password) =>
      _sb.auth.signInWithPassword(email: email, password: password);

  Future<AuthResponse> signUp(String email, String password) =>
      _sb.auth.signUp(email: email, password: password);

  Future<void> resetPassword(String email) =>
      _sb.auth.resetPasswordForEmail(email, redirectTo: 'io.supabase.docara://reset-password');

  Future<void> signOut() => _sb.auth.signOut();

  Future<void> updatePassword(String newPassword) =>
      _sb.auth.updateUser(UserAttributes(password: newPassword));

  Stream<AuthState> get authStateChanges => _sb.auth.onAuthStateChange;

  // ─── App Metadata ───────────────────────────────────────
  Future<Map<String, dynamic>?> getLatestVersion() async {
    try {
      final response = await _sb
          .from('app_metadata')
          .select('value, download_url')
          .eq('key', 'latest_version')
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching version: $e');
      return null;
    }
  }

  // ─── Business ───────────────────────────────────────────
  Future<String?> getBusinessId() async {
    if (currentUser == null) return null;
    final res = await _sb
        .from('businesses')
        .select('id')
        .eq('owner_id', currentUser!.id)
        .maybeSingle();
    return res?['id'] as String?;
  }

  Future<String> createBusiness(String name) async {
    final res = await _sb
        .from('businesses')
        .insert({'name': name, 'owner_id': currentUser!.id})
        .select('id')
        .single();
    return res['id'] as String;
  }

  Future<BusinessInfo?> getFullBusinessInfo(String businessId) async {
    final res = await _sb
        .from('businesses')
        .select('name, email, phone, address, logo_url, signature_url, revenue_goal, currency')
        .eq('id', businessId)
        .maybeSingle();
    
    if (res == null) return null;

    return BusinessInfo(
      name: res['name'] ?? '',
      email: res['email'] ?? '',
      phone: res['phone'] ?? '',
      address: res['address'] ?? '',
      logoPath: res['logo_url'],
      signaturePath: res['signature_url'],
      revenueGoal: (res['revenue_goal'] ?? 0.0).toDouble(),
      currency: res['currency'] ?? '₵',
      // The following fields are not synced to avoid schema mismatch
      terms: 'Payment is due within 30 days.',
      pdfTermsLabel: 'Terms & Conditions',
      pdfSignatureLabel: 'Authorized Signature',
      pdfTemplate: PdfTemplate.sidebar,
      managerPin: '1234',
    );
  }

  Future<void> updateBusinessInfo(String businessId, BusinessInfo info) async {
    // Only include columns we are CERTAIN exist in the DB schema
    final Map<String, dynamic> data = {
      'name': info.name,
      'email': info.email,
      'phone': info.phone,
      'address': info.address,
      'revenue_goal': info.revenueGoal,
      'currency': info.currency,
    };

    // Note: logo_url and signature_url are handled separately via upload
    if (info.logoPath != null && (info.logoPath!.startsWith('http') || info.logoPath!.isEmpty)) {
       data['logo_url'] = info.logoPath;
    }
    if (info.signaturePath != null && (info.signaturePath!.startsWith('http') || info.signaturePath!.isEmpty)) {
       data['signature_url'] = info.signaturePath;
    }

    // Attempt to update. If it fails, it might be due to missing columns in an old schema.
    // We could try to update fields one by one, but for now we just stick to the basics.
    await _sb.from('businesses').update(data).eq('id', businessId);
  }

  Future<String?> uploadBusinessAsset(String businessId, String localPath, String fileName) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;

      final path = '$businessId/$fileName';
      
      // Upload with upsert
      await _sb.storage.from('business_assets').upload(
        path,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      // Get public URL
      return _sb.storage.from('business_assets').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  // ─── Staff ──────────────────────────────────────────────
  Future<List<Staff>> getStaff(String businessId) async {
    final res = await _sb.from('staff').select().eq('business_id', businessId);
    return (res as List).map((e) => Staff(
      id: e['id'],
      name: e['name'],
      role: e['role'] ?? 'Cashier',
      phone: e['phone'],
      pin: e['pin'],
    )).toList();
  }

  Future<void> addStaff(String businessId, Staff staff) async {
    await _sb.from('staff').insert({
      'id': staff.id,
      'business_id': businessId,
      'name': staff.name,
      'role': staff.role,
      'phone': staff.phone,
      'pin': staff.pin,
    });
  }

  Future<void> updateStaff(Staff staff) async {
    await _sb.from('staff').update({
      'name': staff.name,
      'role': staff.role,
      'phone': staff.phone,
      'pin': staff.pin,
    }).eq('id', staff.id);
  }


  Future<void> deleteStaff(String staffId) async {
    await _sb.from('staff').delete().eq('id', staffId);
  }

  // ─── Products ───────────────────────────────────────────
  Future<List<Product>> getProducts(String businessId) async {
    final res = await _sb.from('products').select().eq('business_id', businessId);
    return (res as List).map((e) => Product(
      id: e['id'],
      name: e['name'],
      price: (e['price'] as num).toDouble(),
      costPrice: e['cost_price'] != null ? (e['cost_price'] as num).toDouble() : null,
      description: e['description'],
      barcode: e['barcode'],
      stockQuantity: e['stock_quantity'] ?? 0,
      minStockLevel: e['min_stock_level'] ?? 5,
    )).toList();
  }

  Future<void> upsertProduct(String businessId, Product product) async {
    await _sb.from('products').upsert({
      'id': product.id,
      'business_id': businessId,
      'name': product.name,
      'price': product.price,
      'cost_price': product.costPrice,
      'description': product.description,
      'barcode': product.barcode,
      'stock_quantity': product.stockQuantity,
      'min_stock_level': product.minStockLevel,
    });
  }

  Future<bool> decrementProductStock(String productId, int quantity) async {
    try {
      await _sb.rpc('decrement_product_stock', params: {
        'p_id': productId,
        'p_quantity': quantity,
      });
      return true;
    } catch (e) {
      debugPrint('RPC decrement failed: $e');
      return false;
    }
  }

  Future<void> updateProductStockOnly(String productId, int newQuantity) async {
    await _sb.from('products').update({
      'stock_quantity': newQuantity,
    }).eq('id', productId);
  }


  Future<void> deleteProduct(String productId) async {
    await _sb.from('products').delete().eq('id', productId);
  }

  // ─── Customers ──────────────────────────────────────────
  Future<List<Customer>> getCustomers(String businessId) async {
    final res = await _sb.from('customers').select().eq('business_id', businessId);
    return (res as List).map((e) => Customer(
      id: e['id'],
      name: e['name'],
      address: e['address'] ?? '',
      contact: e['contact'] ?? '',
      totalSpent: (e['total_spent'] as num?)?.toDouble() ?? 0.0,
      invoiceCount: e['invoice_count'] ?? 0,
    )).toList();
  }

  Future<void> upsertCustomer(String businessId, Customer customer) async {
    await _sb.from('customers').upsert({
      'id': customer.id,
      'business_id': businessId,
      'name': customer.name,
      'address': customer.address,
      'contact': customer.contact,
      'total_spent': customer.totalSpent,
      'invoice_count': customer.invoiceCount,
    });
  }

  Future<void> deleteCustomer(String customerId) async {
    await _sb.from('customers').delete().eq('id', customerId);
  }

  Future<bool> incrementCustomerStats(String customerId, double amount, int count) async {
    try {
      await _sb.rpc('increment_customer_stats', params: {
        'c_id': customerId,
        'p_amount': amount,
        'p_count': count,
      });
      return true;
    } catch (e) {
      debugPrint('Customer stats RPC failed: $e');
      return false;
    }
  }

  // ─── Invoices ───────────────────────────────────────────
  Future<List<Invoice>> getInvoices(String businessId) async {
    final res = await _sb
        .from('invoices')
        .select('*, invoice_items(*)')
        .eq('business_id', businessId)
        .order('date', ascending: false);
    return (res as List).map((e) => _invoiceFromMap(e as Map<String, dynamic>)).toList();
  }

  Invoice _invoiceFromMap(Map<String, dynamic> e) {
    final items = (e['invoice_items'] as List? ?? []).map((item) => InvoiceItem(
      name: item['name'],
      quantity: item['quantity'],
      sellingPrice: (item['selling_price'] as num).toDouble(),
      costPrice: item['cost_price'] != null ? (item['cost_price'] as num).toDouble() : null,
      productId: item['product_id'],
    )).toList();

    return Invoice(
      id: e['id'],
      date: DateTime.parse(e['date']),
      dueDate: e['due_date'] != null ? DateTime.parse(e['due_date']) : null,
      type: e['type'] == 'receipt' ? InvoiceType.receipt : InvoiceType.invoice,
      clientInfo: ClientInfo(
        name: e['client_name'] ?? '',
        address: e['client_address'] ?? '',
        contact: e['client_contact'] ?? '',
      ),
      items: items,
      discountValue: (e['discount_value'] as num?)?.toDouble() ?? 0.0,
      discountType: e['discount_type'] == 'percentage' ? DiscountType.percentage : DiscountType.fixed,
      taxValue: (e['tax_value'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (e['amount_paid'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: _parsePaymentMethod(e['payment_method']),
      isEstimate: e['is_estimate'] ?? false,
      isPos: e['is_pos'] ?? false,
      cashierName: e['cashier_name'],
      stationName: e['station_name'],
      stockReduced: e['stock_reduced'] ?? false,
    );
  }

  PaymentMethod _parsePaymentMethod(String? method) {
    switch (method) {
      case 'momo': return PaymentMethod.momo;
      case 'transfer': return PaymentMethod.transfer;
      default: return PaymentMethod.cash;
    }
  }

  Future<void> saveInvoice(String businessId, Invoice invoice, String stationName) async {
    await saveInvoicesBatch(businessId, [invoice], stationName);
  }

  Future<void> saveInvoicesBatch(String businessId, List<Invoice> invoices, String stationName) async {
    if (invoices.isEmpty) return;

    final invoiceData = invoices.map((inv) => {
      'id': inv.id,
      'business_id': businessId,
      'date': inv.date.toIso8601String(),
      'due_date': inv.dueDate?.toIso8601String(),
      'type': inv.type.name,
      'client_name': inv.clientInfo.name,
      'client_address': inv.clientInfo.address,
      'client_contact': inv.clientInfo.contact,
      'discount_value': inv.discountValue,
      'discount_type': inv.discountType.name,
      'tax_value': inv.taxValue,
      'amount_paid': inv.amountPaid,
      'payment_method': inv.paymentMethod.name,
      'is_estimate': inv.isEstimate,
      'is_pos': inv.isPos,
      'cashier_name': inv.cashierName,
      'station_name': stationName,
      'stock_reduced': inv.stockReduced,
    }).toList();

    await _sb.from('invoices').upsert(invoiceData);

    final List<Map<String, dynamic>> allItems = [];
    final List<String> invoiceIds = [];
    for (var inv in invoices) {
      invoiceIds.add(inv.id);
      for (var item in inv.items) {
        allItems.add({
          'invoice_id': inv.id,
          'name': item.name,
          'quantity': item.quantity,
          'selling_price': item.sellingPrice,
          'cost_price': item.costPrice,
          'product_id': item.productId,
        });
      }
    }

    await _sb.from('invoice_items').delete().inFilter('invoice_id', invoiceIds);
    if (allItems.isNotEmpty) {
      await _sb.from('invoice_items').insert(allItems);
    }
  }

  Future<void> deleteInvoice(String invoiceId) async {
    await _sb.from('invoices').delete().eq('id', invoiceId);
  }

  // ─── Expenses ───────────────────────────────────────────
  Future<List<Expense>> getExpenses(String businessId) async {
    final res = await _sb
        .from('expenses')
        .select()
        .eq('business_id', businessId)
        .order('date', ascending: false);
    return (res as List).map((e) => Expense(
      id: e['id'],
      date: DateTime.parse(e['date']),
      amount: (e['amount'] as num).toDouble(),
      description: e['description'] ?? '',
      category: _parseExpenseCategory(e['category']),
    )).toList();
  }

  ExpenseCategory _parseExpenseCategory(String? cat) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.name == cat,
      orElse: () => ExpenseCategory.other,
    );
  }

  Future<void> saveExpense(String businessId, Expense expense) async {
    await _sb.from('expenses').upsert({
      'id': expense.id,
      'business_id': businessId,
      'date': expense.date.toIso8601String(),
      'amount': expense.amount,
      'description': expense.description,
      'category': expense.category.name,
    });
  }

  Future<void> deleteExpense(String expenseId) async {
    await _sb.from('expenses').delete().eq('id', expenseId);
  }

  // ─── Real-time ──────────────────────────────────────────
  RealtimeChannel subscribeToInvoices(String businessId, void Function() onUpdate) {
    return _sb
        .channel('invoices_$businessId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'invoices',
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }
}
