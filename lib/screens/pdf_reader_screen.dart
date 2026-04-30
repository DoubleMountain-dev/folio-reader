// lib/screens/pdf_reader_screen.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../providers/library_provider.dart';
import '../utils/app_theme.dart';

class PdfReaderScreen extends StatelessWidget {
  final BookDocument book;
  final Uint8List pdfBytes;
  const PdfReaderScreen({super.key, required this.book, required this.pdfBytes});

  void _openInTab() {
    final b64 = base64Encode(pdfBytes);
    final url = 'data:application/pdf;base64,$b64';
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(book.title, style: GoogleFonts.dmSans(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline, color: Colors.white),
            onPressed: () {
              context.read<LibraryProvider>().addBookmark(book.id, DocBookmark(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                chapter: 'PDF', page: 0, preview: book.title,
              ));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Bookmark added'), behavior: SnackBarBehavior.floating));
            },
          ),
        ],
      ),
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.picture_as_pdf, size: 90, color: Colors.red.shade400),
          const SizedBox(height: 24),
          Text(book.title, textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                  fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 8),
          Text('PDF -- ${(pdfBytes.length / 1024 / 1024).toStringAsFixed(1)} MB',
              style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white54)),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _openInTab,
            icon: const Icon(Icons.open_in_new, size: 20),
            label: Text('Open PDF in Browser',
                style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
          const SizedBox(height: 12),
          Text('Opens in a new tab with full zoom, navigation and download.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white38, height: 1.5)),
        ]),
      )),
    );
  }
}
