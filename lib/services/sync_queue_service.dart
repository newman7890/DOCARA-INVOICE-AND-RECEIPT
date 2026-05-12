import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/invoice.dart';

class SyncQueueService {
  static const String _queueKey = 'offline_invoice_queue';

  /// Adds an invoice (and its assigned station name) to the offline queue
  Future<void> queueInvoice(Invoice invoice, String stationName) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Read existing queue
    final List<String> rawQueue = prefs.getStringList(_queueKey) ?? [];
    
    // Create a payload that includes both the invoice and the station name
    final Map<String, dynamic> payload = {
      'invoice': invoice.toMap(),
      'stationName': stationName,
    };
    
    rawQueue.add(json.encode(payload));
    await prefs.setStringList(_queueKey, rawQueue);
  }

  /// Retrieves the current queue of pending offline invoices
  Future<List<Map<String, dynamic>>> getPendingInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawQueue = prefs.getStringList(_queueKey) ?? [];
    
    return rawQueue.map((str) => json.decode(str) as Map<String, dynamic>).toList();
  }

  /// Removes a specific invoice from the queue after it has been successfully synced
  Future<void> removeInvoiceFromQueue(String invoiceId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawQueue = prefs.getStringList(_queueKey) ?? [];
    
    // Keep everything EXCEPT the invoice that was successfully synced
    final List<String> newQueue = rawQueue.where((str) {
      final data = json.decode(str) as Map<String, dynamic>;
      final invMap = data['invoice'] as Map<String, dynamic>;
      return invMap['id'] != invoiceId;
    }).toList();
    
    await prefs.setStringList(_queueKey, newQueue);
  }

  /// Returns true if there are items waiting to sync
  Future<bool> hasPendingItems() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawQueue = prefs.getStringList(_queueKey) ?? [];
    return rawQueue.isNotEmpty;
  }
}
