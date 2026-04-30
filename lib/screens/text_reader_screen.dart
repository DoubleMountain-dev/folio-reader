// lib/screens/text_reader_screen.dart
//
// ReadEra-style paged reader:
// - Text is split into fixed-size pages that fit exactly one screen
// - Swipe left/right OR tap left/right edge to turn pages
// - PageView for smooth transitions
// - Tap center to show/hide UI bars
// - Long-press word for dictionary
// - Tap-and-hold selection for quotes

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../providers/library_provider.dart';
import '../utils/app_theme.dart';
import 'reading_settings_screen.dart';
import 'search_in_book_screen.dart';

class TextReaderScreen extends StatefulWidget {
  final BookDocument book;
  const TextReaderScreen({super.key, required this.book});
  @override State<TextReaderScreen> createState() => _TextReaderScreenState();
}

class _TextReaderScreenState extends State<TextReaderScreen> {
  late PageController _pageCtrl;
  bool _showBars = false;
  int _currentPage = 0;
  List<_Page> _pages = [];
  bool _built = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().openBook(widget.book.id, widget.book.title);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // Build all pages once we know the screen size
  void _buildPages(Size screenSize, ReadingSettings settings) {
    if (_built) return;
    _built = true;

    final style = _bodyTextStyle(settings, Colors.black);
    final padding = const EdgeInsets.fromLTRB(20, 52, 20, 60);
    final textWidth  = screenSize.width  - padding.horizontal;
    final textHeight = screenSize.height - padding.vertical;

    final raw = <_Page>[];
    int chapterPageStart = 0;

    for (int ci = 0; ci < widget.book.chapters.length; ci++) {
      final ch = widget.book.chapters[ci];
      final paras = _splitParagraphs(ch.content);

      // First page of chapter always starts with the chapter title
      bool firstPageOfChapter = true;
      final buf = <_Paragraph>[];
      double usedHeight = 0;

      for (int pi = 0; pi < paras.length; pi++) {
        final para = paras[pi];
        final paraHeight = _measurePara(para, textWidth, textHeight, style);

        if (usedHeight + paraHeight > textHeight && buf.isNotEmpty) {
          // Flush current page
          raw.add(_Page(
            chapterIndex: ci,
            chapterTitle: ch.title,
            paragraphs: List.from(buf),
            isFirstOfChapter: firstPageOfChapter,
          ));
          firstPageOfChapter = false;
          buf.clear();
          usedHeight = 0;
        }

        // If single paragraph is taller than page, split it by sentences
        if (paraHeight > textHeight) {
          final chunks = _splitParaToFit(para, textWidth, textHeight, style);
          for (final chunk in chunks) {
            final h = _measurePara(chunk, textWidth, textHeight, style);
            if (usedHeight + h > textHeight && buf.isNotEmpty) {
              raw.add(_Page(
                chapterIndex: ci,
                chapterTitle: ch.title,
                paragraphs: List.from(buf),
                isFirstOfChapter: firstPageOfChapter,
              ));
              firstPageOfChapter = false;
              buf.clear();
              usedHeight = 0;
            }
            buf.add(chunk);
            usedHeight += h;
          }
        } else {
          buf.add(para);
          usedHeight += paraHeight;
        }
      }

      if (buf.isNotEmpty) {
        raw.add(_Page(
          chapterIndex: ci,
          chapterTitle: ch.title,
          paragraphs: List.from(buf),
          isFirstOfChapter: firstPageOfChapter,
        ));
      }

      // Record mapping: chapter ci starts at raw.length - (pages added for this chapter)
      if (ci == 0 || chapterPageStart == 0) chapterPageStart = 0;
    }

    // Find starting page from saved progress
    int startPage = 0;
    if (widget.book.currentPage > 0 && raw.isNotEmpty) {
      // Map saved page number to page index
      final savedChapter = _findChapterIndex();
      for (int i = 0; i < raw.length; i++) {
        if (raw[i].chapterIndex >= savedChapter) { startPage = i; break; }
      }
    }

    setState(() {
      _pages = raw;
      _currentPage = startPage.clamp(0, raw.isEmpty ? 0 : raw.length - 1);
    });

    if (startPage > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageCtrl.hasClients) {
          _pageCtrl.jumpToPage(startPage);
        }
      });
    }
  }

  int _findChapterIndex() {
    if (widget.book.chapters.isEmpty) return 0;
    int ci = 0;
    for (int i = 0; i < widget.book.chapters.length; i++) {
      if (widget.book.chapters[i].startPage <= widget.book.currentPage) ci = i;
    }
    return ci;
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    if (_pages.isNotEmpty && page < _pages.length) {
      final p = _pages[page];
      final ch = widget.book.chapters.isNotEmpty
          ? widget.book.chapters[p.chapterIndex]
          : null;
      context.read<LibraryProvider>().updateProgress(
        widget.book.id,
        ch?.startPage ?? page,
        totalPages: _pages.length,
      );
    }
  }

  void _saveQuote(String text) {
    final ch = _pages.isNotEmpty ? _pages[_currentPage] : null;
    context.read<LibraryProvider>().addQuote(widget.book.id, DocQuote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      chapter: ch?.chapterTitle ?? '',
      page: _currentPage,
    ));
    _snack('Quote saved', Icons.format_quote, AppColors.accentRed);
  }

  void _addBookmark() {
    final ch = _pages.isNotEmpty ? _pages[_currentPage] : null;
    context.read<LibraryProvider>().addBookmark(widget.book.id, DocBookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chapter: ch?.chapterTitle ?? 'Page $_currentPage',
      page: _currentPage,
      preview: ch?.paragraphs.firstOrNull?.text ?? '',
    ));
    _snack('Bookmark added', Icons.bookmark, AppColors.woodBrown);
  }

  void _snack(String msg, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      duration: const Duration(seconds: 2),
    ));
  }

  TextStyle _bodyTextStyle(ReadingSettings s, Color color) {
    switch (s.fontFamily) {
      case 'sans': return GoogleFonts.dmSans(fontSize: s.fontSize, height: s.lineHeight, color: color);
      case 'mono': return TextStyle(fontFamily: 'monospace', fontSize: s.fontSize, height: s.lineHeight, color: color);
      default:     return GoogleFonts.playfairDisplay(fontSize: s.fontSize, height: s.lineHeight, color: color);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<LibraryProvider>().settings;
    final bg = settings.backgroundColor;
    final fg = settings.textColor;
    final size = MediaQuery.of(context).size;

    // Build pages on first frame
    if (!_built) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _buildPages(size, settings));
    }

    final total = _pages.length;
    final pct   = total > 0 ? (_currentPage + 1) / total : 0.0;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        // ── Page viewer ────────────────────────────────────────────────────────
        if (_pages.isEmpty)
          Center(child: _pages.isEmpty && _built
              ? Text('No content', style: GoogleFonts.dmSans(color: fg))
              : CircularProgressIndicator(color: AppColors.accentRed))
        else
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: _onPageChanged,
            itemCount: _pages.length,
            itemBuilder: (ctx, i) => _PageView(
              page: _pages[i],
              settings: settings,
              textColor: fg,
              bgColor: bg,
              onTapLeft:   () => _pageCtrl.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
              onTapRight:  () => _pageCtrl.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
              onTapCenter: () => setState(() => _showBars = !_showBars),
              onSaveQuote: _saveQuote,
            ),
          ),

        // ── Top bar ────────────────────────────────────────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          top: _showBars ? 0 : -80, left: 0, right: 0,
          child: Container(
            color: bg.withValues(alpha: 0.95),
            child: SafeArea(bottom: false, child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: fg, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(child: Text(
                _pages.isNotEmpty ? _pages[_currentPage].chapterTitle : widget.book.title,
                style: GoogleFonts.dmSans(fontSize: 13, color: fg.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              )),
              IconButton(
                icon: Icon(Icons.search, color: fg, size: 22),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SearchInBookScreen(
                    book: widget.book,
                    onNavigate: (ci) {
                      // Jump to first page of that chapter
                      final idx = _pages.indexWhere((p) => p.chapterIndex >= ci);
                      if (idx != -1) _pageCtrl.jumpToPage(idx);
                    },
                  ),
                )),
              ),
              IconButton(
                icon: Icon(Icons.bookmark_outline, color: fg, size: 22),
                onPressed: _addBookmark,
              ),
              IconButton(
                icon: Icon(Icons.tune_rounded, color: fg, size: 22),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ReadingSettingsScreen()));
                  // Rebuild pages with new settings
                  setState(() => _built = false);
                  WidgetsBinding.instance.addPostFrameCallback((_) => _buildPages(size, settings));
                },
              ),
            ])),
          ),
        ),

        // ── Bottom bar (page number + progress) ───────────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          bottom: _showBars ? 0 : -60, left: 0, right: 0,
          child: Container(
            color: bg.withValues(alpha: 0.95),
            child: SafeArea(top: false, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Text(
                  '${_currentPage + 1}',
                  style: GoogleFonts.dmSans(fontSize: 11, color: fg.withValues(alpha: 0.5)),
                ),
                const SizedBox(width: 10),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: fg.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(AppColors.accentRed),
                    minHeight: 3,
                  ),
                )),
                const SizedBox(width: 10),
                Text(
                  '$total',
                  style: GoogleFonts.dmSans(fontSize: 11, color: fg.withValues(alpha: 0.5)),
                ),
              ]),
            )),
          ),
        ),
      ]),
    );
  }
}

