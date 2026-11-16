import 'book_item.dart';

/// Represents a single page of books loaded from a catalog source with an optional next page link.
class BookCatalogPage {
  final List<BookItem> items;
  final Uri? nextPageUri;
  final Uri? documentUri;

  const BookCatalogPage({
    required this.items,
    this.nextPageUri,
    this.documentUri,
  });
}
