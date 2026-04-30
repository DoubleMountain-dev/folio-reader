// lib/screens/library_screen.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../models/document.dart';
import '../utils/app_theme.dart';
import 'book_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchCtrl = TextEditingController();

  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _importFiles(BuildContext context) {
    final input = html.FileUploadInputElement()
      ..accept = '.epub,.fb2,.txt,.html,.htm,.pdf'
      ..multiple = true;
    input.onChange.listen((_) async {
      final files = input.files;
      if (files == null || files.isEmpty) return;
      final entries = <MapEntry<String, Uint8List>>[];
      for (final file in files) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoadEnd.first;
        entries.add(MapEntry(file.name, Uint8List.fromList(reader.result as List<int>)));
      }
      if (!context.mounted) return;
      final provider = context.read<LibraryProvider>();
      final added = await provider.importFiles(entries);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(added.isEmpty
            ? (provider.error ?? 'No new books added')
            : '${added.length} book${added.length > 1 ? "s" : ""} added'),
        backgroundColor: added.isEmpty ? Colors.red.shade700 : AppColors.spineForest,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    });
    input.click();
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final books = lib.books;
    final reading = lib.currentlyReading;

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: CustomScrollView(slivers: [
        // ── App Bar ──────────────────────────────────────────────────────────
        SliverAppBar(pinned: true, expandedHeight: 90, backgroundColor: AppColors.woodBrown,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Folio', style: GoogleFonts.playfairDisplay(
                  fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.paperWarm)),
              Row(children: [
                if (lib.isLoading) const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentRed)),
                IconButton(icon: const Icon(Icons.filter_list, color: AppColors.paperWarm, size: 22),
                    onPressed: () => _showFilterSheet(context)),
                IconButton(icon: const Icon(Icons.add, color: AppColors.accentRed, size: 26),
                    onPressed: () => _importFiles(context)),
              ]),
            ]),
          ),
        ),

        // ── Search bar ────────────────────────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Expanded(child: Container(
              height: 42,
              decoration: BoxDecoration(color: AppColors.paperWarm,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.creamLight)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Icon(Icons.search, color: AppColors.mutedBrown, size: 18),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _searchCtrl,
                  onChanged: (q) => context.read<LibraryProvider>().setSearch(q),
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.inkDark),
                  decoration: InputDecoration(
                    hintText: 'Search by title or author...',
                    hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.mutedBrown),
                    border: InputBorder.none, isDense: true),
                )),
                if (lib.searchQuery.isNotEmpty)
                  GestureDetector(onTap: () {
                    _searchCtrl.clear();
                    context.read<LibraryProvider>().setSearch('');
                  }, child: Icon(Icons.close, size: 16, color: AppColors.mutedBrown)),
              ]),
            )),
          ]),
        )),

        // ── Active filters chips ──────────────────────────────────────────────
        if (lib.filterTag != null || lib.filterCollection != null)
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(children: [
              if (lib.filterTag != null) _FilterChip(
                label: '# ${lib.filterTag}',
                onRemove: () => context.read<LibraryProvider>().setFilterTag(null)),
              if (lib.filterCollection != null) _FilterChip(
                label: lib.bookCollections.firstWhere(
                    (c) => c.id == lib.filterCollection, orElse: () =>
                    BookCollection(id: '', name: 'Unknown', color: '#000')).name,
                onRemove: () => context.read<LibraryProvider>().setFilterCollection(null)),
            ]),
          )),

        if (books.isEmpty && lib.collections.isEmpty)
          SliverFillRemaining(child: _EmptyState(onImport: () => _importFiles(context)))
        else ...[
          // Currently reading
          if (reading.isNotEmpty && lib.searchQuery.isEmpty && lib.filterTag == null) ...[
            SliverToBoxAdapter(child: _SectionHeader(title: 'Reading Now', count: reading.length)),
            SliverToBoxAdapter(child: SizedBox(height: 220,
              child: ListView.builder(scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: reading.length,
                itemBuilder: (ctx, i) => _ReadingCard(book: reading[i])))),
            SliverToBoxAdapter(child: _WoodShelf()),
          ],

          SliverToBoxAdapter(child: _SectionHeader(title: 'Library', count: books.length)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.58),
              delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _BookGridCard(book: books[i]), childCount: books.length),
            ),
          ),
        ],
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _importFiles(context),
        backgroundColor: AppColors.accentRed, foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Add Book', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final lib = context.read<LibraryProvider>();
    showModalBottomSheet(context: context, backgroundColor: AppColors.paperWarm, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        final lib2 = ctx.watch<LibraryProvider>();
        return Padding(padding: const EdgeInsets.all(20), child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Filter & Sort', style: GoogleFonts.playfairDisplay(
              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.inkDark)),
          const SizedBox(height: 16),

          Text('SORT BY', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600,
              color: AppColors.mutedBrown, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: SortOrder.values.map((s) {
            final labels = {
              SortOrder.dateAdded: 'Date Added', SortOrder.lastOpened: 'Last Opened',
              SortOrder.title: 'Title', SortOrder.author: 'Author', SortOrder.progress: 'Progress',
            };
            final sel = lib2.sortOrder == s;
            return ChoiceChip(label: Text(labels[s]!), selected: sel,
              selectedColor: AppColors.accentRed, labelStyle: GoogleFonts.dmSans(
                  fontSize: 12, color: sel ? Colors.white : AppColors.inkDark),
              onSelected: (_) { context.read<LibraryProvider>().setSortOrder(s); });
          }).toList()),
          const SizedBox(height: 16),

          if (lib.allTags.isNotEmpty) ...[
            Text('TAGS', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.mutedBrown, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: lib.allTags.map((tag) {
              final sel = lib2.filterTag == tag;
              return ChoiceChip(label: Text('# $tag'), selected: sel,
                selectedColor: AppColors.spineNavy, labelStyle: GoogleFonts.dmSans(
                    fontSize: 12, color: sel ? Colors.white : AppColors.inkDark),
                onSelected: (_) { context.read<LibraryProvider>().setFilterTag(sel ? null : tag); });
            }).toList()),
            const SizedBox(height: 16),
          ],

          if (lib.bookCollections.isNotEmpty) ...[
            Text('COLLECTIONS', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.mutedBrown, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: lib.bookCollections.map((col) {
              final sel = lib2.filterCollection == col.id;
              final color = Color(int.parse(col.color.replaceFirst('#', '0xFF')));
              return ChoiceChip(label: Text(col.name), selected: sel,
                selectedColor: color, labelStyle: GoogleFonts.dmSans(
                    fontSize: 12, color: sel ? Colors.white : AppColors.inkDark),
                onSelected: (_) { context.read<LibraryProvider>().setFilterCollection(sel ? null : col.id); });
            }).toList()),
            const SizedBox(height: 16),
          ],

          Row(children: [
            Expanded(child: TextButton(
              onPressed: () { context.read<LibraryProvider>().clearFilters(); Navigator.pop(ctx); },
              child: Text('Clear All', style: GoogleFonts.dmSans(color: AppColors.accentRed)))),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed, foregroundColor: Colors.white),
              child: Text('Apply', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)))),
          ]),
          const SizedBox(height: 8),
        ]));
      }),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _FilterChip({required this.label, required this.onRemove});
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8, bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: AppColors.accentRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.accentRed)),
      const SizedBox(width: 4),
      GestureDetector(onTap: onRemove, child: Icon(Icons.close, size: 14, color: AppColors.accentRed)),
    ]),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onImport;
  const _EmptyState({required this.onImport});
  @override Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.menu_book_rounded, size: 80, color: AppColors.mutedBrown.withValues(alpha: 0.3)),
    const SizedBox(height: 20),
    Text('Your library is empty', style: GoogleFonts.playfairDisplay(
        fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.mutedBrown)),
    const SizedBox(height: 8),
    Text('EPUB, FB2, TXT, HTML, PDF', style: GoogleFonts.dmSans(
        fontSize: 14, color: AppColors.mutedBrown.withValues(alpha: 0.7))),
    const SizedBox(height: 32),
    ElevatedButton.icon(onPressed: onImport, icon: const Icon(Icons.file_open_rounded),
      label: Text('Open Books', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed,
          foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)))),
    const SizedBox(height: 8),
    Text('You can select multiple files at once', style: GoogleFonts.dmSans(
        fontSize: 12, color: AppColors.mutedBrown.withValues(alpha: 0.5))),
  ]));
}

