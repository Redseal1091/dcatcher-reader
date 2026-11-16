import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manga_reader_app/features/library/models/book_shelf_item.dart';
import 'package:manga_reader_app/features/library/state/book_shelf_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookShelfItem Model', () {
    test('serialization and deserialization preserve all required fields', () {
      final now = DateTime(2026, 11, 12, 12, 0, 0);
      final item = BookShelfItem(
        id: 'book_123',
        title: 'Война и мир',
        author: 'Лев Толстой',
        genre: 'Классика',
        year: 1869,
        coverUrl: 'https://example.com/cover.jpg',
        description: 'Роман-эпопея',
        availableFormats: const ['epub', 'fb2', 'pdf'],
        addedAt: now,
      );

      final jsonMap = item.toJson();
      expect(jsonMap['id'], 'book_123');
      expect(jsonMap['title'], 'Война и мир');
      expect(jsonMap['author'], 'Лев Толстой');
      expect(jsonMap['genre'], 'Классика');
      expect(jsonMap['year'], 1869);
      expect(jsonMap['coverUrl'], 'https://example.com/cover.jpg');
      expect(jsonMap['description'], 'Роман-эпопея');
      expect(jsonMap['availableFormats'], ['epub', 'fb2', 'pdf']);
      expect(jsonMap['addedAt'], now.toIso8601String());

      final restored = BookShelfItem.fromJson(jsonMap);
      expect(restored.id, item.id);
      expect(restored.title, item.title);
      expect(restored.author, item.author);
      expect(restored.genre, item.genre);
      expect(restored.year, item.year);
      expect(restored.coverUrl, item.coverUrl);
      expect(restored.description, item.description);
      expect(restored.availableFormats, item.availableFormats);
      expect(restored.addedAt, item.addedAt);
      expect(restored, equals(item));
    });

    test('fromJson throws FormatException on missing or empty id/title', () {
      expect(
        () => BookShelfItem.fromJson({'title': 'No ID'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BookShelfItem.fromJson({'id': '', 'title': 'Empty ID'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BookShelfItem.fromJson({'id': 'valid_id', 'title': ''}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('BookShelfProvider State & Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('fresh provider starts empty and marks isLoaded true', () async {
      final provider = BookShelfProvider();
      await provider.loadShelf();

      expect(provider.isLoaded, isTrue);
      expect(provider.items, isEmpty);
      expect(provider.count, 0);
    });

    test('addBook persists to user_book_shelf_v1 and updates items', () async {
      final provider = BookShelfProvider();
      await provider.loadShelf();

      final book1 = BookShelfItem(
        id: 'book_1',
        title: 'Мастер и Маргарита',
        author: 'Михаил Булгаков',
        genre: 'Роман',
        year: 1967,
        coverUrl: '',
        description: 'Мистический роман',
        availableFormats: const ['epub'],
        addedAt: DateTime(2026, 1, 1),
      );

      await provider.addBook(book1);

      expect(provider.items.length, 1);
      expect(provider.contains('book_1'), isTrue);
      expect(provider.getById('book_1')?.title, 'Мастер и Маргарита');

      // Verify SharedPreferences persistence
      final prefs = await SharedPreferences.getInstance();
      final storedRaw = prefs.getString(BookShelfProvider.storageKey);
      expect(storedRaw, isNotNull);

      final decoded = jsonDecode(storedRaw!) as Map<String, dynamic>;
      expect(decoded['version'], 1);
      final itemsList = decoded['items'] as List<dynamic>;
      expect(itemsList.length, 1);
      expect(itemsList[0]['id'], 'book_1');
    });

    test('rehydration restores items accurately from storage', () async {
      final storedData = {
        'version': 1,
        'items': [
          {
            'id': 'book_persist_1',
            'title': 'Преступление и наказание',
            'author': 'Федор Достоевский',
            'genre': 'Классика',
            'year': 1866,
            'coverUrl': '',
            'description': 'Психологический роман',
            'availableFormats': ['fb2'],
            'addedAt': '2026-05-01T10:00:00.000',
          }
        ],
      };

      SharedPreferences.setMockInitialValues({
        BookShelfProvider.storageKey: jsonEncode(storedData),
      });

      final provider = BookShelfProvider();
      await provider.loadShelf();

      expect(provider.items.length, 1);
      expect(provider.contains('book_persist_1'), isTrue);
      final loaded = provider.getById('book_persist_1');
      expect(loaded?.title, 'Преступление и наказание');
      expect(loaded?.author, 'Федор Достоевский');
      expect(loaded?.year, 1866);
    });

    test('deterministic newest-first ordering by addedAt', () async {
      final provider = BookShelfProvider();
      await provider.loadShelf();

      final oldBook = BookShelfItem(
        id: 'b_old',
        title: 'Старая книга',
        addedAt: DateTime(2025, 1, 1),
      );
      final midBook = BookShelfItem(
        id: 'b_mid',
        title: 'Средняя книга',
        addedAt: DateTime(2026, 1, 1),
      );
      final newBook = BookShelfItem(
        id: 'b_new',
        title: 'Новая книга',
        addedAt: DateTime(2026, 6, 1),
      );

      // Add in arbitrary order
      await provider.addBook(midBook);
      await provider.addBook(oldBook);
      await provider.addBook(newBook);

      final items = provider.items;
      expect(items.length, 3);
      expect(items[0].id, 'b_new');
      expect(items[1].id, 'b_mid');
      expect(items[2].id, 'b_old');
    });

    test('idempotent add and update', () async {
      final provider = BookShelfProvider();
      await provider.loadShelf();

      final book = BookShelfItem(
        id: 'same_id',
        title: 'Первая редакция',
        addedAt: DateTime(2026, 1, 1),
      );
      await provider.addBook(book);
      expect(provider.items.length, 1);
      expect(provider.getById('same_id')?.title, 'Первая редакция');

      // Update same ID
      final updated = BookShelfItem(
        id: 'same_id',
        title: 'Вторая редакция',
        addedAt: DateTime(2026, 1, 1),
      );
      await provider.addBook(updated);
      expect(provider.items.length, 1);
      expect(provider.getById('same_id')?.title, 'Вторая редакция');
    });

    test('removeBook removes item and persists change', () async {
      final provider = BookShelfProvider();
      await provider.loadShelf();

      final book = BookShelfItem(
        id: 'del_1',
        title: 'Удаляемая книга',
        addedAt: DateTime.now(),
      );
      await provider.addBook(book);
      expect(provider.contains('del_1'), isTrue);

      await provider.removeBook('del_1');
      expect(provider.contains('del_1'), isFalse);
      expect(provider.items, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      final storedRaw = prefs.getString(BookShelfProvider.storageKey);
      final decoded = jsonDecode(storedRaw!) as Map<String, dynamic>;
      expect((decoded['items'] as List).isEmpty, isTrue);
    });

    test('corrupt entries isolated without failing valid entries', () async {
      final mixedData = {
        'version': 1,
        'items': [
          // Valid
          {
            'id': 'valid_1',
            'title': 'Хорошая книга',
            'addedAt': '2026-01-01T00:00:00.000',
          },
          // Corrupt: missing id
          {
            'title': 'Нет ID',
          },
          // Corrupt: not a map
          'invalid_string_entry',
          // Corrupt: missing title
          {
            'id': 'corrupt_no_title',
          },
          // Valid
          {
            'id': 'valid_2',
            'title': 'Вторая хорошая книга',
            'addedAt': '2026-02-01T00:00:00.000',
          },
        ],
      };

      SharedPreferences.setMockInitialValues({
        BookShelfProvider.storageKey: jsonEncode(mixedData),
      });

      final provider = BookShelfProvider();
      await provider.loadShelf();

      expect(provider.isLoaded, isTrue);
      expect(provider.items.length, 2);
      expect(provider.contains('valid_1'), isTrue);
      expect(provider.contains('valid_2'), isTrue);
      expect(provider.contains('corrupt_no_title'), isFalse);
    });

    test('corrupt non-json string in storage handled gracefully', () async {
      SharedPreferences.setMockInitialValues({
        BookShelfProvider.storageKey: '<<<corrupt NOT JSON>>>',
      });

      final provider = BookShelfProvider();
      await provider.loadShelf();

      expect(provider.isLoaded, isTrue);
      expect(provider.items, isEmpty);
    });
  });
}