// ─── Page model ───────────────────────────────────────────────────────────────

class _Page {
  final int chapterIndex;
  final String chapterTitle;
  final List<_Paragraph> paragraphs;
  final bool isFirstOfChapter;
  _Page({required this.chapterIndex, required this.chapterTitle,
    required this.paragraphs, required this.isFirstOfChapter});
}

class _Paragraph {
  final String text;
  final bool isHeading;
  final bool isSeparator;
  _Paragraph({required this.text, this.isHeading = false, this.isSeparator = false});
}

// ─── Page splitting helpers ───────────────────────────────────────────────────

List<_Paragraph> _splitParagraphs(String content) {
  final result = <_Paragraph>[];
  final raw = content.split(RegExp(r'\n{2,}'));
  for (final raw_p in raw) {
    final p = raw_p.trim();
    if (p.isEmpty) continue;
    if (p == '* * *' || p == '***' || p == '---') {
      result.add(_Paragraph(text: '* * *', isSeparator: true));
      continue;
    }
    final isHeading = (p.length < 80 && p == p.toUpperCase() && p.replaceAll(RegExp(r'[^A-Z]'), '').length > 3)
        || p.startsWith('**');
    final display = p.replaceAll(RegExp(r'^\*\*|\*\*$'), '').replaceAll('\n', ' ').trim();
    result.add(_Paragraph(text: display, isHeading: isHeading));
  }
  return result;
}

