import 'package:manga_reader_app/features/books/models/book_item.dart';
import 'package:manga_reader_app/features/books/services/book_offline_store.dart';

/// Test helper providing an in-memory/no-op offline store that avoids
/// invoking host path_provider or performing real disk IO.
class EmptyBookOfflineStore extends BookOfflineStore {
  @override
  Future<BookItem?> load(String id) async => null;

  @override
  Future<List<BookItem>> list() async => [];

  @override
  Future<void> save(BookItem book, List<BookChapter> chapters) async {}

  @override
  Future<void> remove(String id) async {}
}
