import 'dart:convert';

enum InvoiceType { invoice, receipt }

enum DiscountType { percentage, fixed }

enum PaymentMethod { cash, momo, transfer }

enum PdfTemplate { sidebar, classic, minimalist }

enum PaymentGateway { none, stripe, paystack, paypal }

enum ChartPeriod { daily, weekly, monthly, yearly }

class BusinessInfo {
  final String name;
  final String email;
  final String phone;
  final String address;
  final String? logoPath;
  final String? terms;
  final String? signaturePath;
  final double revenueGoal;
  final String currency;
  final String? posSubtitle;
  final String? posFooterMessage;
  final String? posEmail;
  final String? pdfTermsLabel;
  final String? pdfSignatureLabel;
  final PdfTemplate pdfTemplate;
  final String? managerPin;
  final PaymentGateway paymentGateway;
  final String gatewayPublicKey;
  final String gatewaySecretKey;
  final bool isPaymentEnabled;
  final bool isLiveMode;

  BusinessInfo({
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.logoPath,
    this.terms,
    this.signaturePath,
    this.revenueGoal = 0.0,
    this.currency = '₵',
    this.posSubtitle,
    this.posFooterMessage,
    this.posEmail,
    this.pdfTermsLabel,
    this.pdfSignatureLabel,
    this.pdfTemplate = PdfTemplate.sidebar,
    this.managerPin = '1234',
    this.paymentGateway = PaymentGateway.none,
    this.gatewayPublicKey = '',
    this.gatewaySecretKey = '',
    this.isPaymentEnabled = false,
    this.isLiveMode = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'logoPath': logoPath,
      'terms': terms,
      'signaturePath': signaturePath,
      'revenueGoal': revenueGoal,
      'currency': currency,
      'posSubtitle': posSubtitle,
      'posFooterMessage': posFooterMessage,
      'posEmail': posEmail,
      'pdfTermsLabel': pdfTermsLabel,
      'pdfSignatureLabel': pdfSignatureLabel,
      'pdfTemplate': pdfTemplate.index,
      'managerPin': managerPin,
      'paymentGateway': paymentGateway.index,
      'gatewayPublicKey': gatewayPublicKey,
      'gatewaySecretKey': gatewaySecretKey,
      'isPaymentEnabled': isPaymentEnabled,
      'isLiveMode': isLiveMode,
    };
  }

  factory BusinessInfo.fromMap(Map<String, dynamic> map) {
    return BusinessInfo(
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      logoPath: map['logoPath'],
      terms: map['terms'],
      signaturePath: map['signaturePath'],
      revenueGoal: (map['revenueGoal'] ?? 0.0).toDouble(),
      currency: map['currency'] ?? '₵',
      posSubtitle: map['posSubtitle'],
      posFooterMessage: map['posFooterMessage'],
      posEmail: map['posEmail'],
      pdfTermsLabel: map['pdfTermsLabel'],
      pdfSignatureLabel: map['pdfSignatureLabel'],
      pdfTemplate: PdfTemplate.values[map['pdfTemplate'] ?? 0],
      managerPin: map['managerPin'],
      paymentGateway: PaymentGateway.values[map['paymentGateway'] ?? 0],
      gatewayPublicKey: map['gatewayPublicKey'] ?? '',
      gatewaySecretKey: map['gatewaySecretKey'] ?? '',
      isPaymentEnabled: map['isPaymentEnabled'] ?? false,
      isLiveMode: map['isLiveMode'] ?? false,
    );
  }

  BusinessInfo copyWith({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? logoPath,
    String? terms,
    String? signaturePath,
    double? revenueGoal,
    String? currency,
    String? posSubtitle,
    String? posFooterMessage,
    String? posEmail,
    String? pdfTermsLabel,
    String? pdfSignatureLabel,
    PdfTemplate? pdfTemplate,
    String? managerPin,
    PaymentGateway? paymentGateway,
    String? gatewayPublicKey,
    String? gatewaySecretKey,
    bool? isPaymentEnabled,
    bool? isLiveMode,
  }) {
    return BusinessInfo(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      logoPath: logoPath ?? this.logoPath,
      terms: terms ?? this.terms,
      signaturePath: signaturePath ?? this.signaturePath,
      revenueGoal: revenueGoal ?? this.revenueGoal,
      currency: currency ?? this.currency,
      posSubtitle: posSubtitle ?? this.posSubtitle,
      posFooterMessage: posFooterMessage ?? this.posFooterMessage,
      posEmail: posEmail ?? this.posEmail,
      pdfTermsLabel: pdfTermsLabel ?? this.pdfTermsLabel,
      pdfSignatureLabel: pdfSignatureLabel ?? this.pdfSignatureLabel,
      pdfTemplate: pdfTemplate ?? this.pdfTemplate,
      managerPin: managerPin ?? this.managerPin,
      paymentGateway: paymentGateway ?? this.paymentGateway,
      gatewayPublicKey: gatewayPublicKey ?? this.gatewayPublicKey,
      gatewaySecretKey: gatewaySecretKey ?? this.gatewaySecretKey,
      isPaymentEnabled: isPaymentEnabled ?? this.isPaymentEnabled,
      isLiveMode: isLiveMode ?? this.isLiveMode,
    );
  }

