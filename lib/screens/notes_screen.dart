// lib/screens/notes_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../models/document.dart';
import '../utils/app_theme.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final quotes = library.books.expand((b) => b.quotes).toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final bookmarks = library.books.expand((b) => b.bookmarks).toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));

    return Scaffold(
      backgroundColor: AppColors.paperWarm,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            title: Text('Notes & Bookmarks',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.paperWarm)),
            backgroundColor: AppColors.woodBrown, pinned: true,
            bottom: TabBar(
              controller: _tab,
              indicatorColor: AppColors.accentRed, indicatorWeight: 2,
              labelColor: AppColors.accentRed,
              unselectedLabelColor: AppColors.paperWarm.withValues(alpha: 0.5),
              labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'Quotes (${quotes.length})'),
                Tab(text: 'Bookmarks (${bookmarks.length})'),
              ],
            ),
          ),
        ],
        body: TabBarView(controller: _tab, children: [
          _QuoteList(quotes: quotes),
          _BookmarkList(bookmarks: bookmarks),
        ]),
      ),
    );
  }
}

class _QuoteList extends StatelessWidget {
  final List<DocQuote> quotes;
  const _QuoteList({required this.quotes});
  @override
  Widget build(BuildContext context) {
    if (quotes.isEmpty) return _Empty(icon: Icons.format_quote_rounded,
        msg: 'No saved quotes', hint: 'Highlight text while reading');
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: quotes.length,
      separatorBuilder: (_, __) => const Divider(
          height: 1, color: Color(0xFFE8E0D0), indent: 16, endIndent: 16),
      itemBuilder: (_, i) => _QuoteCard(quote: quotes[i]),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final DocQuote quote;
  const _QuoteCard({required this.quote});
  String _ago() {
    final d = DateTime.now().difference(quote.savedAt);
    if (d.inDays > 6) return '${(d.inDays / 7).round()}wk ago';
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    return 'just now';
  }
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: AppColors.creamLight,
            borderRadius: BorderRadius.circular(8),
            border: const Border(left: BorderSide(color: AppColors.accentRed, width: 3))),
        child: Text('"${quote.text}"', style: GoogleFonts.playfairDisplay(
            fontSize: 13, fontStyle: FontStyle.italic,
            color: const Color(0xFF5A4E3A), height: 1.6)),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppColors.creamLight,
              borderRadius: BorderRadius.circular(10)),
          child: Text('${quote.chapter} - p.${quote.page}',
              style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.mutedBrown,
                  fontWeight: FontWeight.w500)),
        ),
        const Spacer(),
        Text(_ago(), style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.mutedBrown)),
      ]),
    ]),
  );
}

class _BookmarkList extends StatelessWidget {
  final List<DocBookmark> bookmarks;
  const _BookmarkList({required this.bookmarks});
  @override
  Widget build(BuildContext context) {
    if (bookmarks.isEmpty) return _Empty(icon: Icons.bookmark_border_rounded,
        msg: 'No bookmarks', hint: 'Tap the bookmark icon while reading');
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: bookmarks.length,
      separatorBuilder: (_, __) => const Divider(
          height: 1, color: Color(0xFFE8E0D0), indent: 16, endIndent: 16),
      itemBuilder: (_, i) {
        final bm = bookmarks[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.accentRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.bookmark_rounded, color: AppColors.accentRed, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bm.chapter, style: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkDark)),
              Text('Page ${bm.page}  --  ${bm.preview.length > 60 ? "${bm.preview.substring(0, 60)}..." : bm.preview}',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.mutedBrown)),
            ])),
          ]),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String msg, hint;
  const _Empty({required this.icon, required this.msg, required this.hint});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 56, color: AppColors.mutedBrown.withValues(alpha: 0.3)),
      const SizedBox(height: 16),
      Text(msg, style: GoogleFonts.playfairDisplay(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.mutedBrown)),
      const SizedBox(height: 8),
      Text(hint, textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
              fontSize: 13, color: AppColors.mutedBrown.withValues(alpha: 0.7), height: 1.5)),
    ],
  ));
}
