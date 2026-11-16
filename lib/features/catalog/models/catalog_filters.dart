import '../../../core/widgets/tri_state_chip.dart';
export '../../../core/widgets/tri_state_chip.dart' show FilterTriState;
import 'manga.dart';

class CatalogFilters {
  // Статусы личной библиотеки (с логикой исключения)
  FilterTriState readingStatus;
  FilterTriState completedStatus;
  FilterTriState plannedStatus;

  // Тип контента: Манхва, Манга, Маньхуа
  Set<PublicationType> publicationTypes;

  // Возрастной рейтинг: 0+, 16+, 18+
  Set<ContentRating> contentRatings;

  // Жанры
  Set<String> selectedGenreIds;

  // Compatibility getters/setters for query and genres
  String get query => searchQuery;
  set query(String val) => searchQuery = val;

  Set<String> get includedGenres => selectedGenreIds;
  set includedGenres(Set<String> val) => selectedGenreIds = val;

  Set<String> excludedGenres = {};

  // Поисковая строка
  String searchQuery;

  // Исключить лицензированные тайтлы
  bool hideLicensed;

  // Сортировка: -rating, -id, -count_chapters, -total_views
  String ordering;

  // Фильтр статуса: null, 'ongoing', 'completed'
  String? statusFilter;

  CatalogFilters({
    this.readingStatus = FilterTriState.ignore,
    this.completedStatus = FilterTriState.ignore,
    this.plannedStatus = FilterTriState.ignore,
    Set<PublicationType>? publicationTypes,
    Set<ContentRating>? contentRatings,
    Set<String>? selectedGenreIds,
    this.searchQuery = '',
    this.hideLicensed = false,
    this.ordering = '-rating',
    this.statusFilter,
  })  : publicationTypes = publicationTypes ?? {PublicationType.manhwa, PublicationType.manga, PublicationType.manhua},
        contentRatings = contentRatings ?? {ContentRating.safe, ContentRating.suggestive},
        selectedGenreIds = selectedGenreIds ?? {};

  CatalogFilters clone() {
    final cloned = CatalogFilters(
      readingStatus: readingStatus,
      completedStatus: completedStatus,
      plannedStatus: plannedStatus,
      publicationTypes: Set.from(publicationTypes),
      contentRatings: Set.from(contentRatings),
      selectedGenreIds: Set.from(selectedGenreIds),
      searchQuery: searchQuery,
      hideLicensed: hideLicensed,
      ordering: ordering,
      statusFilter: statusFilter,
    );
    cloned.excludedGenres = Set.from(excludedGenres);
    return cloned;
  }

  void reset() {
    readingStatus = FilterTriState.ignore;
    completedStatus = FilterTriState.ignore;
    plannedStatus = FilterTriState.ignore;
    publicationTypes = {PublicationType.manhwa, PublicationType.manga, PublicationType.manhua};
    contentRatings = {ContentRating.safe, ContentRating.suggestive};
    selectedGenreIds = {};
    excludedGenres = {};
    searchQuery = '';
    hideLicensed = false;
    ordering = '-rating';
    statusFilter = null;
  }

  FilterTriState getGenreState(String genreId) {
    if (selectedGenreIds.contains(genreId)) return FilterTriState.include;
    if (excludedGenres.contains(genreId)) return FilterTriState.exclude;
    return FilterTriState.ignore;
  }

  void setGenreState(String genreId, FilterTriState state) {
    switch (state) {
      case FilterTriState.ignore:
        selectedGenreIds.remove(genreId);
        excludedGenres.remove(genreId);
        break;
      case FilterTriState.include:
        selectedGenreIds.add(genreId);
        excludedGenres.remove(genreId);
        break;
      case FilterTriState.exclude:
        selectedGenreIds.remove(genreId);
        excludedGenres.add(genreId);
        break;
    }
  }

  void clearGenres() {
    selectedGenreIds.clear();
    excludedGenres.clear();
  }

  int get activeFiltersCount {
    int count = 0;
    if (readingStatus != FilterTriState.ignore) count++;
    if (completedStatus != FilterTriState.ignore) count++;
    if (plannedStatus != FilterTriState.ignore) count++;
    if (publicationTypes.length < 3) count++;
    if (contentRatings.contains(ContentRating.erotica) || contentRatings.length < 2) count++;
    if (selectedGenreIds.isNotEmpty) count += selectedGenreIds.length;
    if (excludedGenres.isNotEmpty) count += excludedGenres.length;
    if (hideLicensed) count++;
    return count;
  }
}
