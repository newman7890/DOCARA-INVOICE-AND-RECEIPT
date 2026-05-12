import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/invoice_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _businessController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _businessController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final name = _businessController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }
    if (pass.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final error = await auth.signUp(email, pass, name);
    if (error != null && mounted) {
      _showError(error);
    } else if (mounted) {
      // Load data and navigate to home
      await context.read<InvoiceProvider>().loadFromSupabase();
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.store_mall_directory_outlined, color: Colors.white, size: 64),
                  const SizedBox(height: 16),
                  const Text('Create Your Business', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Set up your Docara account', style: TextStyle(color: Colors.white60, fontSize: 14)),
                  const SizedBox(height: 40),
                  _buildCard(context, auth),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text('Already have an account? Log in', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          _buildField(_businessController, 'Business Name', Icons.storefront_outlined),
          const SizedBox(height: 16),
          _buildField(_emailController, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildField(_passwordController, 'Password', Icons.lock_outlined, obscure: _obscure, suffix: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
            onPressed: () => setState(() => _obscure = !_obscure),
          )),
          const SizedBox(height: 32),
          auth.isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : ElevatedButton(
                  onPressed: _signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E3A8A),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('CREATE ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {
    TextInputType? type, bool obscure = false, Widget? suffix
  }) {
    return TextField(
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
}
