// lib/screens/book_detail_screen.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../providers/library_provider.dart';
import '../utils/app_theme.dart';
import 'text_reader_screen.dart';
import 'pdf_reader_screen.dart';

class BookDetailScreen extends StatelessWidget {
  final BookDocument book;
  const BookDetailScreen({super.key, required this.book});

  void _openPdf(BuildContext context, BookDocument current) {
    final input = html.FileUploadInputElement()
      ..accept = '.pdf'
      ..multiple = false;
    input.onChange.listen((_) {
      final files = input.files;
      if (files == null || files.isEmpty) return;
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((_) {
        if (!context.mounted) return;
        final bytes = Uint8List.fromList(reader.result as List<int>);
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => PdfReaderScreen(book: current, pdfBytes: bytes)));
      });
    });
    input.click();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(book.spineColor.replaceFirst('#', '0xFF')));
    final library = context.watch<LibraryProvider>();
    final current = library.books.firstWhere((b) => b.id == book.id, orElse: () => book);

    return Scaffold(
      backgroundColor: AppColors.paperWarm,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 260, pinned: true, backgroundColor: color,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white70),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Remove book?'),
                  content: Text('"${book.title}" will be removed.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        context.read<LibraryProvider>().removeBook(book.id);
                        Navigator.pop(context); Navigator.pop(context);
                      },
                      child: const Text('Remove', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(color: color,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(height: 50),
                Container(
                  width: 100, height: 140,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20, offset: const Offset(6, 10))],
                  ),
                  child: Stack(children: [
                    Positioned(left: 0, top: 0, bottom: 0, width: 6,
                        child: Container(color: Colors.black.withValues(alpha: 0.3))),
                    Center(child: Padding(padding: const EdgeInsets.all(8),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(book.title, textAlign: TextAlign.center,
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: Colors.white, height: 1.3)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(book.formatLabel,
                              style: GoogleFonts.dmSans(fontSize: 8, color: Colors.white,
                                  fontWeight: FontWeight.w700, letterSpacing: 1)),
                        ),
                      ]),
                    )),
                  ]),
                ),
              ]),
            ),
          ),
        ),

        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(book.title, style: GoogleFonts.playfairDisplay(
                fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.inkDark)),
            const SizedBox(height: 4),
            Text(book.author, style: GoogleFonts.dmSans(
                fontSize: 15, color: AppColors.accentRed, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _Tag(text: book.formatLabel),
              if (book.totalPages > 0) _Tag(text: '${book.totalPages} p.'),
              _Tag(text: '${book.chapters.length} ch.'),
            ]),
            const SizedBox(height: 16),

            if (current.currentPage > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.creamLight,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Reading Progress', style: GoogleFonts.dmSans(
                        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedBrown)),
                    Text('${(current.progress * 100).round()}%', style: GoogleFonts.dmSans(
                        fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: current.progress, backgroundColor: Colors.white,
                      valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6)),
                  const SizedBox(height: 6),
                  Text('page ${current.currentPage} of ${book.totalPages}',
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.mutedBrown)),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            if (book.format == DocFormat.pdf) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200)),
                child: Row(children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'PDFs open in a new browser tab. You will need to select the file again.',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: Colors.orange.shade800, height: 1.4))),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            if (book.chapters.isNotEmpty) ...[
              Text('Table of Contents', style: GoogleFonts.playfairDisplay(
                  fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.inkDark)),
              const SizedBox(height: 8),
              ...book.chapters.take(25).map((ch) => _ChapterRow(
                  chapter: ch, color: color,
                  isCurrent: ch.startPage <= current.currentPage && current.currentPage > 0)),
              if (book.chapters.length > 25)
                Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('... and ${book.chapters.length - 25} more',
                      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.mutedBrown))),
            ],
            const SizedBox(height: 32),
          ]),
        )),
      ]),

      bottomNavigationBar: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              if (book.format == DocFormat.pdf) {
                _openPdf(context, current);
              } else {
                context.read<LibraryProvider>().openBook(current.id, current.title);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => TextReaderScreen(book: current)));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              elevation: 0,
            ),
            icon: Icon(book.format == DocFormat.pdf ? Icons.open_in_new : Icons.menu_book_rounded),
            label: Text(
              book.format == DocFormat.pdf ? 'Open PDF'
                  : current.currentPage > 0 ? 'Continue Reading' : 'Start Reading',
              style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      )),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: AppColors.creamLight,
        borderRadius: BorderRadius.circular(16)),
    child: Text(text, style: GoogleFonts.dmSans(
        fontSize: 12, color: AppColors.mutedBrown, fontWeight: FontWeight.w500)),
  );
}

class _ChapterRow extends StatelessWidget {
  final DocChapter chapter;
  final Color color;
  final bool isCurrent;
  const _ChapterRow({required this.chapter, required this.color, required this.isCurrent});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 1),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: isCurrent ? color.withValues(alpha: 0.08) : null,
      border: const Border(bottom: BorderSide(color: Color(0xFFE8E0D0), width: 0.5)),
    ),
    child: Row(children: [
      if (isCurrent) Container(width: 4, height: 4, margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      Expanded(child: Text(chapter.title, style: GoogleFonts.dmSans(
          fontSize: 13, color: isCurrent ? color : AppColors.inkDark,
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400))),
      Text('p.${chapter.startPage}',
          style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.mutedBrown)),
    ]),
  );
}
