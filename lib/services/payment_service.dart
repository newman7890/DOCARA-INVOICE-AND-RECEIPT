import 'package:flutter/material.dart';
import 'package:flutter_paystack_max/flutter_paystack_max.dart' as paystack;
import '../models/invoice.dart';

/// Abstract base class for all payment gateways.
/// This service handles the abstraction of different payment providers for SaaS.
abstract class PaymentService {
  final BusinessInfo businessInfo;

  PaymentService(this.businessInfo);

  /// Initiates a payment process.
  /// Returns true if payment was successful, false otherwise.
  Future<bool> processPayment({
    required double amount,
    required String currency,
    required String customerEmail,
    required String invoiceId,
    required BuildContext context,
  });

  /// Factory method to get the appropriate payment service
  static PaymentService getService(BusinessInfo info) {
    if (!info.isPaymentEnabled || info.paymentGateway == PaymentGateway.none) {
      return MockPaymentService(info);
    }

    switch (info.paymentGateway) {
      case PaymentGateway.paystack:
        return PaystackService(info);
      case PaymentGateway.stripe:
        return MockPaymentService(info); // To be replaced with StripeService
      case PaymentGateway.paypal:
        return MockPaymentService(info); // To be replaced with PaypalService
      default:
        return MockPaymentService(info);
    }
  }
}

/// A mock implementation for testing and development
class MockPaymentService extends PaymentService {
  MockPaymentService(super.businessInfo);

  @override
  Future<bool> processPayment({
    required double amount,
    required String currency,
    required String customerEmail,
    required String invoiceId,
    required BuildContext context,
  }) async {
    // Show a mock payment dialog
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Simulated Payment Gateway'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Merchant: ${businessInfo.name}'),
            Text('Invoice: #$invoiceId'),
            const SizedBox(height: 10),
            Text(
              'Total: $currency ${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: double.infinity == 0 ? FontWeight.normal : FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 20),
            const Text('This is a simulated transaction for testing purposes.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('SUCCESSFUL PAYMENT'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}

/// Real implementation for Paystack
class PaystackService extends PaymentService {
  PaystackService(super.businessInfo);

  @override
  Future<bool> processPayment({
    required double amount,
    required String currency,
    required String customerEmail,
    required String invoiceId,
    required BuildContext context,
  }) async {
    try {
      final selectedCurrency = (() {
        final cleanCurrency = currency.trim().toUpperCase();
        
        try {
          return paystack.PaystackCurrency.values.firstWhere(
            (e) => e.name.toUpperCase() == cleanCurrency || 
                   e.toString().split('.').last.toUpperCase() == cleanCurrency,
          );
        } catch (_) {
          // Fallback mapping for symbols if they were saved previously
          if (cleanCurrency == '₵' || cleanCurrency == '\u20B5') return paystack.PaystackCurrency.ghs;
          if (cleanCurrency == '\$') return paystack.PaystackCurrency.usd;
          if (cleanCurrency == '₦' || cleanCurrency == '\u20A6') return paystack.PaystackCurrency.ngn;
          return paystack.PaystackCurrency.ghs;
        }
      })();

      final request = paystack.PaystackTransactionRequest(
        reference: 'INV-${invoiceId.replaceAll("-", "")}-${DateTime.now().millisecondsSinceEpoch}',
        secretKey: businessInfo.gatewaySecretKey,
        email: customerEmail.isEmpty ? 'customer@example.com' : customerEmail,
        amount: (amount * 100).toDouble(),
        currency: selectedCurrency,
        channel: [
          paystack.PaystackPaymentChannel.mobileMoney,
          paystack.PaystackPaymentChannel.card,
        ],
      );

      final initializedTransaction = await paystack.PaymentService.initializeTransaction(request);

      if (!initializedTransaction.status) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Initialization Error (${selectedCurrency.name.toUpperCase()}): ${initializedTransaction.message}'), 
              backgroundColor: Colors.red
            ),
          );
        }
        return false;
      }

      if (!context.mounted) return false;

      await paystack.PaymentService.showPaymentModal(
        context,
        transaction: initializedTransaction,
        callbackUrl: 'https://standard.paystack.co/close', // Default fallback
      );

      // Verify the transaction
      final verification = await paystack.PaymentService.verifyTransaction(
        paystackSecretKey: businessInfo.gatewaySecretKey,
        initializedTransaction.data?.reference ?? request.reference,
      );

      return verification.status;
    } catch (e) {
      debugPrint('Paystack Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }
}
