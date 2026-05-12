import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const String privacyPolicy = '''
# Privacy Policy

**Effective Date: May 12, 2026**

Welcome to **Docara POS**. We value your privacy and are committed to protecting your business data.

## 1. Information We Collect
To provide our receipt and invoice generation services, we collect:
*   **Business Information**: Name, Email, Phone, Address, and Tax Identification Numbers.
*   **Transaction Data**: Details of invoices, receipts, expenses, and product inventory.
*   **Staff Profiles**: Names and roles of staff members authorized to use the system.

## 2. Data Synchronization & Cloud Storage
We use **Supabase** (a secure cloud database) to:
*   Synchronize your business profile across multiple devices.
*   Provide secure backups of your transaction history.
*   Store your business logo and professional signature for inclusion in documents.

## 3. Local Storage
The app stores data locally on your device to ensure functionality even without an internet connection. This data is synced to our secure cloud servers once a connection is established.

## 4. Security
We implement industry-standard security measures, including:
*   **Admin PIN Protection**: Sensitive business settings and deletions require authorized PIN entry.
*   **Encrypted Cloud Storage**: Data is stored securely on Supabase servers with row-level security.

## 5. Third-Party Services
We utilize Supabase for authentication, database hosting, and file storage. We do not sell your personal or business data to third-party advertisers.

## 6. Your Rights
You have the right to access, update, or delete your business data at any time through the application settings.

## 7. Contact Us
If you have any questions regarding this Privacy Policy, please contact us at support@docara.com.
''';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.inter(
            color: const Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E3A8A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Markdown(
        data: privacyPolicy,
        styleSheet: MarkdownStyleSheet(
          h1: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E3A8A),
          ),
          h2: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E3A8A),
            height: 2.0,
          ),
          p: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF475569),
            height: 1.6,
          ),
          listBullet: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF1E3A8A),
          ),
        ),
        padding: const EdgeInsets.all(24),
      ),
    );
  }
}
