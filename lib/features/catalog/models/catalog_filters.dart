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
    return CatalogFilters(
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
  }

  void reset() {
    readingStatus = FilterTriState.ignore;
    completedStatus = FilterTriState.ignore;
    plannedStatus = FilterTriState.ignore;
    publicationTypes = {PublicationType.manhwa, PublicationType.manga, PublicationType.manhua};
    contentRatings = {ContentRating.safe, ContentRating.suggestive};
    selectedGenreIds = {};
    searchQuery = '';
    hideLicensed = false;
    ordering = '-rating';
    statusFilter = null;
  }

  int get activeFiltersCount {
    int count = 0;
    if (readingStatus != FilterTriState.ignore) count++;
    if (completedStatus != FilterTriState.ignore) count++;
    if (plannedStatus != FilterTriState.ignore) count++;
    if (publicationTypes.length < 3) count++;
    if (contentRatings.contains(ContentRating.erotica) || contentRatings.length < 2) count++;
    if (selectedGenreIds.isNotEmpty) count += selectedGenreIds.length;
    if (hideLicensed) count++;
    return count;
  }
}
