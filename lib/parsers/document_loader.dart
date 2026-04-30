// lib/parsers/document_loader.dart

import 'dart:typed_data';
import '../models/document.dart';
import 'fb2_parser.dart';
import 'epub_parser.dart';
import 'text_parser.dart';

class DocumentLoader {
  static BookDocument load(String fileName, Uint8List bytes) {
    final format = BookDocument.formatFromName(fileName);
    switch (format) {
      case DocFormat.fb2:
        return Fb2Parser.parse(fileName, bytes);
      case DocFormat.epub:
        return EpubParser.parse(fileName, bytes);
      case DocFormat.txt:
        return TxtParser.parse(fileName, bytes);
      case DocFormat.html:
        return HtmlFileParser.parse(fileName, bytes);
      case DocFormat.pdf:
        return _pdfMeta(fileName);
      case DocFormat.unknown:
        // Try as plain text
        return TxtParser.parse(fileName, bytes);
    }
  }

  static BookDocument _pdfMeta(String fileName) {
    final title = fileName
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
        .replaceAll('_', ' ')
        .trim();
    return BookDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      title: title,
      author: 'Unknown Author',
      format: DocFormat.pdf,
      totalPages: 0,
      chapters: [],
    );
  }
}
