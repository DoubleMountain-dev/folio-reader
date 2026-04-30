// lib/providers/library_provider.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document.dart';
import '../parsers/document_loader.dart';

enum SortOrder { dateAdded, lastOpened, title, author, progress }

class LibraryProvider extends ChangeNotifier {
  List<BookDocument>   _books        = [];
  List<BookCollection> _collections  = [];
  List<ReadingSession> _sessions     = [];
  List<HistoryEntry>   _history      = [];
  List<Achievement>    _achievements = _defaultAchievements();
  ReadingGoal          _goal         = ReadingGoal(year: DateTime.now().year, targetBooks: 12);
  ReadingSettings      _settings     = const ReadingSettings();
  bool   _isLoading   = false;
  String? _error;
  SortOrder _sortOrder = SortOrder.dateAdded;
  String _searchQuery  = '';
  String? _filterTag;
  String? _filterCollection;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<BookDocument>   get collections  => _books;
  List<BookCollection> get bookCollections => _collections;
  List<ReadingSession> get sessions     => _sessions;
  List<HistoryEntry>   get history      => _history.take(50).toList();
  List<Achievement>    get achievements => _achievements;
  ReadingGoal          get goal         => _goal;
  ReadingSettings      get settings     => _settings;
  bool                 get isLoading    => _isLoading;
  String?              get error        => _error;
  SortOrder            get sortOrder    => _sortOrder;
  String               get searchQuery  => _searchQuery;
  String?              get filterTag    => _filterTag;
  String?              get filterCollection => _filterCollection;