class _SectionHeader extends StatelessWidget {
  final String title; final int count;
  const _SectionHeader({required this.title, required this.count});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Row(children: [
      Text(title.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 11,
          fontWeight: FontWeight.w600, color: AppColors.mutedBrown, letterSpacing: 1.2)),
      const SizedBox(width: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppColors.accentRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: GoogleFonts.dmSans(
            fontSize: 10, color: AppColors.accentRed, fontWeight: FontWeight.w600))),
    ]),
  );
}

class _WoodShelf extends StatelessWidget {
  @override Widget build(BuildContext context) => Container(height: 12,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(color: const Color(0xFFC8B89A),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4, offset: const Offset(0, 3))]));
}

class _ReadingCard extends StatelessWidget {
  final BookDocument book;
  const _ReadingCard({required this.book});
  @override Widget build(BuildContext context) {
    final color = Color(int.parse(book.spineColor.replaceFirst('#', '0xFF')));
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: book))),
      child: Container(width: 140, margin: const EdgeInsets.only(right: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 160, decoration: BoxDecoration(color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4),
                  blurRadius: 12, offset: const Offset(4, 6))]),
            child: Stack(children: [
              Positioned(left: 0, top: 0, bottom: 0, width: 8, child: Container(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8))))),
              Positioned(top: 8, right: 8, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)),
                child: Text(book.formatLabel, style: GoogleFonts.dmSans(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)))),
              Center(child: Padding(padding: const EdgeInsets.all(12), child: Text(book.title,
                  textAlign: TextAlign.center, style: GoogleFonts.playfairDisplay(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3)))),
              Positioned(bottom: 8, left: 8, right: 8, child: Text(book.author,
                  textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 9, color: Colors.white70))),
            ])),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(
              value: book.progress, backgroundColor: AppColors.creamLight,
              valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 3)),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('p. ${book.currentPage}', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.mutedBrown)),
            Text('${(book.progress * 100).round()}%', style: GoogleFonts.dmSans(
                fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ]),
        ])),
    );
  }
}

