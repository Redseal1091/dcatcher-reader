import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/library_item.dart';
import '../../catalog/models/catalog_filters.dart';

class LibraryProvider extends ChangeNotifier {
  final Map<String, LibraryItem> _items = {};
  final Map<String, Map<String, String>> _blacklisted = {};
  bool _isLoaded = false;

  Map<String, LibraryItem> get items => _items;
  Map<String, Map<String, String>> get blacklisted => _blacklisted;
  bool get isLoaded => _isLoaded;

  LibraryProvider() {
    loadLibrary();
  }

  Future<void> loadLibrary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Загрузка библиотеки
      final raw = prefs.getString('user_library');
      if (raw != null) {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        _items.clear();
        decoded.forEach((key, val) {
          _items[key] = LibraryItem.fromJson(val);
        });
      }

      // Загрузка черного списка
      final rawBlacklist = prefs.getString('user_blacklist');
      if (rawBlacklist != null) {
        final Map<String, dynamic> decoded = jsonDecode(rawBlacklist);
        _blacklisted.clear();
        decoded.forEach((key, val) {
          if (val is Map) {
            _blacklisted[key] = {
              'title': val['title']?.toString() ?? 'Без названия',
              'coverUrl': val['coverUrl']?.toString() ?? '',
            };
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading library: $e');
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> saveLibrary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final Map<String, dynamic> data = {};
      _items.forEach((key, item) {
        data[key] = item.toJson();
      });
      await prefs.setString('user_library', jsonEncode(data));

      await prefs.setString('user_blacklist', jsonEncode(_blacklisted));
    } catch (e) {
      debugPrint('Error saving library: $e');
    }
  }

  LibraryItem? getItem(String mangaId) => _items[mangaId];

  UserMangaStatus? getStatus(String mangaId) {
    return _items[mangaId]?.status;
  }

  void setStatus(String mangaId, UserMangaStatus? status, {String? title, String? coverUrl}) {
    if (status == null) {
      _items.remove(mangaId);
    } else {
      final existing = _items[mangaId];
      if (existing != null) {
        _items[mangaId] = existing.copyWith(
          status: status,
          title: title ?? existing.title,
          coverUrl: coverUrl ?? existing.coverUrl,
          updatedAt: DateTime.now(),
        );
      } else {
        _items[mangaId] = LibraryItem(
          mangaId: mangaId,
          status: status,
          title: title,
          coverUrl: coverUrl,
          updatedAt: DateTime.now(),
        );
      }
    }
    saveLibrary();
    notifyListeners();
  }

  /// Фиксирование момента, где остановился пользователь (глава, страница, тайтл)
  void updateProgress({
    required String mangaId,
    required String chapterId,
    required String chapterNumber,
    int page = 1,
    String? title,
    String? coverUrl,
  }) {
    final existing = _items[mangaId];
    if (existing != null) {
      _items[mangaId] = existing.copyWith(
        lastChapterId: chapterId,
        lastChapterNumber: chapterNumber,
        lastPage: page,
        title: title ?? existing.title,
        coverUrl: coverUrl ?? existing.coverUrl,
        status: existing.status == UserMangaStatus.completed ? existing.status : UserMangaStatus.reading,
        updatedAt: DateTime.now(),
      );
    } else {
      _items[mangaId] = LibraryItem(
        mangaId: mangaId,
        status: UserMangaStatus.reading,
        lastChapterId: chapterId,
        lastChapterNumber: chapterNumber,
        lastPage: page,
        title: title,
        coverUrl: coverUrl,
        updatedAt: DateTime.now(),
      );
    }
    saveLibrary();
    notifyListeners();
  }

  // --- Черный список (Не показывать) ---

  bool isBlacklisted(String mangaId) {
    return _blacklisted.containsKey(mangaId);
  }

  void addToBlacklist(String mangaId, {required String title, required String coverUrl}) {
    _blacklisted[mangaId] = {
      'title': title,
      'coverUrl': coverUrl,
    };
    saveLibrary();
    notifyListeners();
  }

  void removeFromBlacklist(String mangaId) {
    _blacklisted.remove(mangaId);
    saveLibrary();
    notifyListeners();
  }

  void toggleBlacklist(String mangaId, {required String title, required String coverUrl}) {
    if (isBlacklisted(mangaId)) {
      removeFromBlacklist(mangaId);
    } else {
      addToBlacklist(mangaId, title: title, coverUrl: coverUrl);
    }
  }

  /// Проверяет, должна ли данная манга быть ИСКЛЮЧЕНА из каталога
  bool shouldExclude(String mangaId, CatalogFilters filters) {
    // 0. Черный список: скрывать везде, кроме прямого поиска по названию
    if (isBlacklisted(mangaId)) {
      if (filters.searchQuery.trim().isEmpty) {
        return true; // Скрываем из общего каталога!
      }
    }

    final status = getStatus(mangaId);

    // 1. Исключение статуса "Читаю"
    if (filters.readingStatus == FilterTriState.exclude && status == UserMangaStatus.reading) {
      return true; // Скрыть
    }

    // 2. Исключение статуса "Прочитано"
    if (filters.completedStatus == FilterTriState.exclude && status == UserMangaStatus.completed) {
      return true; // Скрыть
    }

    // 3. Исключение статуса "В планах"
    if (filters.plannedStatus == FilterTriState.exclude && status == UserMangaStatus.planned) {
      return true; // Скрыть
    }

    // 4. Логика Include
    final bool hasInclude = filters.readingStatus == FilterTriState.include ||
        filters.completedStatus == FilterTriState.include ||
        filters.plannedStatus == FilterTriState.include;

    if (hasInclude) {
      if (filters.readingStatus == FilterTriState.include && status == UserMangaStatus.reading) return false;
      if (filters.completedStatus == FilterTriState.include && status == UserMangaStatus.completed) return false;
      if (filters.plannedStatus == FilterTriState.include && status == UserMangaStatus.planned) return false;
      return true;
    }

    return false;
  }

  // --- Экспорт и Импорт бэкапа библиотеки (JSON) ---

  String exportBackup() {
    final Map<String, dynamic> libraryData = {};
    _items.forEach((key, item) {
      libraryData[key] = item.toJson();
    });

    final backup = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'library': libraryData,
      'blacklist': _blacklisted,
    };

    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  bool importBackup(String jsonString) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      if (data.containsKey('library')) {
        final Map<String, dynamic> lib = data['library'];
        lib.forEach((key, val) {
          _items[key] = LibraryItem.fromJson(val);
        });
      }
      if (data.containsKey('blacklist')) {
        final Map<String, dynamic> bl = data['blacklist'];
        bl.forEach((key, val) {
          if (val is Map) {
            _blacklisted[key] = {
              'title': val['title']?.toString() ?? 'Без названия',
              'coverUrl': val['coverUrl']?.toString() ?? '',
            };
          }
        });
      }
      saveLibrary();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Import backup error: $e');
      return false;
    }
  }
}