  List<BookDocument> get books {
    var list = List<BookDocument>.from(_books);
    // Filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((b) =>
        b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q)).toList();
    }
    if (_filterTag != null) {
      list = list.where((b) => b.tags.contains(_filterTag)).toList();
    }
    if (_filterCollection != null) {
      list = list.where((b) => b.collectionId == _filterCollection).toList();
    }
    // Sort
    switch (_sortOrder) {
      case SortOrder.dateAdded:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt)); break;
      case SortOrder.lastOpened:
        list.sort((a, b) {
          if (a.lastOpenedAt == null && b.lastOpenedAt == null) return 0;
          if (a.lastOpenedAt == null) return 1;
          if (b.lastOpenedAt == null) return -1;
          return b.lastOpenedAt!.compareTo(a.lastOpenedAt!);
        }); break;
      case SortOrder.title:
        list.sort((a, b) => a.title.compareTo(b.title)); break;
      case SortOrder.author:
        list.sort((a, b) => a.author.compareTo(b.author)); break;
      case SortOrder.progress:
        list.sort((a, b) => b.progress.compareTo(a.progress)); break;
    }
    return list;
  }

  List<BookDocument> get currentlyReading =>
      _books.where((b) => b.currentPage > 0 && !b.isFinished).toList();

  List<BookDocument> get finishedBooks => _books.where((b) => b.isFinished).toList();

  Set<String> get allTags => _books.expand((b) => b.tags).toSet();

  // ── Stats ─────────────────────────────────────────────────────────────────
  int pagesReadInPeriod(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _sessions
        .where((s) => s.date.isAfter(cutoff))
        .fold(0, (sum, s) => sum + s.pagesRead);
  }

  int get pagesReadToday     => pagesReadInPeriod(1);
  int get pagesReadThisWeek  => pagesReadInPeriod(7);
  int get pagesReadThisMonth => pagesReadInPeriod(30);

  int get readingStreakDays {
    if (_sessions.isEmpty) return 0;
    final today = DateTime.now();
    int streak = 0;
    for (int i = 0; i < 365; i++) {
      final day = DateTime(today.year, today.month, today.day - i);
      final hasSession = _sessions.any((s) =>
          s.date.year == day.year && s.date.month == day.month && s.date.day == day.day);
      if (hasSession) { streak++; } else { break; }
    }
    return streak;
  }

  int get booksFinishedThisYear {
    return finishedBooks.where((b) =>
        b.lastOpenedAt != null && b.lastOpenedAt!.year == DateTime.now().year).length;
  }

  LibraryProvider() { Future.delayed(Duration.zero, _load); }

  // ── Import ────────────────────────────────────────────────────────────────
  Future<List<BookDocument>> importFiles(List<MapEntry<String, Uint8List>> files) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final added = <BookDocument>[];
    for (final entry in files) {
      try {
        final doc = DocumentLoader.load(entry.key, entry.value);
        final exists = _books.any((b) => b.fileName == entry.key && b.title == doc.title);
        if (!exists) { _books.add(doc); added.add(doc); }
      } catch (e) {
        _error = 'Failed to open "${entry.key}": $e';
      }
    }
    if (added.isNotEmpty) await _save();
    _isLoading = false;
    notifyListeners();
    _checkAchievements();
    return added;
  }

  // ── Progress ──────────────────────────────────────────────────────────────
  void updateProgress(String id, int page, {int? totalPages}) {
    final idx = _books.indexWhere((b) => b.id == id);
    if (idx == -1) return;
    final prev = _books[idx].currentPage;
    final pagesRead = (page - prev).clamp(0, 9999);
    _books[idx] = _books[idx].copyWith(
        currentPage: page, totalPages: totalPages, lastOpenedAt: DateTime.now());
    if (pagesRead > 0) {
      _sessions.add(ReadingSession(
          bookId: id, date: DateTime.now(), pagesRead: pagesRead));
    }
    _save();
    notifyListeners();
    _checkAchievements();
  }

  void openBook(String id, String title) {
    _history.insert(0, HistoryEntry(bookId: id, bookTitle: title, openedAt: DateTime.now()));
    if (_history.length > 100) _history.removeLast();
    final idx = _books.indexWhere((b) => b.id == id);
    if (idx != -1) _books[idx] = _books[idx].copyWith(lastOpenedAt: DateTime.now());
    _save();
    notifyListeners();
  }

  // ── Tags ──────────────────────────────────────────────────────────────────
  void setTags(String id, List<String> tags) {
    final idx = _books.indexWhere((b) => b.id == id);
    if (idx != -1) { _books[idx] = _books[idx].copyWith(tags: tags); _save(); notifyListeners(); }
  }

  void setCollection(String id, String? collectionId) {
    final idx = _books.indexWhere((b) => b.id == id);
    if (idx != -1) { _books[idx] = _books[idx].copyWith(collectionId: collectionId); _save(); notifyListeners(); }
  }

  // ── Collections ───────────────────────────────────────────────────────────
  void addCollection(String name, String color) {
    _collections.add(BookCollection(
        id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, color: color));
    _save(); notifyListeners();
  }

  void deleteCollection(String id) {
    _collections.removeWhere((c) => c.id == id);
    for (final b in _books) { if (b.collectionId == id) b.collectionId = null; }
    _save(); notifyListeners();
  }

  // ── Search & Filter ───────────────────────────────────────────────────────
  void setSearch(String q) { _searchQuery = q; notifyListeners(); }
  void setFilterTag(String? tag) { _filterTag = tag; notifyListeners(); }
  void setFilterCollection(String? cid) { _filterCollection = cid; notifyListeners(); }
  void setSortOrder(SortOrder order) { _sortOrder = order; notifyListeners(); }
  void clearFilters() { _searchQuery = ''; _filterTag = null; _filterCollection = null; notifyListeners(); }

  // ── Goal ─────────────────────────────────────────────────────────────────
  void setGoal(int targetBooks) {
    _goal = ReadingGoal(year: DateTime.now().year, targetBooks: targetBooks);
    _save(); notifyListeners();
  }

  // ── Quotes & Bookmarks ────────────────────────────────────────────────────
  void addQuote(String id, DocQuote quote) {
    final idx = _books.indexWhere((b) => b.id == id);
    if (idx != -1) {
      final updated = List<DocQuote>.from(_books[idx].quotes)..add(quote);
      _books[idx] = _books[idx].copyWith(quotes: updated);
      _save(); notifyListeners();
    }
  }

  void addBookmark(String id, DocBookmark bookmark) {
    final idx = _books.indexWhere((b) => b.id == id);
    if (idx != -1) {
      final updated = List<DocBookmark>.from(_books[idx].bookmarks)..add(bookmark);
      _books[idx] = _books[idx].copyWith(bookmarks: updated);
      _save(); notifyListeners();
    }
  }

  void removeBook(String id) { _books.removeWhere((b) => b.id == id); _save(); notifyListeners(); }
  void updateSettings(ReadingSettings s) { _settings = s; notifyListeners(); }

  // ── Achievements ──────────────────────────────────────────────────────────
  void _checkAchievements() {
    bool changed = false;
    for (int i = 0; i < _achievements.length; i++) {
      final a = _achievements[i];
      if (a.unlocked) continue;
      bool unlock = false;
      switch (a.id) {
        case 'first_book':  unlock = _books.isNotEmpty; break;
        case 'five_books':  unlock = _books.length >= 5; break;
        case 'ten_books':   unlock = _books.length >= 10; break;
        case 'first_finish': unlock = finishedBooks.isNotEmpty; break;
        case 'five_finish': unlock = finishedBooks.length >= 5; break;
        case 'streak_3':    unlock = readingStreakDays >= 3; break;
        case 'streak_7':    unlock = readingStreakDays >= 7; break;
        case 'streak_30':   unlock = readingStreakDays >= 30; break;
        case 'first_quote': unlock = _books.any((b) => b.quotes.isNotEmpty); break;
        case 'goal_done':   unlock = booksFinishedThisYear >= _goal.targetBooks; break;
        case 'pages_100':   unlock = pagesReadThisMonth >= 100; break;
        case 'pages_1000':  unlock = _sessions.fold(0, (s, r) => s + r.pagesRead) >= 1000; break;
      }
      if (unlock) {
        _achievements[i] = a.copyWith(unlocked: true, unlockedAt: DateTime.now());
        changed = true;
      }
    }
    if (changed) { _save(); notifyListeners(); }
  }

  static List<Achievement> _defaultAchievements() => [
    const Achievement(id: 'first_book',   emoji: '📚', title: 'First Book',        description: 'Add your first book to the library'),
    const Achievement(id: 'five_books',   emoji: '🗂️', title: 'Collector',         description: 'Add 5 books to the library'),
    const Achievement(id: 'ten_books',    emoji: '🏛️', title: 'Librarian',         description: 'Add 10 books to the library'),
    const Achievement(id: 'first_finish', emoji: '🏁', title: 'Finisher',           description: 'Finish your first book'),
    const Achievement(id: 'five_finish',  emoji: '🏆', title: 'Bookworm',           description: 'Finish 5 books'),
    const Achievement(id: 'streak_3',     emoji: '🔥', title: '3-Day Streak',       description: 'Read 3 days in a row'),
    const Achievement(id: 'streak_7',     emoji: '⚡', title: 'Week Warrior',       description: 'Read 7 days in a row'),
    const Achievement(id: 'streak_30',    emoji: '🌟', title: 'Month Master',       description: 'Read 30 days in a row'),
    const Achievement(id: 'first_quote',  emoji: '💬', title: 'Quote Collector',    description: 'Save your first quote'),
    const Achievement(id: 'goal_done',    emoji: '🎯', title: 'Goal Reached!',      description: 'Complete your annual reading goal'),
    const Achievement(id: 'pages_100',    emoji: '📖', title: '100 Pages',          description: 'Read 100 pages this month'),
    const Achievement(id: 'pages_1000',   emoji: '🚀', title: '1000 Pages',         description: 'Read 1000 pages total'),
  ];

  // ── Persistence ───────────────────────────────────────────────────────────
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('books_v4',       jsonEncode(_books.map(_bookToJson).toList()));
      await prefs.setString('collections_v1', jsonEncode(_collections.map((c) => c.toJson()).toList()));
      await prefs.setString('sessions_v1',    jsonEncode(_sessions.map((s) => s.toJson()).toList()));
      await prefs.setString('history_v1',     jsonEncode(_history.map((h) => h.toJson()).toList()));
      await prefs.setString('goal_v1',        jsonEncode(_goal.toJson()));
      await prefs.setString('achievements_v1',jsonEncode(_achievements.map((a) => a.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('books_v4');
      if (raw != null) _books = (jsonDecode(raw) as List).map((j) => _bookFromJson(j)).toList();
      final colRaw = prefs.getString('collections_v1');
      if (colRaw != null) _collections = (jsonDecode(colRaw) as List).map((j) => BookCollection.fromJson(j)).toList();
      final sesRaw = prefs.getString('sessions_v1');
      if (sesRaw != null) _sessions = (jsonDecode(sesRaw) as List).map((j) => ReadingSession.fromJson(j)).toList();
      final histRaw = prefs.getString('history_v1');
      if (histRaw != null) _history = (jsonDecode(histRaw) as List).map((j) => HistoryEntry.fromJson(j)).toList();
      final goalRaw = prefs.getString('goal_v1');
      if (goalRaw != null) _goal = ReadingGoal.fromJson(jsonDecode(goalRaw));
      final achRaw = prefs.getString('achievements_v1');
      if (achRaw != null) {
        final saved = Map<String, dynamic>.fromEntries(
            (jsonDecode(achRaw) as List).map((j) => MapEntry(j['id'] as String, j)));
        _achievements = _defaultAchievements().map((a) {
          final s = saved[a.id];
          if (s == null) return a;
          return a.copyWith(
              unlocked: s['unlocked'] == true,
              unlockedAt: DateTime.tryParse(s['unlockedAt'] ?? ''));
        }).toList();
      }
      notifyListeners();
    } catch (_) {}
  }

  Map<String, dynamic> _bookToJson(BookDocument b) => {
    'id': b.id, 'fileName': b.fileName, 'title': b.title, 'author': b.author,
    'format': b.format.index, 'totalPages': b.totalPages, 'currentPage': b.currentPage,
    'addedAt': b.addedAt.toIso8601String(), 'lastOpenedAt': b.lastOpenedAt?.toIso8601String(),
    'tags': b.tags, 'collectionId': b.collectionId,
    'quotes': b.quotes.map((q) => {'id': q.id, 'text': q.text, 'chapter': q.chapter, 'page': q.page, 'savedAt': q.savedAt.toIso8601String()}).toList(),
    'bookmarks': b.bookmarks.map((m) => {'id': m.id, 'chapter': m.chapter, 'page': m.page, 'preview': m.preview, 'savedAt': m.savedAt.toIso8601String()}).toList(),
  };

  BookDocument _bookFromJson(Map<String, dynamic> j) {
    final fmtIdx = (j['format'] as int? ?? 5).clamp(0, DocFormat.values.length - 1);
    return BookDocument(
      id: j['id'], fileName: j['fileName'] ?? '', title: j['title'], author: j['author'],
      format: DocFormat.values[fmtIdx], totalPages: j['totalPages'] ?? 0, currentPage: j['currentPage'] ?? 0,
      addedAt: DateTime.tryParse(j['addedAt'] ?? '') ?? DateTime.now(),
      lastOpenedAt: DateTime.tryParse(j['lastOpenedAt'] ?? ''),
      tags: List<String>.from(j['tags'] ?? []), collectionId: j['collectionId'],
      quotes: (j['quotes'] as List? ?? []).map((q) => DocQuote(id: q['id'], text: q['text'], chapter: q['chapter'], page: q['page'], savedAt: DateTime.tryParse(q['savedAt'] ?? ''))).toList(),
      bookmarks: (j['bookmarks'] as List? ?? []).map((m) => DocBookmark(id: m['id'], chapter: m['chapter'], page: m['page'], preview: m['preview'], savedAt: DateTime.tryParse(m['savedAt'] ?? ''))).toList(),
    );
  }
}