class _BookGridCard extends StatelessWidget {
  final BookDocument book;
  const _BookGridCard({required this.book});
  @override Widget build(BuildContext context) {
    final color = Color(int.parse(book.spineColor.replaceFirst('#', '0xFF')));
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: book))),
      child: Column(children: [
        Expanded(child: Container(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(2, 4))]),
          child: Stack(children: [
            Positioned(left: 0, top: 0, bottom: 0, width: 6,
                child: Container(color: Colors.black.withValues(alpha: 0.2))),
            Positioned(top: 6, right: 6, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)),
              child: Text(book.formatLabel, style: GoogleFonts.dmSans(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w700)))),
            Center(child: Padding(padding: const EdgeInsets.all(8), child: Text(book.title,
                textAlign: TextAlign.center, style: GoogleFonts.dmSans(
                    fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600, height: 1.3)))),
            if (book.progress > 0)
              Positioned(bottom: 0, left: 6, right: 0, height: 3,
                  child: LinearProgressIndicator(value: book.progress,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation(Colors.white54), minHeight: 3)),
          ])),
        ),
        const SizedBox(height: 5),
        Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(fontSize: 9, color: AppColors.inkDark, fontWeight: FontWeight.w500)),
        Text(book.author.split(' ').last, maxLines: 1,
            style: GoogleFonts.dmSans(fontSize: 8, color: AppColors.mutedBrown)),
      ]),
    );
  }
}
