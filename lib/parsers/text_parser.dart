// lib/parsers/text_parser.dart
// TXT and HTML parsers - extract full text content.

import 'dart:typed_data';
import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/document.dart';

// ── TXT Parser ────────────────────────────────────────────────────────────────

class TxtParser {
  static BookDocument parse(String fileName, Uint8List bytes) {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      try {
        content = latin1.decode(bytes);
      } catch (_) {
        content = String.fromCharCodes(bytes);
      }
    }

    // Remove BOM
    if (content.startsWith('\uFEFF')) content = content.substring(1);

    final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll('_', ' ').trim();

    if (content.trim().isEmpty) {
      return BookDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: fileName,
        title: title,
        author: 'Unknown',
        format: DocFormat.txt,
        totalPages: 1,
        chapters: [DocChapter(id: 'ch_0', title: title, startPage: 0, content: 'File is empty.')],
      );
    }

    final chapters = _splitIntoChapters(content, title);
    int pageCounter = 0;
    final docChapters = <DocChapter>[];

    for (int i = 0; i < chapters.length; i++) {
      final text = chapters[i]['text']!;
      final chTitle = chapters[i]['title']!;
      if (text.trim().isEmpty) continue;
      final pages = (text.length / 1800).ceil().clamp(1, 9999);
      docChapters.add(DocChapter(
        id: 'ch_$i',
        title: chTitle,
        startPage: pageCounter,
        content: text.trim(),
      ));
      pageCounter += pages;
    }

    if (docChapters.isEmpty) {
      docChapters.add(DocChapter(
        id: 'ch_0', title: title, startPage: 0, content: content.trim()));
      pageCounter = (content.length / 1800).ceil().clamp(1, 9999);
    }

    return BookDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      title: title,
      author: 'Unknown Author',
      format: DocFormat.txt,
      totalPages: pageCounter,
      chapters: docChapters,
    );
  }

  static List<Map<String, String>> _splitIntoChapters(String content, String docTitle) {
    // Pattern: lines that look like chapter headings
    final chapterRegex = RegExp(
      r'^[\s]*(chapter|part|section|head)\s+.{0,60}$',
      multiLine: true,
      caseSensitive: false,
    );

    final matches = chapterRegex.allMatches(content).toList();

    // Also detect lines of only caps / digits (common chapter headings)
    final capsRegex = RegExp(
      r'^[\s]*[IVX\d]{1,6}[\.\s]+[A-Z].{0,60}$',
      multiLine: true,
    );
    final capsMatches = capsRegex.allMatches(content)
        .where((m) => m.group(0)!.trim().length > 2)
        .toList();

    // Merge and sort all heading matches
    final allMatches = <RegExpMatch>[...matches, ...capsMatches];
    allMatches.sort((a, b) => a.start.compareTo(b.start));

    // Remove duplicates (matches within 10 chars of each other)
    final deduped = <RegExpMatch>[];
    for (final m in allMatches) {
      if (deduped.isEmpty || m.start - deduped.last.start > 10) {
        deduped.add(m);
      }
    }

    if (deduped.isEmpty) {
      // No headings -- split into chunks of ~3000 chars at paragraph boundaries
      return _splitByParagraphs(content, docTitle);
    }

    final chapters = <Map<String, String>>[];

    // Content before first heading
    if (deduped.first.start > 200) {
      final pre = content.substring(0, deduped.first.start).trim();
      if (pre.isNotEmpty) {
        chapters.add({'title': 'Introduction', 'text': pre});
      }
    }

    for (int i = 0; i < deduped.length; i++) {
      final start = deduped[i].start;
      final end   = i + 1 < deduped.length ? deduped[i + 1].start : content.length;
      final headingLine = content.substring(start, content.indexOf('\n', start) == -1
          ? content.length
          : content.indexOf('\n', start)).trim();
      final bodyStart = content.indexOf('\n', start);
      final body = bodyStart == -1 ? '' : content.substring(bodyStart, end).trim();

      chapters.add({'title': headingLine.isEmpty ? 'Chapter ${i + 1}' : headingLine, 'text': body});
    }

    return chapters;
  }

  static List<Map<String, String>> _splitByParagraphs(String content, String docTitle) {
    // Split at double newlines, group into ~5000 char chunks
    final paragraphs = content.split(RegExp(r'\n{2,}'));
    final chunks = <Map<String, String>>[];
    int partNum = 1;
    final buf = StringBuffer();

    for (final para in paragraphs) {
      buf.writeln(para.trim());
      buf.writeln();
      if (buf.length > 5000) {
        chunks.add({'title': chunks.isEmpty ? docTitle : 'Part $partNum', 'text': buf.toString()});
        buf.clear();
        partNum++;
      }
    }
    if (buf.isNotEmpty) {
      chunks.add({'title': chunks.isEmpty ? docTitle : 'Part $partNum', 'text': buf.toString()});
    }
    return chunks.isEmpty ? [{'title': docTitle, 'text': content}] : chunks;
  }
}

