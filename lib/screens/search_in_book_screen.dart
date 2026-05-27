// lib/screens/search_in_book_screen.dart
// Search within book text with result highlighting.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/document.dart';
import '../utils/app_theme.dart';

class SearchInBookScreen extends StatefulWidget {
  final BookDocument book;
  final void Function(int chapterIndex) onNavigate;
  const SearchInBookScreen({super.key, required this.book, required this.onNavigate});
  @override State<SearchInBookScreen> createState() => _SearchInBookScreenState();
}

class _SearchInBookScreenState extends State<SearchInBookScreen> {
  final _ctrl = TextEditingController();
  List<_SearchResult> _results = [];

  void _search(String query) {
    if (query.trim().isEmpty) { setState(() => _results = []); return; }
    final q = query.toLowerCase();
    final results = <_SearchResult>[];
    for (int ci = 0; ci < widget.book.chapters.length; ci++) {
      final ch = widget.book.chapters[ci];
      final text = ch.content.toLowerCase();
      int idx = 0;
      while (true) {
        idx = text.indexOf(q, idx);
        if (idx == -1) break;
        // Extract context around match
        final start = (idx - 60).clamp(0, text.length);
        final end   = (idx + q.length + 60).clamp(0, text.length);
        results.add(_SearchResult(
          chapterIndex: ci, chapterTitle: ch.title,
          matchStart: idx - start, matchEnd: idx - start + q.length,
          context: ch.content.substring(start, end),
        ));
        idx += q.length;
        if (results.length > 100) break;
      }
    }
    setState(() => _results = results);
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paperWarm,
      appBar: AppBar(
        backgroundColor: AppColors.woodBrown,
        iconTheme: const IconThemeData(color: AppColors.paperWarm),
        title: TextField(
          controller: _ctrl, onChanged: _search, autofocus: true,
          style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.paperWarm),
          decoration: InputDecoration(
            hintText: 'Search in book...',
            hintStyle: GoogleFonts.dmSans(color: AppColors.paperWarm.withValues(alpha: 0.5)),
            border: InputBorder.none),
        ),
        actions: [
          if (_results.isNotEmpty)
            Padding(padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text('${_results.length} results',
                  style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.paperWarm.withValues(alpha: 0.7))))),
        ],
      ),
      body: _results.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.search, size: 56, color: AppColors.mutedBrown.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(_ctrl.text.isEmpty ? 'Type to search...' : 'No results found',
                  style: GoogleFonts.playfairDisplay(fontSize: 18, color: AppColors.mutedBrown)),
            ]))
          : ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE8E0D0), indent: 16, endIndent: 16),
              itemBuilder: (_, i) {
                final r = _results[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(r.chapterTitle, style: GoogleFonts.dmSans(
                      fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentRed)),
                  subtitle: _HighlightedText(
                    text: (r.context.startsWith('...') ? '' : '') + r.context + '...',
                    query: _ctrl.text.trim(),
                    matchStart: r.matchStart, matchEnd: r.matchEnd,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNavigate(r.chapterIndex);
                  },
                );
              },
            ),
    );
  }
}

class _SearchResult {
  final int chapterIndex, matchStart, matchEnd;
  final String chapterTitle, context;
  const _SearchResult({required this.chapterIndex, required this.chapterTitle,
    required this.matchStart, required this.matchEnd, required this.context});
}

class _HighlightedText extends StatelessWidget {
  final String text, query;
  final int matchStart, matchEnd;
  const _HighlightedText({required this.text, required this.query,
    required this.matchStart, required this.matchEnd});

  @override Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.inkDark, height: 1.5));
    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    int idx = 0;
    while (true) {
      final found = lower.indexOf(q, idx);
      if (found == -1) { spans.add(TextSpan(text: text.substring(idx))); break; }
      if (found > idx) spans.add(TextSpan(text: text.substring(idx, found)));
      spans.add(TextSpan(
        text: text.substring(found, found + q.length),
        style: const TextStyle(backgroundColor: Color(0xFFFFE082), fontWeight: FontWeight.w700),
      ));
      idx = found + q.length;
    }
    return RichText(text: TextSpan(
      style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.inkDark, height: 1.5),
      children: spans,
    ), maxLines: 3, overflow: TextOverflow.ellipsis);
  }
}
