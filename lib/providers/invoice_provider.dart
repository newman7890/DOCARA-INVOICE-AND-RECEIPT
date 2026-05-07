import 'package:flutter/material.dart';
import '../models/invoice.dart';

class InvoiceProvider with ChangeNotifier {
  Invoice? _currentInvoice;
  final List<Customer> _customers = [];
  final List<Product> _products = [];
  final List<Invoice> _invoices = [];
  
  Invoice? get currentInvoice => _currentInvoice;
  List<Customer> get customers => _customers;
  List<Product> get products => _products;
  List<Invoice> get invoices => _invoices;

  void addCustomer(Customer customer) {
    _customers.add(customer);
    notifyListeners();
  }

  void updateCustomer(Customer customer) {
    final index = _customers.indexWhere((c) => c.id == customer.id);
    if (index != -1) {
      _customers[index] = customer;
      notifyListeners();
    }
  }

  void addProduct(Product product) {
    _products.add(product);
    notifyListeners();
  }

  void updateProduct(Product product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
      notifyListeners();
    }
  }

  void deleteCustomer(String name) {
    _customers.removeWhere((c) => c.name == name);
    notifyListeners();
  }

  void deleteProduct(String name) {
    _products.removeWhere((p) => p.name == name);
    notifyListeners();
  }

  void deleteInvoice(String invoiceId) {
    _invoices.removeWhere((inv) => inv.id == invoiceId);
    notifyListeners();
  }

  void saveCurrentInvoice() {
    if (_currentInvoice != null) {
      final index = _invoices.indexWhere((inv) => inv.id == _currentInvoice!.id);
      if (index != -1) {
        _invoices[index] = _currentInvoice!;
      } else {
        _invoices.insert(0, _currentInvoice!);
      }
      notifyListeners();
    }
  }

  void createNewInvoice({bool isEstimate = false, bool isPos = false}) {
    _currentInvoice = Invoice(
      id: 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
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
    final newType = _currentInvoice!.type == InvoiceType.invoice 
        ? InvoiceType.receipt 
        : InvoiceType.invoice;
    _currentInvoice = _currentInvoice!.copyWith(type: newType);
    notifyListeners();
  }

  void addItem(InvoiceItem item) {
    if (_currentInvoice == null) return;
    final updatedItems = List<InvoiceItem>.from(_currentInvoice!.items);
    
    // Check if an item with the same name and price already exists
    final existingIndex = updatedItems.indexWhere(
      (i) => i.name == item.name && i.sellingPrice == item.sellingPrice
    );
    
    if (existingIndex != -1) {
      // Update quantity of existing item
      final existingItem = updatedItems[existingIndex];
      updatedItems[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + item.quantity
      );
    } else {
      // Add as new item
      updatedItems.add(item);
    }
    
    _currentInvoice = _copyInvoice(items: updatedItems);
    notifyListeners();
  }

  void removeItem(int index) {
    if (_currentInvoice == null) return;
    final updatedItems = List<InvoiceItem>.from(_currentInvoice!.items)..removeAt(index);
    _currentInvoice = _copyInvoice(items: updatedItems);
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
    String? id,
    DateTime? date,
    DateTime? dueDate,
    InvoiceType? type,
    ClientInfo? clientInfo,
    List<InvoiceItem>? items,
    double? discountValue,
    DiscountType? discountType,
    double? taxValue,
    double? amountPaid,
    PaymentMethod? paymentMethod,
    String? watermarkPath,
    double? watermarkOpacity,
    double? watermarkRotation,
    bool? isEstimate,
    bool? isPos,
    String? cashierName,
  }) {
    return _currentInvoice!.copyWith(
      id: id,
      date: date,
      dueDate: dueDate,
      type: type,
      clientInfo: clientInfo,
      items: items,
      discountValue: discountValue,
      discountType: discountType,
      taxValue: taxValue,
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
      watermarkPath: watermarkPath,
      watermarkOpacity: watermarkOpacity,
      watermarkRotation: watermarkRotation,
      isEstimate: isEstimate,
      isPos: isPos,
      cashierName: cashierName,
    );
  }

  void loadFromBackup(Map<String, dynamic> data) {
    if (data.containsKey('customers')) {
      _customers.clear();
      _customers.addAll((data['customers'] as List).map((x) => Customer.fromMap(x)));
    }
    if (data.containsKey('products')) {
      _products.clear();
      _products.addAll((data['products'] as List).map((x) => Product.fromMap(x)));
    }
    if (data.containsKey('invoices')) {
      _invoices.clear();
      _invoices.addAll((data['invoices'] as List).map((x) => Invoice.fromMap(x)));
    }
    notifyListeners();
  }
}
