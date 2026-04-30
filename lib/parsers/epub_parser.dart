// lib/parsers/epub_parser.dart
// Parses EPUB 2/3 from raw bytes. Extracts full HTML chapter bodies as text.

import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/document.dart';

class EpubParser {
  static BookDocument parse(String fileName, Uint8List bytes) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      return _error(fileName, 'Could not unzip EPUB: $e');
    }

    // 1. Read container.xml to find OPF path
    final containerXml = _readFile(archive, 'META-INF/container.xml');
    if (containerXml == null) return _error(fileName, 'Missing META-INF/container.xml');

    String opfPath;
    try {
      final containerDoc = XmlDocument.parse(containerXml);
      opfPath = containerDoc
              .findAllElements('rootfile')
              .firstOrNull
              ?.getAttribute('full-path') ??
          'content.opf';
    } catch (_) {
      opfPath = 'content.opf';
    }

    // OPF directory is the base path for resolving relative hrefs
    final opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
        : '';

    // 2. Parse OPF
    final opfContent = _readFile(archive, opfPath);
    if (opfContent == null) return _error(fileName, 'Missing OPF file at $opfPath');

    String title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    String author = 'Unknown Author';
    final manifest = <String, String>{};    // id -> href
    final spineIds = <String>[];

    try {
      final opfDoc = XmlDocument.parse(opfContent);

      // Metadata
      try {
        final meta = opfDoc.findAllElements('metadata').first;
        final t = meta.findElements('dc:title').firstOrNull ??
            meta.findElements('title').firstOrNull;
        if (t != null && t.innerText.trim().isNotEmpty) {
          title = t.innerText.trim();
        }
        final a = meta.findElements('dc:creator').firstOrNull ??
            meta.findElements('creator').firstOrNull;
        if (a != null && a.innerText.trim().isNotEmpty) {
          author = a.innerText.trim();
        }
      } catch (_) {}

      // Manifest: build id -> href map
      try {
        final manifestEl = opfDoc.findAllElements('manifest').first;
        for (final item in manifestEl.findElements('item')) {
          final id   = item.getAttribute('id') ?? '';
          final href = item.getAttribute('href') ?? '';
          if (id.isNotEmpty && href.isNotEmpty) {
            manifest[id] = href;
          }
        }
      } catch (_) {}

      // Spine: reading order
      try {
        final spineEl = opfDoc.findAllElements('spine').first;
        for (final ref in spineEl.findElements('itemref')) {
          final idref = ref.getAttribute('idref') ?? '';
          if (idref.isNotEmpty) spineIds.add(idref);
        }
      } catch (_) {}
    } catch (e) {
      return _error(fileName, 'Could not parse OPF: $e');
    }

    if (spineIds.isEmpty) {
      return _error(fileName, 'EPUB spine is empty -- no reading order found.');
    }

    // 3. Build chapters from spine items
    final chapters = <DocChapter>[];
    int pageCounter = 0;

    for (int i = 0; i < spineIds.length; i++) {
      final href = manifest[spineIds[i]];
      if (href == null) continue;

      // Resolve path relative to OPF directory
      // Handle URL-encoded characters and fragments (#anchor)
      final cleanHref = Uri.decodeFull(href.split('#').first);
      final fullPath = cleanHref.startsWith('/')
          ? cleanHref.substring(1)
          : '$opfDir$cleanHref';

      final chapterHtml = _readFile(archive, fullPath);
      if (chapterHtml == null) continue;

      // Parse HTML and extract all text
      final parsed = _parseHtml(chapterHtml);
      final text = parsed['text'] ?? '';
      final chTitle = parsed['title'] ?? 'Chapter ${i + 1}';

      // Skip items with very little content (usually nav/toc pages)
      if (text.trim().length < 50) continue;

      final pages = (text.length / 1800).ceil().clamp(1, 999);
      chapters.add(DocChapter(
        id: 'ch_$i',
        title: chTitle,
        startPage: pageCounter,
        content: text.trim(),
      ));
      pageCounter += pages;
    }

    if (chapters.isEmpty) {
      // Last resort: dump all text files in archive
      final allText = StringBuffer();
      for (final file in archive.files) {
        if (file.name.endsWith('.html') || file.name.endsWith('.xhtml') || file.name.endsWith('.htm')) {
          try {
            final content = utf8.decode(file.content as List<int>, allowMalformed: true);
            final parsed = _parseHtml(content);
            allText.writeln(parsed['text'] ?? '');
          } catch (_) {}
        }
      }
      final text = allText.toString().trim();
      chapters.add(DocChapter(
        id: 'ch_0',
        title: title,
        startPage: 0,
        content: text.isEmpty ? 'Could not extract text from EPUB.' : text,
      ));
      pageCounter = (text.length / 1800).ceil().clamp(1, 9999);
    }

    return BookDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      title: title,
      author: author,
      format: DocFormat.epub,
      totalPages: pageCounter,
      chapters: chapters,
    );
  }

  // Read a file from the archive by path, trying variations
  static String? _readFile(Archive archive, String path) {
    final normPath = path.replaceAll('\\', '/').replaceAll('//', '/');
    // Try exact match first
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final normName = file.name.replaceAll('\\', '/');
      if (normName == normPath || normName == '/$normPath') {
        try {
          return utf8.decode(file.content as List<int>, allowMalformed: true);
        } catch (_) {
          return String.fromCharCodes(file.content as List<int>);
        }
      }
    }
    // Try suffix match (handles different root paths)
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final normName = file.name.replaceAll('\\', '/');
      if (normName.endsWith('/$normPath') || normName.endsWith(normPath)) {
        try {
          return utf8.decode(file.content as List<int>, allowMalformed: true);
        } catch (_) {
          return String.fromCharCodes(file.content as List<int>);
        }
      }
    }
    return null;
  }

  // Parse HTML chapter and extract: title and full body text
  static Map<String, String> _parseHtml(String htmlContent) {
    final doc = html_parser.parse(htmlContent);

    // Extract title
    String chTitle = '';
    final h1 = doc.querySelector('h1');
    final h2 = doc.querySelector('h2');
    final titleEl = doc.querySelector('title');

    if (h1 != null && h1.text.trim().isNotEmpty) {
      chTitle = h1.text.trim();
    } else if (h2 != null && h2.text.trim().isNotEmpty) {
      chTitle = h2.text.trim();
    } else if (titleEl != null && titleEl.text.trim().isNotEmpty) {
      chTitle = titleEl.text.trim();
    }

    // Remove elements that aren't reading content
    doc.querySelectorAll('script, style, nav, [epub\\:type="toc"], [epub\\:type="landmarks"]')
        .forEach((el) => el.remove());

    // Get body or root element
    final body = doc.body ?? doc.documentElement;
    if (body == null) return {'title': chTitle, 'text': ''};

    final buf = StringBuffer();
    _extractNodeText(body, buf);

    final text = buf.toString()
        .replaceAll(RegExp(r' +'), ' ')          // multiple spaces -> one
        .replaceAll(RegExp(r'\n '), '\n')         // space after newline
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')   // max 2 newlines
        .trim();

    return {'title': chTitle, 'text': text};
  }

  // Walk DOM and convert to readable text with proper paragraph breaks
  static void _extractNodeText(dom.Node node, StringBuffer buf) {
    if (node.nodeType == dom.Node.TEXT_NODE) {
      final text = node.text ?? '';
      // Preserve meaningful whitespace, collapse insignificant
      final cleaned = text.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
      if (cleaned.trim().isNotEmpty) {
        buf.write(cleaned);
      }
      return;
    }

    if (node.nodeType != dom.Node.ELEMENT_NODE) return;
    final el = node as dom.Element;
    final tag = el.localName?.toLowerCase() ?? '';

    switch (tag) {
      // Block elements that need paragraph breaks
      case 'p':
        buf.write('\n');
        for (final child in el.nodes) _extractNodeText(child, buf);
        buf.write('\n');
        break;

      case 'div':
      case 'article':
      case 'section':
      case 'blockquote':
      case 'figure':
        buf.write('\n');
        for (final child in el.nodes) _extractNodeText(child, buf);
        buf.write('\n');
        break;

      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        buf.write('\n\n');
        for (final child in el.nodes) _extractNodeText(child, buf);
        buf.write('\n\n');
        break;

      case 'br':
        buf.write('\n');
        break;

      case 'hr':
        buf.write('\n\n* * *\n\n');
        break;

      case 'li':
        buf.write('\n- ');
        for (final child in el.nodes) _extractNodeText(child, buf);
        break;

      case 'ul':
      case 'ol':
        buf.write('\n');
        for (final child in el.nodes) _extractNodeText(child, buf);
        buf.write('\n');
        break;

      case 'td':
      case 'th':
        for (final child in el.nodes) _extractNodeText(child, buf);
        buf.write(' | ');
        break;

      case 'tr':
        buf.write('\n');
        for (final child in el.nodes) _extractNodeText(child, buf);
        break;

      case 'table':
        buf.write('\n');
        for (final child in el.nodes) _extractNodeText(child, buf);
        buf.write('\n');
        break;

      // Skip non-content elements
      case 'script':
      case 'style':
      case 'nav':
      case 'head':
        break;

      // Inline elements - just recurse
      default:
        for (final child in el.nodes) _extractNodeText(child, buf);
    }
  }

  static BookDocument _error(String fileName, String msg) {
    return BookDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      title: fileName,
      author: 'Unknown',
      format: DocFormat.epub,
      totalPages: 1,
      chapters: [DocChapter(id: 'ch_0', title: 'Error', startPage: 0, content: msg)],
    );
  }
}
