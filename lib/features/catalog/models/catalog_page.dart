import 'manga.dart';

class CatalogPage {
  final List<Manga> items;
  final bool hasNextPage;

  const CatalogPage({
    required this.items,
    required this.hasNextPage,
  });
}
