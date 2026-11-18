import 'package:flutter/foundation.dart';
import '../models/manga.dart';
import '../models/catalog_filters.dart';
import '../models/genre.dart';
import '../../sources/manga_source.dart';
import '../../sources/source_manager.dart';
import '../../library/state/library_provider.dart';

class CatalogProvider extends ChangeNotifier {
  MangaSource? _source = SourceManager.currentSource;
  CatalogFilters _filters = CatalogFilters();
  
  List<Manga> _allManga = [];
  List<Manga> _filteredManga = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasNextPage = true;
  int _currentPage = 1;
  String? _errorMessage;
  String? _loadMoreError;
  int _currentRequestId = 0;

  MangaSource? get source => _source;
  CatalogFilters get filters => _filters;
  List<Manga> get mangaList => _filteredManga;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasNextPage => _hasNextPage;
  int get currentPage => _currentPage;
  String? get errorMessage => _errorMessage;
  String? get loadMoreError => _loadMoreError;

  CatalogProvider() {
    loadCatalog();
  }

  void switchSource(MangaSource? newSource, {LibraryProvider? libraryProvider}) {
    _source = newSource;
    if (newSource != null) {
      SourceManager.setCurrentSource(newSource.id);
    }
    loadCatalog(libraryProvider: libraryProvider);
  }

  Future<void> loadCatalog({LibraryProvider? libraryProvider}) async {
    final requestId = ++_currentRequestId;
    _isLoading = true;
    _isLoadingMore = false;
    _errorMessage = null;
    _loadMoreError = null;
    _currentPage = 1;
    _hasNextPage = true;
    // Clear old items immediately so switching source or reloading isolates state
    _allManga = [];
    _filteredManga = [];
    notifyListeners();

    if (_source == null) {
      _isLoading = false;
      _hasNextPage = false;
      notifyListeners();
      return;
    }

    final targetSource = _source!;
    final targetFilters = _filters.clone();

    try {
      final pageResult = await targetSource.getCatalogPage(
        filters: targetFilters,
        page: 1,
      );
      if (requestId != _currentRequestId) return;
      _allManga = List<Manga>.from(pageResult.items);
      _hasNextPage = pageResult.hasNextPage;
      _currentPage = 1;
      applyLocalFilters(libraryProvider);
    } catch (e) {
      if (requestId != _currentRequestId) return;
      _errorMessage = e.toString();
      _hasNextPage = false;
    } finally {
      if (requestId == _currentRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore({LibraryProvider? libraryProvider}) async {
    if (_isLoading || _isLoadingMore || !_hasNextPage || _source == null) {
      return;
    }

    final requestId = _currentRequestId;
    final targetSource = _source!;
    final targetFilters = _filters.clone();
    final nextPage = _currentPage + 1;

    _isLoadingMore = true;
    _loadMoreError = null;
    notifyListeners();

    try {
      final pageResult = await targetSource.getCatalogPage(
        filters: targetFilters,
        page: nextPage,
      );

      if (requestId != _currentRequestId) return;

      // Deduplicate items against existing manga list and within next page using sourceId/id key
      final existingKeys = _allManga.map((m) => '${m.sourceId}:${m.id}').toSet();
      final newItems = <Manga>[];
      for (final m in pageResult.items) {
        if (existingKeys.add('${m.sourceId}:${m.id}')) {
          newItems.add(m);
        }
      }

      _allManga.addAll(newItems);
      _currentPage = nextPage;
      _hasNextPage = pageResult.hasNextPage;
      _loadMoreError = null;
      applyLocalFilters(libraryProvider);
    } catch (e) {
      if (requestId != _currentRequestId) return;
      // Preserve existing items, record loadMoreError, allow retrying the same page
      _loadMoreError = e.toString();
    } finally {
      if (requestId == _currentRequestId) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void updateFilters(CatalogFilters newFilters, LibraryProvider? libraryProvider) {
    _filters = newFilters;
    // Network reload so searches and remote filters invoke native bridge
    loadCatalog(libraryProvider: libraryProvider);
  }

  /// Быстрая локальная фильтрация без повторного запроса в сеть
  /// (например, когда пользователь изменил статус исключения «Читаю» / «Прочитано»)
  void applyLocalFilters(LibraryProvider? libraryProvider) {
    bool matchesFilters(Manga manga) {
      if (_filters.hideLicensed && manga.isLicensed) return false;
      if (_filters.statusFilter != null) {
        final s = manga.status.toLowerCase();
        // Trust remote source results when status isn't provided on catalog cards.
        if (s.isNotEmpty && s != 'unknown') {
          if (_filters.statusFilter == 'ongoing' && manga.statusLabel != 'Онгоинг') return false;
          if (_filters.statusFilter == 'completed' && manga.statusLabel != 'Закончен') return false;
          if (_filters.statusFilter == 'hiatus' && manga.statusLabel != 'Заморожен') return false;
        }
      }
      if (_filters.publicationTypes.isNotEmpty &&
          !_filters.publicationTypes.contains(PublicationType.all)) {
        if (manga.type != PublicationType.all && !_filters.publicationTypes.contains(manga.type)) {
          return false;
        }
      }
      if (libraryProvider != null && libraryProvider.shouldExclude(manga.id, _filters)) {
        return false;
      }
      if (manga.genres.isNotEmpty) {
        if (_filters.excludedGenres.isNotEmpty) {
          for (final excId in _filters.excludedGenres) {
            final genre = MangaGenre.findById(excId);
            if (genre != null && manga.genres.any((g) => genre.matches(g))) {
              return false;
            }
          }
        }
        if (_filters.selectedGenreIds.isNotEmpty) {
          for (final incId in _filters.selectedGenreIds) {
            final genre = MangaGenre.findById(incId);
            if (genre != null && !manga.genres.any((g) => genre.matches(g))) {
              return false;
            }
          }
        }
      }
      return true;
    }

    _filteredManga = _allManga.where(matchesFilters).toList();
    notifyListeners();
  }
}
