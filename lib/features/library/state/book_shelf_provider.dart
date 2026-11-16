import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_shelf_item.dart';

class BookShelfProvider extends ChangeNotifier {
  static const String storageKey = 'user_book_shelf_v1';
  static const int currentSchemaVersion = 1;

  final Map<String, BookShelfItem> _items = {};
  bool _isLoaded = false;
  SharedPreferences? _prefs;

  BookShelfProvider({SharedPreferences? prefs}) : _prefs = prefs {
    loadShelf();
  }

  bool get isLoaded => _isLoaded;
  int get count => _items.length;

  /// Deterministic newest-first list of books.
  List<BookShelfItem> get items {
    final list = _items.values.toList();
    list.sort((a, b) {
      final cmp = b.addedAt.compareTo(a.addedAt);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });
    return List.unmodifiable(list);
  }

  bool contains(String id) => _items.containsKey(id);

  BookShelfItem? getById(String id) => _items[id];

  Future<void> loadShelf() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs?.getString(storageKey);

      _items.clear();

      if (raw != null && raw.trim().isNotEmpty) {
        final dynamic decoded = jsonDecode(raw);
        List<dynamic>? rawList;

        if (decoded is Map<String, dynamic>) {
          final itemsField = decoded['items'];
          if (itemsField is List) {
            rawList = itemsField;
          }
        } else if (decoded is Map) {
          final itemsField = decoded['items'];
          if (itemsField is List) {
            rawList = itemsField;
          }
        } else if (decoded is List) {
          rawList = decoded;
        }

        if (rawList != null) {
          for (final rawItem in rawList) {
            try {
              if (rawItem is Map<String, dynamic>) {
                final item = BookShelfItem.fromJson(rawItem);
                _items[item.id] = item;
              } else if (rawItem is Map) {
                final item = BookShelfItem.fromJson(Map<String, dynamic>.from(rawItem));
                _items[item.id] = item;
              }
            } catch (itemError) {
              // Reject corrupt entries independently
              debugPrint('Rejected corrupt bookshelf entry: $itemError');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading bookshelf: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> addBook(BookShelfItem item) async {
    _items[item.id] = item;
    await _persist();
    notifyListeners();
  }

  Future<void> updateBookProgress({
    required String bookId,
    required String chapterId,
    String? chapterTitle,
    required double scrollOffset,
    required double readPercent,
  }) async {
    final item = _items[bookId];
    if (item != null) {
      _items[bookId] = item.copyWith(
        lastChapterId: chapterId,
        lastChapterTitle: chapterTitle ?? item.lastChapterTitle,
        lastScrollOffset: scrollOffset,
        lastReadPercent: readPercent,
        lastReadAt: DateTime.now(),
      );
      await _persist();
      notifyListeners();
    }
  }

  Future<void> removeBook(String id) async {
    if (_items.remove(id) != null) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> clear() async {
    _items.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final versionedPayload = {
        'version': currentSchemaVersion,
        'items': _items.values.map((e) => e.toJson()).toList(),
      };
      await _prefs?.setString(storageKey, jsonEncode(versionedPayload));
    } catch (e) {
      debugPrint('Error persisting bookshelf: $e');
    }
  }
}