// ── HTML File Parser ──────────────────────────────────────────────────────────

class HtmlFileParser {
  static BookDocument parse(String fileName, Uint8List bytes) {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }

    final doc = html_parser.parse(content);

    String title = doc.querySelector('title')?.text.trim()
        ?? fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    String author = doc.querySelector('meta[name="author"]')
            ?.attributes['content'] ?? 'Unknown Author';

    // Remove non-content elements
    doc.querySelectorAll('script, style, nav, header, footer').forEach((e) => e.remove());

    final body = doc.body ?? doc.documentElement;
    if (body == null) {
      return BookDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: fileName, title: title, author: author,
        format: DocFormat.html, totalPages: 1,
        chapters: [DocChapter(id: 'ch_0', title: title, startPage: 0, content: 'Empty document.')],
      );
    }

    // Split by heading elements
    final chapters = <DocChapter>[];
    int pageCounter = 0;

    final headings = body.querySelectorAll('h1, h2, h3');
    if (headings.isEmpty) {
      // No headings -- one big chapter
      final text = _nodeToText(body);
      chapters.add(DocChapter(id: 'ch_0', title: title, startPage: 0, content: text.trim()));
      pageCounter = (text.length / 1800).ceil().clamp(1, 9999);
    } else {
      for (int i = 0; i < headings.length; i++) {
        final heading = headings[i];
        final chTitle = heading.text.trim().isEmpty ? 'Section ${i + 1}' : heading.text.trim();
        final buf = StringBuffer();

        // Collect all sibling elements until next heading
        dom.Element? sibling = heading.nextElementSibling;
        while (sibling != null) {
          final tag = sibling.localName?.toLowerCase() ?? '';
          if (tag == 'h1' || tag == 'h2' || tag == 'h3') break;
          buf.writeln(_nodeToText(sibling));
          sibling = sibling.nextElementSibling;
        }

        final text = buf.toString().trim();
        if (text.isEmpty) continue;
        final pages = (text.length / 1800).ceil().clamp(1, 999);
        chapters.add(DocChapter(id: 'ch_$i', title: chTitle, startPage: pageCounter, content: text));
        pageCounter += pages;
      }
    }

    if (chapters.isEmpty) {
      final text = _nodeToText(body);
      chapters.add(DocChapter(id: 'ch_0', title: title, startPage: 0, content: text.trim()));
      pageCounter = (text.length / 1800).ceil().clamp(1, 9999);
    }

    return BookDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName, title: title, author: author,
      format: DocFormat.html, totalPages: pageCounter, chapters: chapters,
    );
  }

  static String _nodeToText(dom.Element el) {
    final buf = StringBuffer();
    _walk(el, buf);
    return buf.toString()
        .replaceAll(RegExp(r' +'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static void _walk(dom.Node node, StringBuffer buf) {
    if (node.nodeType == dom.Node.TEXT_NODE) {
      final t = (node.text ?? '').replaceAll(RegExp(r'[\r\n\t]+'), ' ');
      if (t.trim().isNotEmpty) buf.write(t);
      return;
    }
    if (node.nodeType != dom.Node.ELEMENT_NODE) return;
    final el = node as dom.Element;
    final tag = el.localName?.toLowerCase() ?? '';

    switch (tag) {
      case 'p': case 'div': case 'section': case 'article':
        buf.write('\n');
        for (final c in el.nodes) _walk(c, buf);
        buf.write('\n');
        break;
      case 'h1': case 'h2': case 'h3': case 'h4':
        buf.write('\n\n');
        for (final c in el.nodes) _walk(c, buf);
        buf.write('\n\n');
        break;
      case 'br': buf.write('\n'); break;
      case 'hr': buf.write('\n\n* * *\n\n'); break;
      case 'li': buf.write('\n- '); for (final c in el.nodes) _walk(c, buf); break;
      case 'script': case 'style': break;
      default: for (final c in el.nodes) _walk(c, buf);
    }
  }
}
