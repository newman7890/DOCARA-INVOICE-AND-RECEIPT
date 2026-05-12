import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/invoice_provider.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final _stationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _stationController.text = context.read<SettingsProvider>().stationName;
  }

  @override
  void dispose() {
    _stationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Station Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E3A8A).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done, color: Color(0xFF1E3A8A), size: 28),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Supabase Cloud Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 4),
                        Text('Your data syncs automatically across all devices via Supabase.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('STATION NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            const Text(
              'Give this computer a name so the admin dashboard can identify which station made each sale.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stationController,
              decoration: InputDecoration(
                hintText: 'e.g. Front Desk, Station 1, Cashier 2',
                prefixIcon: const Icon(Icons.computer, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                final name = _stationController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a station name.')));
                  return;
                }

                // Station Identity Forgery Protection
                final provider = context.read<InvoiceProvider>();
                final settingsProvider = context.read<SettingsProvider>();
                if (provider.activeStaff != null) {
                   // This is a staff member, we need to show the authorization dialog
                   final passController = TextEditingController();
                   final authorized = await showDialog<bool>(
                     context: context,
                     builder: (context) => AlertDialog(
                       title: const Text('Admin Authorization'),
                       content: Column(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           const Text('Only Admin can change Station Identity. Enter Admin Password:'),
                           const SizedBox(height: 16),
                           TextField(controller: passController, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Password')),
                         ],
                       ),
                       actions: [
                         TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                         TextButton(onPressed: () => Navigator.pop(context, passController.text == (settingsProvider.businessInfo?.managerPin ?? '1234')), child: const Text('AUTHORIZE')),
                       ],
                     ),
                   );
                   if (authorized != true) return;
                }

                if (!mounted) return;
                await settingsProvider.updateStationName(name);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Station name saved!')));
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Save Station Name', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
