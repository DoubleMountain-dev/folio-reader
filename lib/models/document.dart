// lib/models/document.dart
import 'package:flutter/material.dart';

enum DocFormat { epub, fb2, pdf, txt, html, unknown }

class BookDocument {
  final String id;
  final String fileName;
  final String title;
  final String author;
  final DocFormat format;
  final int totalPages;
  int currentPage;
  final DateTime addedAt;
  DateTime? lastOpenedAt;
  final List<DocChapter> chapters;
  final List<DocQuote> quotes;
  final List<DocBookmark> bookmarks;
  List<String> tags;
  String? collectionId;

  BookDocument({
    required this.id, required this.fileName, required this.title,
    required this.author, required this.format,
    this.totalPages = 0, this.currentPage = 0,
    DateTime? addedAt, this.lastOpenedAt,
    List<DocChapter>? chapters, List<DocQuote>? quotes,
    List<DocBookmark>? bookmarks, List<String>? tags, this.collectionId,
  })  : addedAt = addedAt ?? DateTime.now(),
        chapters = chapters ?? [], quotes = quotes ?? [],
        bookmarks = bookmarks ?? [], tags = tags ?? [];

  double get progress => totalPages > 0 ? (currentPage / totalPages).clamp(0.0, 1.0) : 0.0;
  bool get isFinished => progress >= 1.0 && totalPages > 0;

  String get formatLabel {
    switch (format) {
      case DocFormat.epub: return 'EPUB'; case DocFormat.fb2: return 'FB2';
      case DocFormat.pdf:  return 'PDF';  case DocFormat.txt: return 'TXT';
      case DocFormat.html: return 'HTML'; default: return 'TEXT';
    }
  }

  String get spineColor {
    switch (format) {
      case DocFormat.epub: return '#2D3561'; case DocFormat.fb2: return '#1B4332';
      case DocFormat.pdf:  return '#6B2D3E'; case DocFormat.txt: return '#7B3F00';
      case DocFormat.html: return '#4A1942'; default: return '#2C3E50';
    }
  }

  static DocFormat formatFromName(String name) {
    switch (name.split('.').last.toLowerCase()) {
      case 'epub': return DocFormat.epub; case 'fb2': return DocFormat.fb2;
      case 'pdf':  return DocFormat.pdf;  case 'txt': return DocFormat.txt;
      case 'html': case 'htm': return DocFormat.html; default: return DocFormat.unknown;
    }
  }

  BookDocument copyWith({int? currentPage, int? totalPages, List<DocQuote>? quotes,
    List<DocBookmark>? bookmarks, List<String>? tags, String? collectionId,
    DateTime? lastOpenedAt}) {
    return BookDocument(
      id: id, fileName: fileName, title: title, author: author, format: format,
      totalPages: totalPages ?? this.totalPages, currentPage: currentPage ?? this.currentPage,
      addedAt: addedAt, lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      chapters: chapters, quotes: quotes ?? this.quotes, bookmarks: bookmarks ?? this.bookmarks,
      tags: tags ?? this.tags, collectionId: collectionId ?? this.collectionId,
    );
  }
}

class DocChapter {
  final String id, title, content;
  final int startPage;
  const DocChapter({required this.id, required this.title, required this.startPage, required this.content});
}

class DocQuote {
  final String id, text, chapter;
  final int page;
  final DateTime savedAt;
  DocQuote({required this.id, required this.text, required this.chapter, required this.page, DateTime? savedAt})
      : savedAt = savedAt ?? DateTime.now();
}

class DocBookmark {
  final String id, chapter, preview;
  final int page;
  final DateTime savedAt;
  DocBookmark({required this.id, required this.chapter, required this.page, required this.preview, DateTime? savedAt})
      : savedAt = savedAt ?? DateTime.now();
}

class BookCollection {
  final String id, name, color;
  final DateTime createdAt;
  BookCollection({required this.id, required this.name, required this.color, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color, 'createdAt': createdAt.toIso8601String()};
  factory BookCollection.fromJson(Map<String, dynamic> j) =>
      BookCollection(id: j['id'], name: j['name'], color: j['color'] ?? '#2D3561',
          createdAt: DateTime.tryParse(j['createdAt'] ?? ''));
}

class ReadingSession {
  final String bookId;
  final DateTime date;
  final int pagesRead;
  ReadingSession({required this.bookId, required this.date, required this.pagesRead});
  Map<String, dynamic> toJson() => {'bookId': bookId, 'date': date.toIso8601String(), 'pagesRead': pagesRead};
  factory ReadingSession.fromJson(Map<String, dynamic> j) => ReadingSession(
    bookId: j['bookId'], pagesRead: j['pagesRead'] ?? 0,
    date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now());
}

class ReadingGoal {
  final int year, targetBooks;
  ReadingGoal({required this.year, required this.targetBooks});
  Map<String, dynamic> toJson() => {'year': year, 'targetBooks': targetBooks};
  factory ReadingGoal.fromJson(Map<String, dynamic> j) =>
      ReadingGoal(year: j['year'] ?? DateTime.now().year, targetBooks: j['targetBooks'] ?? 12);
}

class Achievement {
  final String id, title, description, emoji;
  final bool unlocked;
  final DateTime? unlockedAt;
  const Achievement({required this.id, required this.title, required this.description,
    required this.emoji, this.unlocked = false, this.unlockedAt});
  Achievement copyWith({bool? unlocked, DateTime? unlockedAt}) => Achievement(
    id: id, title: title, description: description, emoji: emoji,
    unlocked: unlocked ?? this.unlocked, unlockedAt: unlockedAt ?? this.unlockedAt);
  Map<String, dynamic> toJson() => {'id': id, 'unlocked': unlocked, 'unlockedAt': unlockedAt?.toIso8601String()};
}

class HistoryEntry {
  final String bookId, bookTitle;
  final DateTime openedAt;
  HistoryEntry({required this.bookId, required this.bookTitle, required this.openedAt});
  Map<String, dynamic> toJson() => {'bookId': bookId, 'bookTitle': bookTitle, 'openedAt': openedAt.toIso8601String()};
  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
    bookId: j['bookId'], bookTitle: j['bookTitle'],
    openedAt: DateTime.tryParse(j['openedAt'] ?? '') ?? DateTime.now());
}

class ReadingSettings {
  final double fontSize, lineHeight;
  final String fontFamily, theme;
  const ReadingSettings({this.fontSize = 16.0, this.lineHeight = 1.8, this.fontFamily = 'serif', this.theme = 'sepia'});
  ReadingSettings copyWith({double? fontSize, double? lineHeight, String? fontFamily, String? theme}) =>
      ReadingSettings(fontSize: fontSize ?? this.fontSize, lineHeight: lineHeight ?? this.lineHeight,
          fontFamily: fontFamily ?? this.fontFamily, theme: theme ?? this.theme);
  Color get backgroundColor {
    switch (theme) {
      case 'dark': return const Color(0xFF1A1208); case 'night': return const Color(0xFF0D1117);
      case 'light': return Colors.white; default: return const Color(0xFFFAF6ED);
    }
  }
  Color get textColor {
    switch (theme) {
      case 'dark': case 'night': return const Color(0xFFD4C9B0); default: return const Color(0xFF3D3020);
    }
  }
}
