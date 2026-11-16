import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:manga_reader_app/features/books/models/book_item.dart';

class BookOfflineStore {
  static final RegExp _validIdRegex = RegExp(r'^[a-zA-Z0-9_-]{1,100}$');
  static const String _subdirName = 'books_offline_v1';
  static const int _maxFileSizeBytes = 16 * 1024 * 1024; // 16 MiB

  final Future<Directory> Function()? directoryProvider;

  BookOfflineStore({this.directoryProvider});

  Future<Directory> _getBaseDirectory() async {
    if (directoryProvider != null) {
      return await directoryProvider!();
    }
    return await getApplicationSupportDirectory();
  }

  Future<Directory> _getStorageDirectory() async {
    final baseDir = await _getBaseDirectory();
    final storagePath = p.join(baseDir.path, _subdirName);
    final type = await FileSystemEntity.type(storagePath, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw FileSystemException('Storage directory is a symlink', storagePath);
    }
    final storageDir = Directory(storagePath);
    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }
    return storageDir;
  }

  bool _isValidId(String id) {
    return _validIdRegex.hasMatch(id);
  }

  Future<void> save(BookItem book, List<BookChapter> chapters) async {
    if (!_isValidId(book.id)) {
      throw ArgumentError('Malformed book id: "${book.id}"');
    }

    if (chapters.isEmpty) {
      throw ArgumentError('Cannot save empty chapter list as downloaded');
    }

    final hasNonEmptyBody = chapters.any((c) => c.content.trim().isNotEmpty);
    if (!hasNonEmptyBody) {
      throw ArgumentError('Cannot save chapters with empty bodies as downloaded');
    }

    final payload = {
      'version': 1,
      'book': {
        'id': book.id,
        'title': book.title,
        'author': book.author,
        'genre': book.genre,
        'coverUrl': book.coverUrl,
        'description': book.description,
        'year': book.year,
        'rating': book.rating,
        'isFree': book.isFree,
        'availableFormats': book.availableFormats,
      },
      'chapters': chapters
          .map(
            (c) => {
              'id': c.id,
              'number': c.number,
              'title': c.title,
              'content': c.content,
            },
          )
          .toList(),
    };

    final jsonString = jsonEncode(payload);
    final utf8Bytes = Uint8List.fromList(utf8.encode(jsonString));
    if (utf8Bytes.length > _maxFileSizeBytes) {
      throw ArgumentError(
        'Payload size exceeds 16MiB limit (${utf8Bytes.length} bytes)',
      );
    }

    final storageDir = await _getStorageDirectory();
    final stagingDir = await storageDir.createTemp('staging_');
    final tempFile = File(p.join(stagingDir.path, '${book.id}.json'));
    final finalFile = File(p.join(storageDir.path, '${book.id}.json'));

    try {
      await tempFile.writeAsBytes(utf8Bytes, flush: true);
      await tempFile.rename(finalFile.path);
    } finally {
      try {
        if (await stagingDir.exists()) {
          await stagingDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  Future<BookItem?> load(String id) async {
    if (!_isValidId(id)) {
      return null;
    }

    final baseDir = await _getBaseDirectory();
    final storagePath = p.join(baseDir.path, _subdirName);
    final dirType = await FileSystemEntity.type(storagePath, followLinks: false);
    if (dirType == FileSystemEntityType.link) {
      return null;
    }
    final storageDir = Directory(storagePath);
    if (!await storageDir.exists()) {
      return null;
    }

    final filePath = p.join(storageDir.path, '$id.json');
    final fileType = await FileSystemEntity.type(filePath, followLinks: false);
    if (fileType != FileSystemEntityType.file) {
      return null;
    }

    final file = File(filePath);
    return await _readAndParseFile(file, expectedId: id);
  }

  Future<List<BookItem>> list() async {
    final baseDir = await _getBaseDirectory();
    final storagePath = p.join(baseDir.path, _subdirName);
    final dirType = await FileSystemEntity.type(storagePath, followLinks: false);
    if (dirType == FileSystemEntityType.link) {
      return [];
    }
    final storageDir = Directory(storagePath);
    if (!await storageDir.exists()) {
      return [];
    }

    final List<BookItem> results = [];
    final entries = storageDir.list(followLinks: false);

    await for (final entity in entries) {
      final entityType = await FileSystemEntity.type(entity.path, followLinks: false);
      if (entityType != FileSystemEntityType.file) {
        continue;
      }

      final basename = p.basename(entity.path);
      if (!basename.endsWith('.json') ||
          basename.contains('.tmp') ||
          basename.startsWith('.')) {
        continue;
      }

      final idFromFilename = basename.substring(0, basename.length - '.json'.length);
      if (!_isValidId(idFromFilename)) {
        continue;
      }

      final book = await _readAndParseFile(File(entity.path), expectedId: idFromFilename);
      if (book != null) {
        results.add(book);
      }
    }

    return results;
  }

  Future<void> remove(String id) async {
    if (!_isValidId(id)) {
      return;
    }

    final baseDir = await _getBaseDirectory();
    final storagePath = p.join(baseDir.path, _subdirName);
    final dirType = await FileSystemEntity.type(storagePath, followLinks: false);
    if (dirType == FileSystemEntityType.link) {
      return;
    }
    final storageDir = Directory(storagePath);
    if (!await storageDir.exists()) {
      return;
    }

    final file = File(p.join(storageDir.path, '$id.json'));
    final fileType = await FileSystemEntity.type(file.path, followLinks: false);
    if (fileType == FileSystemEntityType.notFound) {
      return;
    }

    await file.delete();
  }

  Future<BookItem?> _readAndParseFile(File file, {required String expectedId}) async {
    try {
      final fileType = await FileSystemEntity.type(file.path, followLinks: false);
      if (fileType != FileSystemEntityType.file) {
        return null;
      }

      final stat = await file.stat();
      if (stat.size > _maxFileSizeBytes) {
        return null;
      }

      final contents = await file.readAsString();
      final dynamic decoded = jsonDecode(contents);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      if (decoded['version'] != 1) {
        return null;
      }

      final bookMap = decoded['book'];
      if (bookMap is! Map<String, dynamic>) {
        return null;
      }

      final embeddedId = bookMap['id'];
      if (embeddedId != expectedId) {
        return null;
      }

      final chaptersRaw = decoded['chapters'];
      if (chaptersRaw is! List || chaptersRaw.isEmpty) {
        return null;
      }

      final List<BookChapter> chapters = [];
      for (final rawChap in chaptersRaw) {
        if (rawChap is! Map<String, dynamic>) {
          return null;
        }
        final cId = rawChap['id'];
        final cNumber = rawChap['number'];
        final cTitle = rawChap['title'];
        final cContent = rawChap['content'];
        if (cId is! String || cNumber is! String || cTitle is! String || cContent is! String) {
          return null;
        }
        chapters.add(
          BookChapter(
            id: cId,
            number: cNumber,
            title: cTitle,
            content: cContent,
          ),
        );
      }

      if (chapters.isEmpty || !chapters.any((c) => c.content.trim().isNotEmpty)) {
        return null;
      }

      final title = bookMap['title'];
      final author = bookMap['author'];
      final genre = bookMap['genre'];
      final coverUrl = bookMap['coverUrl'];
      final description = bookMap['description'];
      final year = bookMap['year'];
      final rating = bookMap['rating'];
      final isFree = bookMap['isFree'];
      final availableFormatsRaw = bookMap['availableFormats'];

      if (title is! String ||
          author is! String ||
          genre is! String ||
          coverUrl is! String ||
          description is! String ||
          year is! int) {
        return null;
      }

      if (rating is! num || !rating.toDouble().isFinite) {
        return null;
      }

      if (isFree is! bool) {
        return null;
      }

      if (availableFormatsRaw is! List) {
        return null;
      }

      final List<String> availableFormats = [];
      for (final fmt in availableFormatsRaw) {
        if (fmt is! String) {
          return null;
        }
        availableFormats.add(fmt);
      }

      return BookItem(
        id: embeddedId,
        title: title,
        author: author,
        genre: genre,
        coverUrl: coverUrl,
        description: description,
        year: year,
        rating: rating.toDouble(),
        chapters: chapters,
        isFree: isFree,
        availableFormats: availableFormats,
      );
    } catch (_) {
      return null;
    }
  }
}
