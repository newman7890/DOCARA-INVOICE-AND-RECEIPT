import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'User Guide',
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
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/docs/user_guide.md'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
              ),
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading guide: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          return Markdown(
            data: snapshot.data ?? 'No guide content found.',
            styleSheet: MarkdownStyleSheet(
              h1: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A8A),
              ),
              h2: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A8A),
                height: 2.0,
              ),
              h3: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
                height: 1.8,
              ),
              p: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF475569),
                height: 1.6,
              ),
              listBullet: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF1E3A8A),
              ),
              blockquote: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF64748B),
                fontStyle: FontStyle.italic,
              ),
              blockquoteDecoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                border: const Border(
                  left: BorderSide(color: Color(0xFF1E3A8A), width: 4),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              code: GoogleFonts.firaCode(
                backgroundColor: const Color(0xFFF1F5F9),
                color: const Color(0xFFE11D48),
                fontSize: 13,
              ),
              tableBorder: TableBorder.all(color: const Color(0xFFE2E8F0)),
              tableHead: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A8A),
              ),
              tableBody: GoogleFonts.inter(
                color: const Color(0xFF475569),
              ),
            ),
            padding: const EdgeInsets.all(24),
          );
        },
      ),
    );
  }
}