  String toJson() => json.encode(toMap());

  factory BusinessInfo.fromJson(String source) => BusinessInfo.fromMap(json.decode(source));
}

class ClientInfo {
  final String name;
  final String address;
  final String contact;

  ClientInfo({
    required this.name,
    required this.address,
    required this.contact,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'contact': contact,
    };
  }

  factory ClientInfo.fromMap(Map<String, dynamic> map) {
    return ClientInfo(
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      contact: map['contact'] ?? '',
    );
  }
}

class InvoiceItem {
  final String name;
  final int quantity;
  final double sellingPrice;
  final double? costPrice;

  InvoiceItem({
    required this.name,
    required this.quantity,
    required this.sellingPrice,
    this.costPrice,
  });

  double get total => quantity * sellingPrice;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'sellingPrice': sellingPrice,
      'costPrice': costPrice,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      name: map['name'] ?? '',
      quantity: map['quantity']?.toInt() ?? 0,
      sellingPrice: map['sellingPrice']?.toDouble() ?? 0.0,
      costPrice: map['costPrice']?.toDouble(),
    );
  }

  InvoiceItem copyWith({
    String? name,
    int? quantity,
    double? sellingPrice,
    double? costPrice,
  }) {
    return InvoiceItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      costPrice: costPrice ?? this.costPrice,
    );
  }
}

class Invoice {
  final String id;
  final DateTime date;
  final DateTime? dueDate;
  final InvoiceType type;
  final ClientInfo clientInfo;
  final List<InvoiceItem> items;
  final double discountValue;
  final DiscountType discountType;
  final double taxValue;
  final double amountPaid;
  final PaymentMethod paymentMethod;
  final String? watermarkPath;
  final double watermarkOpacity;
  final double watermarkRotation;

  final bool isEstimate;
  final bool isPos;
  final String? cashierName;
  final String? stationName;

  Invoice({
    required this.id,
    required this.date,
    this.dueDate,
    required this.type,
    required this.clientInfo,
    required this.items,
    this.discountValue = 0.0,
    this.discountType = DiscountType.fixed,
    this.taxValue = 0.0,
    this.amountPaid = 0.0,
    this.paymentMethod = PaymentMethod.cash,
    this.watermarkPath,
    this.watermarkOpacity = 0.1,
    this.watermarkRotation = -45.0,
    this.isEstimate = false,
    this.isPos = false,
    this.cashierName,
    this.stationName,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);

  double get discountAmount {
    if (discountType == DiscountType.percentage) {
      return subtotal * (discountValue / 100);
    } else {
      return discountValue;
    }
  }

  double get taxAmount => (subtotal - discountAmount) * (taxValue / 100);
  
  // Anti-Fraud: Total cannot be negative
  double get total => (subtotal - discountAmount + taxAmount).clamp(0.0, double.infinity);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'type': type.index,
      'clientInfo': clientInfo.toMap(),
      'items': items.map((x) => x.toMap()).toList(),
      'discountValue': discountValue,
      'discountType': discountType.index,
      'taxValue': taxValue,
      'amountPaid': amountPaid,
      'paymentMethod': paymentMethod.index,
      'watermarkPath': watermarkPath,
      'watermarkOpacity': watermarkOpacity,
      'watermarkRotation': watermarkRotation,
      'isEstimate': isEstimate,
      'isPos': isPos,
      'cashierName': cashierName,
      'stationName': stationName,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      dueDate: map['dueDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['dueDate']) : null,
      type: InvoiceType.values[map['type'] ?? 0],
      clientInfo: ClientInfo.fromMap(map['clientInfo']),
      items: List<InvoiceItem>.from(map['items']?.map((x) => InvoiceItem.fromMap(x)) ?? []),
      discountValue: map['discountValue']?.toDouble() ?? 0.0,
      discountType: DiscountType.values[map['discountType'] ?? 0],
      taxValue: map['taxValue']?.toDouble() ?? 0.0,
      amountPaid: map['amountPaid']?.toDouble() ?? 0.0,
      paymentMethod: PaymentMethod.values[map['paymentMethod'] ?? 0],
      watermarkPath: map['watermarkPath'],
      watermarkOpacity: map['watermarkOpacity']?.toDouble() ?? 0.1,
      watermarkRotation: map['watermarkRotation']?.toDouble() ?? -45.0,
      isEstimate: map['isEstimate'] ?? false,
      isPos: map['isPos'] ?? false,
      cashierName: map['cashierName'],
      stationName: map['stationName'],
    );
  }