double _measurePara(_Paragraph para, double width, double maxHeight, TextStyle baseStyle) {
  if (para.isSeparator) return 40.0;
  final style = para.isHeading
      ? baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 16) * 1.15, fontWeight: FontWeight.w700)
      : baseStyle;
  final tp = TextPainter(
    text: TextSpan(text: para.text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: null,
  )..layout(maxWidth: width);
  return tp.height + (para.isHeading ? 24.0 : 16.0); // bottom padding per paragraph
}

List<_Paragraph> _splitParaToFit(_Paragraph para, double width, double maxHeight, TextStyle style) {
  // Split by sentences and group into sub-paragraphs that fit
  final sentences = para.text.split(RegExp(r'(?<=[.!?])\s+'));
  final chunks = <_Paragraph>[];
  final buf = StringBuffer();
  double h = 0;

  for (final sentence in sentences) {
    final test = buf.isEmpty ? sentence : '${buf.toString()} $sentence';
    final testPara = _Paragraph(text: test, isHeading: para.isHeading);
    final testH = _measurePara(testPara, width, maxHeight, style);

    if (testH > maxHeight && buf.isNotEmpty) {
      chunks.add(_Paragraph(text: buf.toString().trim(), isHeading: para.isHeading));
      buf.clear();
      buf.write(sentence);
      h = _measurePara(_Paragraph(text: sentence), width, maxHeight, style);
    } else {
      if (buf.isNotEmpty) buf.write(' ');
      buf.write(sentence);
      h = testH;
    }
  }
  if (buf.isNotEmpty) chunks.add(_Paragraph(text: buf.toString().trim(), isHeading: para.isHeading));
  return chunks.isEmpty ? [para] : chunks;
}

// ─── Single page widget ───────────────────────────────────────────────────────

class _PageView extends StatelessWidget {
  final _Page page;
  final ReadingSettings settings;
  final Color textColor, bgColor;
  final VoidCallback onTapLeft, onTapRight, onTapCenter;
  final void Function(String) onSaveQuote;

  const _PageView({
    required this.page, required this.settings, required this.textColor,
    required this.bgColor, required this.onTapLeft, required this.onTapRight,
    required this.onTapCenter, required this.onSaveQuote,
  });

  TextStyle get _body {
    switch (settings.fontFamily) {
      case 'sans': return GoogleFonts.dmSans(fontSize: settings.fontSize, height: settings.lineHeight, color: textColor);
      case 'mono': return TextStyle(fontFamily: 'monospace', fontSize: settings.fontSize, height: settings.lineHeight, color: textColor);
      default:     return GoogleFonts.playfairDisplay(fontSize: settings.fontSize, height: settings.lineHeight, color: textColor);
    }
  }

