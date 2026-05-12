import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
import '../providers/invoice_provider.dart';

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();
    final staffList = provider.staff;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Staff Management', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E3A8A),
      ),
      body: Column(
        children: [
          _buildActiveStaffHeader(context, provider),
          Expanded(
            child: staffList.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: staffList.length,
                    itemBuilder: (context, index) {
                      final staff = staffList[index];
                      final isActive = provider.activeStaff?.id == staff.id;
                      
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: isActive ? const Color(0xFF3B82F6) : Colors.grey.shade200,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () => _showStaffDialog(context, provider, existingStaff: staff),
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: isActive ? const Color(0xFF3B82F6) : const Color(0xFFF1F5F9),
                            child: Icon(
                              Icons.person,
                              color: isActive ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                          title: Text(
                            staff.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(staff.role, style: TextStyle(color: Colors.grey.shade600)),
                              if (staff.phone != null && staff.phone!.isNotEmpty)
                                Text(staff.phone!, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              Row(
                                children: [
                                  Icon(
                                    staff.pin != null ? Icons.lock : Icons.lock_open,
                                    size: 12,
                                    color: staff.pin != null ? Colors.green : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    staff.pin != null ? 'PIN Set' : 'No PIN',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: staff.pin != null ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isActive)
                                TextButton(
                                  onPressed: () => provider.setActiveStaff(staff),
                                  child: const Text('ACTIVATE'),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A)),
                                onPressed: () => _showStaffDialog(context, provider, existingStaff: staff),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _confirmDelete(context, provider, staff),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStaffDialog(context, provider),
        backgroundColor: const Color(0xFF1E3A8A),
        icon: const Icon(Icons.add),
        label: const Text('Add Staff Member'),
      ),
    );
  }

  Widget _buildActiveStaffHeader(BuildContext context, InvoiceProvider provider) {
    final active = provider.activeStaff;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Active Cashier',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                active?.name ?? 'Administrator (Default)',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              if (active != null)
                TextButton(
                  onPressed: () => provider.setActiveStaff(null),
                  child: const Text('RESET TO ADMIN'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No staff members yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 8),
          Text(
            'Add cashiers to track sales by employee',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  void _showStaffDialog(BuildContext context, InvoiceProvider provider, {Staff? existingStaff}) {
    final nameController = TextEditingController(text: existingStaff?.name ?? '');
    final phoneController = TextEditingController(text: existingStaff?.phone ?? '');
    final pinController = TextEditingController(); // Don't pre-fill cleartext PIN
    String role = existingStaff?.role ?? 'Cashier';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingStaff == null ? 'Add New Staff' : 'Edit Staff'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name', hintText: 'Full Name'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone', hintText: 'Optional'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: pinController,
                decoration: InputDecoration(
                  labelText: 'Login PIN',
                  hintText: existingStaff == null ? 'Set 4-digit PIN' : '•••• (Enter to change)',
                  helperText: existingStaff == null 
                      ? 'Required for cashier login' 
                      : 'Leave blank to keep current PIN',
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue: role,
                items: ['Cashier', 'Manager', 'Sales Associate']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => role = v ?? role,
                decoration: const InputDecoration(labelText: 'Role'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              final newPin = pinController.text.trim();
              if (nameController.text.isNotEmpty) {
                // Unique PIN Check
                if (newPin.isNotEmpty) {
                  final collision = provider.staff.any((s) => s.pin == newPin && s.id != existingStaff?.id);
                  if (collision) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error: This PIN is already used by another staff member.'))
                    );
                    return;
                  }
                }

                final staff = Staff(
                  id: existingStaff?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  phone: phoneController.text,
                  role: role,
                  pin: newPin.isEmpty ? existingStaff?.pin : newPin,
                );
                
                if (existingStaff == null) {
                  provider.addStaff(staff);
                } else {
                  provider.updateStaff(staff);
                }
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
            child: Text(existingStaff == null ? 'SAVE STAFF' : 'UPDATE STAFF'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, InvoiceProvider provider, Staff staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff?'),
        content: Text('Are you sure you want to delete ${staff.name}? All previous sales recorded under this name will remain, but you won\'t be able to select them for future sales.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              provider.deleteStaff(staff.id);
              Navigator.pop(context);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
