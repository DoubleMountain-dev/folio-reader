// lib/parsers/fb2_parser.dart
// Parses FB2 (FictionBook 2.0) XML. Extracts full chapter body text.

import 'dart:typed_data';
import 'dart:convert';
import 'package:xml/xml.dart';
import '../models/document.dart';

class Fb2Parser {
  static BookDocument parse(String fileName, Uint8List bytes) {
    String xmlContent;
    try {
      xmlContent = utf8.decode(bytes);
    } catch (_) {
      try {
        xmlContent = latin1.decode(bytes);
      } catch (_) {
        xmlContent = String.fromCharCodes(bytes);
      }
    }

    // Remove BOM if present
    if (xmlContent.startsWith('\uFEFF')) {
      xmlContent = xmlContent.substring(1);
    }

    late XmlDocument doc;
    try {
      doc = XmlDocument.parse(xmlContent);
    } catch (_) {
      // Try stripping problematic content before root element
      final start = xmlContent.indexOf('<FictionBook');
      if (start > 0) {
        xmlContent = xmlContent.substring(start);
      }
      doc = XmlDocument.parse(xmlContent);
    }

    final root = doc.rootElement;

    // ── Metadata ──────────────────────────────────────────────────────────
    String title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    String author = 'Unknown Author';

    try {
      final desc = root.findElements('description').first;
      final titleInfo = desc.findElements('title-info').first;

      final titleEl = titleInfo.findElements('book-title').firstOrNull;
      if (titleEl != null && titleEl.innerText.trim().isNotEmpty) {
        title = titleEl.innerText.trim();
      }

      final authorEl = titleInfo.findElements('author').firstOrNull;
      if (authorEl != null) {
        final first = authorEl.findElements('first-name').firstOrNull?.innerText.trim() ?? '';
        final last  = authorEl.findElements('last-name').firstOrNull?.innerText.trim() ?? '';
        final full  = '$first $last'.trim();
        if (full.isNotEmpty) author = full;
      }
    } catch (_) {}

    // ── Body / Chapters ───────────────────────────────────────────────────
    // FB2 has one or more <body> elements. The first is the main text.
    // Each <body> contains <section> elements (chapters).
    // Each <section> may contain: <title>, <epigraph>, <p>, <poem>,
    // <empty-line>, <subtitle>, nested <section>, etc.

    final chapters = <DocChapter>[];
    int pageCounter = 0;

    // Find the main body (not notes body)
    XmlElement? mainBody;
    for (final body in root.findElements('body')) {
      final name = body.getAttribute('name') ?? '';
      if (name.isEmpty || name == 'main') {
        mainBody = body;
        break;
      }
    }
    mainBody ??= root.findElements('body').firstOrNull;

    if (mainBody != null) {
      final sections = mainBody.findElements('section').toList();

      if (sections.isEmpty) {
        // No sections -- treat entire body as one chapter
        final text = _extractText(mainBody);
        if (text.trim().isNotEmpty) {
          chapters.add(DocChapter(
            id: 'ch_0',
            title: title,
            startPage: 0,
            content: text.trim(),
          ));
          pageCounter = (text.length / 1800).ceil().clamp(1, 9999);
        }
      } else {
        for (int i = 0; i < sections.length; i++) {
          final section = sections[i];
          final chTitle = _sectionTitle(section, i + 1);
          final content = _sectionContent(section);

          if (content.trim().isEmpty) continue;

          final pages = (content.length / 1800).ceil().clamp(1, 9999);
          chapters.add(DocChapter(
            id: 'ch_$i',
            title: chTitle,
            startPage: pageCounter,
            content: content.trim(),
          ));
          pageCounter += pages;
        }
      }
    }

    // Fallback if still no chapters
    if (chapters.isEmpty) {
      final allText = _extractText(root);
      chapters.add(DocChapter(
        id: 'ch_0',
        title: title,
        startPage: 0,
        content: allText.trim().isEmpty ? 'No content found.' : allText.trim(),
      ));
      pageCounter = (allText.length / 1800).ceil().clamp(1, 9999);
    }

    return BookDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      title: title,
      author: author,
      format: DocFormat.fb2,
      totalPages: pageCounter,
      chapters: chapters,
    );
  }

  // Extract chapter title from <title> child (first paragraph inside it)
  static String _sectionTitle(XmlElement section, int index) {
    try {
      final titleEl = section.findElements('title').firstOrNull;
      if (titleEl != null) {
        final text = titleEl.innerText.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (text.isNotEmpty) return text;
      }
    } catch (_) {}
    return 'Chapter $index';
  }

  // Extract ALL text content from a section, EXCLUDING its title element
  // but INCLUDING all paragraphs, subtitles, poems, nested sections, etc.
  static String _sectionContent(XmlElement section) {
    final buf = StringBuffer();
    for (final child in section.children) {
      if (child is XmlElement) {
        final tag = child.localName.toLowerCase();
        // Skip the chapter title -- it's shown as header in UI
        if (tag == 'title') continue;
        _renderElement(child, buf);
      }
    }
    return buf.toString();
  }

  // Recursively render any FB2 element to plain text with formatting
  static void _renderElement(XmlElement el, StringBuffer buf) {
    final tag = el.localName.toLowerCase();

    switch (tag) {
      case 'p':
        buf.write('\n');
        _renderChildren(el, buf);
        buf.write('\n');
        break;

      case 'empty-line':
        buf.write('\n\n');
        break;

      case 'subtitle':
        buf.write('\n\n');
        _renderChildren(el, buf);
        buf.write('\n\n');
        break;

      case 'epigraph':
        buf.write('\n');
        _renderChildren(el, buf);
        buf.write('\n');
        break;

      case 'poem':
        buf.write('\n');
        _renderChildren(el, buf);
        buf.write('\n');
        break;

      case 'stanza':
        _renderChildren(el, buf);
        buf.write('\n');
        break;

      case 'v': // poem verse line
        _renderChildren(el, buf);
        buf.write('\n');
        break;

      case 'cite':
        buf.write('\n');
        _renderChildren(el, buf);
        buf.write('\n');
        break;

      case 'section':
        // nested section -- render its title then content
        for (final child in el.children) {
          if (child is XmlElement) {
            _renderElement(child, buf);
          }
        }
        break;

      case 'title':
        buf.write('\n\n');
        _renderChildren(el, buf);
        buf.write('\n\n');
        break;

      case 'emphasis':
      case 'strong':
      case 'strikethrough':
      case 'code':
      case 'sup':
      case 'sub':
      case 'a':
        _renderChildren(el, buf);
        break;

      case 'image':
        // Skip images
        break;

      case 'table':
        _renderChildren(el, buf);
        buf.write('\n');
        break;

      case 'tr':
        _renderChildren(el, buf);
        buf.write('\n');
        break;

      case 'td':
      case 'th':
        _renderChildren(el, buf);
        buf.write('\t');
        break;

      default:
        _renderChildren(el, buf);
    }
  }

  static void _renderChildren(XmlElement el, StringBuffer buf) {
    for (final node in el.children) {
      if (node is XmlText) {
        final t = node.value;
        if (t.isNotEmpty) buf.write(t);
      } else if (node is XmlElement) {
        _renderElement(node, buf);
      }
    }
  }

  // Extract all text from any element (used as fallback)
  static String _extractText(XmlElement el) {
    final buf = StringBuffer();
    for (final node in el.descendants) {
      if (node is XmlText) {
        buf.write(node.value);
      } else if (node is XmlElement) {
        final tag = node.localName.toLowerCase();
        if (tag == 'p' || tag == 'v' || tag == 'subtitle') {
          buf.write('\n');
        } else if (tag == 'empty-line') {
          buf.write('\n\n');
        }
      }
    }
    return buf.toString();
  }
}