  TextStyle get _heading => _body.copyWith(
    fontSize: (settings.fontSize) * 1.15,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap zones: left 25% = prev, center 50% = toggle bars, right 25% = next
      onTapDown: (details) {
        final x = details.globalPosition.dx;
        final w = MediaQuery.of(context).size.width;
        if (x < w * 0.25) {
          onTapLeft();
        } else if (x > w * 0.75) {
          onTapRight();
        } else {
          onTapCenter();
        }
      },
      child: Container(
        color: bgColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                // Chapter title header (only first page of chapter)
                if (page.isFirstOfChapter) ...[
                  Center(child: Text(
                    page.chapterTitle.toUpperCase(),
                    style: GoogleFonts.dmSans(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.accentRed, letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  )),
                  const SizedBox(height: 4),
                  Center(child: Container(
                    width: 40, height: 1.5,
                    color: AppColors.accentRed.withValues(alpha: 0.4),
                  )),
                  const SizedBox(height: 16),
                ],

                // Paragraph content
                Expanded(
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: page.paragraphs.map((para) {
                        if (para.isSeparator) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: Text('* * *',
                              style: GoogleFonts.dmSans(fontSize: 14,
                                color: textColor.withValues(alpha: 0.4), letterSpacing: 4))),
                          );
                        }
                        return Padding(
                          padding: EdgeInsets.only(bottom: para.isHeading ? 10 : 10),
                          child: _SelectableParaText(
                            text: para.text,
                            style: para.isHeading ? _heading : _body,
                            onSaveQuote: onSaveQuote,
                            textColor: textColor,
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Selectable paragraph with quote + dictionary ─────────────────────────────

class _SelectableParaText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final void Function(String) onSaveQuote;
  final Color textColor;

  const _SelectableParaText({
    required this.text, required this.style,
    required this.onSaveQuote, required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: style,
      onSelectionChanged: (sel, cause) {
        if (sel.isCollapsed) return;
        final s = sel.start.clamp(0, text.length);
        final e = sel.end.clamp(0, text.length);
        if (e <= s) return;
        final selected = text.substring(s, e).trim();
        if (selected.length > 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) _showMenu(context, selected);
          });
        }
      },
    );
  }

  void _showMenu(BuildContext context, String selected) {
    final isSingleWord = !selected.contains(' ') && selected.length <= 30;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paperWarm,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          if (isSingleWord) ...[
            Text('Definition', style: GoogleFonts.playfairDisplay(
                fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.inkDark)),
            const SizedBox(height: 4),
            Text('"$selected"', style: GoogleFonts.dmSans(
                fontSize: 13, color: AppColors.accentRed, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            _DictionaryWidget(word: selected),
            const SizedBox(height: 16),
          ] else ...[
            Text('Selected text', style: GoogleFonts.playfairDisplay(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.inkDark)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.creamLight,
                borderRadius: BorderRadius.circular(8),
                border: const Border(left: BorderSide(color: AppColors.accentRed, width: 3))),
              child: Text(
                '"${selected.length > 200 ? "${selected.substring(0, 200)}..." : selected}"',
                style: GoogleFonts.playfairDisplay(fontSize: 13, fontStyle: FontStyle.italic,
                    color: const Color(0xFF5A4E3A), height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
          ],

          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () { Navigator.pop(context); onSaveQuote(selected); },
            icon: const Icon(Icons.format_quote, size: 18),
            label: Text('Save as Quote', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )),
        ]),
      ),
    );
  }
}

// ─── Dictionary widget ────────────────────────────────────────────────────────

class _DictionaryWidget extends StatefulWidget {
  final String word;
  const _DictionaryWidget({required this.word});
  @override State<_DictionaryWidget> createState() => _DictionaryWidgetState();
}

class _DictionaryWidgetState extends State<_DictionaryWidget> {
  String? _def, _pos;
  bool _loading = true, _notFound = false;

  @override void initState() { super.initState(); _lookup(); }

  void _lookup() {
    try {
      final xhr = html.HttpRequest();
      xhr.open('GET', 'https://api.dictionaryapi.dev/api/v2/entries/en/${widget.word.toLowerCase()}');
      xhr.onLoad.listen((_) {
        if (!mounted) return;
        if (xhr.status == 200) {
          final body = xhr.responseText ?? '';
          final defM = RegExp(r'"definition":"([^"]+)"').firstMatch(body);
          final posM = RegExp(r'"partOfSpeech":"([^"]+)"').firstMatch(body);
          setState(() {
            _def = defM?.group(1) ?? 'No definition';
            _pos = posM?.group(1);
            _loading = false;
          });
        } else {
          setState(() { _notFound = true; _loading = false; });
        }
      });
      xhr.onError.listen((_) { if (mounted) setState(() { _notFound = true; _loading = false; }); });
      xhr.send();
    } catch (_) {
      if (mounted) setState(() { _notFound = true; _loading = false; });
    }
  }

  @override Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 36,
        child: Center(child: SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentRed))));
    if (_notFound) return Text('Not found in dictionary.',
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.mutedBrown, fontStyle: FontStyle.italic));
    return Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.creamLight, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_pos != null) Text(_pos!.toUpperCase(), style: GoogleFonts.dmSans(
            fontSize: 10, color: AppColors.accentRed, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        if (_pos != null) const SizedBox(height: 4),
        Text(_def!, style: GoogleFonts.playfairDisplay(fontSize: 14, color: AppColors.inkDark, height: 1.5)),
      ]));
  }
}
