import 'package:flutter/foundation.dart';
import '../models/manga.dart';
import '../models/catalog_filters.dart';
import '../../sources/manga_source.dart';
import '../../sources/source_manager.dart';
import '../../library/state/library_provider.dart';

class CatalogProvider extends ChangeNotifier {
  MangaSource _source = SourceManager.currentSource;
  CatalogFilters _filters = CatalogFilters();
  
  List<Manga> _allManga = [];
  List<Manga> _filteredManga = [];
  bool _isLoading = false;
  String? _errorMessage;

  MangaSource get source => _source;
  CatalogFilters get filters => _filters;
  List<Manga> get mangaList => _filteredManga;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  CatalogProvider() {
    loadCatalog();
  }

  void switchSource(MangaSource newSource, {LibraryProvider? libraryProvider}) {
    _source = newSource;
    SourceManager.currentSource = newSource;
    loadCatalog(libraryProvider: libraryProvider);
  }

  Future<void> loadCatalog({LibraryProvider? libraryProvider}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allManga = await _source.getCatalog(filters: _filters);
      applyLocalFilters(libraryProvider);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateFilters(CatalogFilters newFilters, LibraryProvider? libraryProvider) {
    _filters = newFilters;
    // Если поменялся текст поиска, типы, рейтинг или жанры — запрашиваем API
    loadCatalog(libraryProvider: libraryProvider);
  }

  /// Быстрая локальная фильтрация без повторного запроса в сеть
  /// (например, когда пользователь изменил статус исключения «Читаю» / «Прочитано»)
  void applyLocalFilters(LibraryProvider? libraryProvider) {
    if (libraryProvider == null) {
      _filteredManga = _allManga.where((manga) {
        if (_filters.hideLicensed && manga.isLicensed) return false;
        if (_filters.statusFilter != null) {
          if (_filters.statusFilter == 'ongoing' && manga.statusLabel != 'Онгоинг') return false;
          if (_filters.statusFilter == 'completed' && manga.statusLabel != 'Закончен') return false;
        }
        return true;
      }).toList();
      notifyListeners();
      return;
    }

    _filteredManga = _allManga.where((manga) {
      // Исключаем лицензированные тайтлы
      if (_filters.hideLicensed && manga.isLicensed) {
        return false;
      }
      // Фильтр статуса (Онгоинг / Закончен)
      if (_filters.statusFilter != null) {
        if (_filters.statusFilter == 'ongoing' && manga.statusLabel != 'Онгоинг') return false;
        if (_filters.statusFilter == 'completed' && manga.statusLabel != 'Закончен') return false;
      }
      // Исключаем по статусам библиотеки
      if (libraryProvider.shouldExclude(manga.id, _filters)) {
        return false;
      }
      return true;
    }).toList();

    notifyListeners();
  }
}
