import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/settings_provider.dart';
import '../models/invoice.dart';
import 'auth/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isAdminMode = false;

  // Admin fields
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscure = true;

  // Cashier fields
  Staff? _selectedStaff;
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_isAdminMode) {
      await _adminLogin();
    } else {
      await _cashierLogin();
    }
  }

  Future<void> _adminLogin() async {
    final email = _emailController.text.trim();
    final pass = _passController.text;
    if (email.isEmpty || pass.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }
    final auth = context.read<AuthProvider>();
    final invoiceProvider = context.read<InvoiceProvider>();
    
    // CRITICAL: Clear any leftover cashier session BEFORE signing in as admin.
    // This ensures that when the app reloads data after login, it doesn't 
    // accidentally restore a previous cashier's dashboard.
    await invoiceProvider.setActiveStaff(null);
    
    final error = await auth.signIn(email, pass);
    if (error != null && mounted) {
      _showError(error);
    } else if (mounted) {
      // Re-load to ensure everything is fresh
      await invoiceProvider.loadFromSupabase();
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _cashierLogin() async {
    if (_selectedStaff == null) {
      _showError('Please select your name.');
      return;
    }
    final staff = _selectedStaff!;
    if (!staff.verifyPin(_pinController.text)) {
      _showError('Incorrect PIN. Please try again.');
      return;
    }
    await context.read<InvoiceProvider>().setActiveStaff(staff);
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red[700]));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final invoice = context.watch<InvoiceProvider>();
    final settings = context.watch<SettingsProvider>();
    final staffList = invoice.staff;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                  child: const Icon(Icons.lock_person_outlined, size: 56, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  settings.businessInfo?.name ?? 'DOCARA POS',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                const Text('BUSINESS MANAGEMENT SUITE', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 2)),
                const SizedBox(height: 40),

                // Mode toggle
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(child: _modeBtn('STAFF', !_isAdminMode, () => setState(() { _isAdminMode = false; _pinController.clear(); }))),
                        const SizedBox(width: 12),
                        Expanded(child: _modeBtn('ADMIN', _isAdminMode, () => setState(() { _isAdminMode = true; _pinController.clear(); }))),
                      ]),
                      const SizedBox(height: 28),

                      if (!_isAdminMode) ...[
                        // Cashier mode
                        _cashierDropdown(staffList),
                        const SizedBox(height: 16),
                        _pinField(),
                      ] else ...[
                        // Admin mode
                        _textField(_emailController, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
                        const SizedBox(height: 14),
                        _textField(_passController, 'Password', Icons.lock_outlined, obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              final email = _emailController.text.trim();
                              if (email.isEmpty) {
                                _showError('Please enter your email above to reset password.');
                                return;
                              }
                              final error = await context.read<AuthProvider>().resetPassword(email);
                              if (!context.mounted) return;
                              if (error != null) {
                                _showError(error);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Password reset link sent to your email.'), backgroundColor: Colors.green),
                                );
                              }
                            },
                            child: const Text('Forgot Password?', style: TextStyle(color: Colors.white60, fontSize: 12)),
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),
                      auth.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : ElevatedButton(
                              onPressed: _onLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1E3A8A),
                                minimumSize: const Size(double.infinity, 54),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('UNLOCK SYSTEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                  child: const Text('New business? Create an account →', style: TextStyle(color: Colors.white60, fontSize: 13)),
                ),
                const SizedBox(height: 8),
                Text('Station: ${settings.stationName}', style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeBtn(String title, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? Colors.white : Colors.white24),
      ),
      alignment: Alignment.center,
      child: Text(title, style: TextStyle(color: active ? const Color(0xFF1E3A8A) : Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
    ),
  );

  Widget _cashierDropdown(List<Staff> staff) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<Staff>(
        value: _selectedStaff,
        hint: const Text('Select your name', style: TextStyle(color: Colors.white38)),
        dropdownColor: const Color(0xFF1E293B),
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
        items: staff.map((s) => DropdownMenuItem(value: s, child: Text(s.name, style: const TextStyle(color: Colors.white)))).toList(),
        onChanged: (val) => setState(() { _selectedStaff = val; _pinController.clear(); }),
      ),
    ),
  );

  Widget _pinField() => TextField(
    controller: _pinController,
    keyboardType: TextInputType.number,
    obscureText: true,
    style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 8),
    textAlign: TextAlign.center,
    maxLength: 4,
    decoration: InputDecoration(
      hintText: 'PIN',
      counterText: '',
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 16, letterSpacing: 2),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
    ),
  );

  Widget _textField(TextEditingController ctrl, String label, IconData icon, {
    TextInputType? type, bool obscure = false, Widget? suffix,
  }) => TextField(
    controller: ctrl,
    keyboardType: type,
    obscureText: obscure,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      prefixIcon: Icon(icon, color: Colors.white54),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    ),
  );
}