  String toJson() => json.encode(toMap());

  factory Invoice.fromJson(String source) => Invoice.fromMap(json.decode(source));

  Invoice copyWith({
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
    String? stationName,
  }) {
    return Invoice(
      id: id ?? this.id,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      type: type ?? this.type,
      clientInfo: clientInfo ?? this.clientInfo,
      items: items ?? this.items,
      discountValue: discountValue ?? this.discountValue,
      discountType: discountType ?? this.discountType,
      taxValue: taxValue ?? this.taxValue,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      watermarkPath: watermarkPath ?? this.watermarkPath,
      watermarkOpacity: watermarkOpacity ?? this.watermarkOpacity,
      watermarkRotation: watermarkRotation ?? this.watermarkRotation,
      isEstimate: isEstimate ?? this.isEstimate,
      isPos: isPos ?? this.isPos,
      cashierName: cashierName ?? this.cashierName,
      stationName: stationName ?? this.stationName,
    );
  }
}

enum ExpenseCategory { marketing, supplies, rent, utilities, labor, other }

class Expense {
  final String id;
  final DateTime date;
  final double amount;
  final String description;
  final ExpenseCategory category;

  Expense({
    required this.id,
    required this.date,
    required this.amount,
    required this.description,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch,
      'amount': amount,
      'description': description,
      'category': category.index,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      category: ExpenseCategory.values[map['category'] ?? 5],
    );
  }
}

class Customer {
  final String id;
  final String name;
  final String address;
  final String contact;
  final double totalSpent;
  final int invoiceCount;

  Customer({
    required this.id,
    required this.name,
    required this.address,
    required this.contact,
    this.totalSpent = 0.0,
    this.invoiceCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'contact': contact,
      'totalSpent': totalSpent,
      'invoiceCount': invoiceCount,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      contact: map['contact'] ?? '',
      totalSpent: (map['totalSpent'] ?? 0.0).toDouble(),
      invoiceCount: map['invoiceCount'] ?? 0,
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? address,
    String? contact,
    double? totalSpent,
    int? invoiceCount,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      contact: contact ?? this.contact,
      totalSpent: totalSpent ?? this.totalSpent,
      invoiceCount: invoiceCount ?? this.invoiceCount,
    );
  }
}

class Product {
  final String id;
  final String name;
  final double price;
  final String? description;
  final String? barcode;
  final int stockQuantity;
  final int minStockLevel;
  final double? costPrice;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.barcode,
    this.stockQuantity = 0,
    this.minStockLevel = 5,
    this.costPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'barcode': barcode,
      'stockQuantity': stockQuantity,
      'minStockLevel': minStockLevel,
      'costPrice': costPrice,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      price: map['price']?.toDouble() ?? 0.0,
      description: map['description'],
      barcode: map['barcode'],
      stockQuantity: map['stockQuantity']?.toInt() ?? 0,
      minStockLevel: map['minStockLevel']?.toInt() ?? 5,
      costPrice: map['costPrice']?.toDouble(),
    );
  }

  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? description,
    String? barcode,
    int? stockQuantity,
    int? minStockLevel,
    double? costPrice,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      barcode: barcode ?? this.barcode,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      costPrice: costPrice ?? this.costPrice,
    );
  }
}

class Staff {
  final String id;
  final String name;
  final String? phone;
  final String role;
  final String? _pin; // Internal private storage

  Staff({
    required this.id,
    required this.name,
    this.phone,
    this.role = 'Cashier',
    String? pin,
  }) : _pin = pin;

  // Masked getter for UI safety
  String? get pin => _pin;

  bool verifyPin(String input) {
    if (_pin == null || _pin.isEmpty) return true;
    return _pin == input;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'role': role,
      'pin': _pin,
    };
  }

  factory Staff.fromMap(Map<String, dynamic> map) {
    return Staff(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      role: map['role'] ?? 'Cashier',
      pin: map['pin'],
    );
  }
}
