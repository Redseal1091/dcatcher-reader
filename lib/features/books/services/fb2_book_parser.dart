import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../models/book_item.dart';

class ParsedBook {
  final String title;
  final String author;
  final String genre;
  final String annotation;
  final List<BookChapter> chapters;

  const ParsedBook({
    required this.title,
    required this.author,
    this.genre = '',
    this.annotation = '',
    required this.chapters,
  });
}

class Fb2BookParser {
  /// Разбор FB2 из байтов (поддерживает как сырой .fb2, так и сжатый .fb2.zip)
  ParsedBook parseBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('Empty FB2 bytes');
    }

    Uint8List rawFb2Bytes;
    // Проверка сигнатуры ZIP (0x50, 0x4B / 'PK')
    if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      try {
        final archive = ZipDecoder().decodeBytes(bytes, verify: false);
        ArchiveFile? fb2File;
        for (final file in archive) {
          final nameLower = file.name.toLowerCase();
          if (nameLower.endsWith('.fb2') || nameLower.endsWith('.xml')) {
            fb2File = file;
            break;
          }
        }
        fb2File ??= archive.files.isNotEmpty ? archive.files.first : null;
        if (fb2File == null || fb2File.content == null) {
          throw const FormatException('No valid FB2 file in ZIP archive');
        }
        rawFb2Bytes = fb2File.content as Uint8List;
      } catch (e) {
        if (e is FormatException) rethrow;
        throw FormatException('Failed to decompress FB2.zip: $e');
      }
    } else {
      rawFb2Bytes = bytes;
    }

    final xmlString = utf8.decode(rawFb2Bytes, allowMalformed: true);
    return parseString(xmlString);
  }

  /// Разбор FB2 из XML строки
  ParsedBook parseString(String xmlString) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xmlString);
    } catch (e) {
      throw FormatException('Invalid FB2 XML structure: $e');
    }

    final root = document.findElements('FictionBook').firstOrNull ?? document.rootElement;
    if (root.localName != 'FictionBook') {
      throw const FormatException('XML root is not FictionBook');
    }

    // 1. Извлечение метаданных (title-info)
    String title = '';
    String author = '';
    String genre = '';
    String annotation = '';

    final description = root.findElements('description').firstOrNull;
    if (description != null) {
      final titleInfo = description.findElements('title-info').firstOrNull;
      if (titleInfo != null) {
        title = titleInfo.findElements('book-title').firstOrNull?.innerText.trim() ?? '';
        genre = titleInfo.findElements('genre').firstOrNull?.innerText.trim() ?? '';

        final authorEl = titleInfo.findElements('author').firstOrNull;
        if (authorEl != null) {
          final first = authorEl.findElements('first-name').firstOrNull?.innerText.trim() ?? '';
          final middle = authorEl.findElements('middle-name').firstOrNull?.innerText.trim() ?? '';
          final last = authorEl.findElements('last-name').firstOrNull?.innerText.trim() ?? '';
          author = [first, middle, last].where((s) => s.isNotEmpty).join(' ');
        }

        final annotationEl = titleInfo.findElements('annotation').firstOrNull;
        if (annotationEl != null) {
          annotation = annotationEl.findElements('p').map((p) => p.innerText.trim()).where((s) => s.isNotEmpty).join('\n\n');
        }
      }
    }

    // 2. Извлечение тела книги (body)
    final bodies = root.findElements('body').toList();
    if (bodies.isEmpty) {
      throw const FormatException('FictionBook contains no <body>');
    }

    // Игнорируем body с сносками/примечаниями (name="notes") для основных глав
    XmlElement mainBody = bodies.first;
    for (final b in bodies) {
      final name = b.getAttribute('name')?.toLowerCase();
      if (name != 'notes' && name != 'comments') {
        mainBody = b;
        break;
      }
    }

    final chapters = <BookChapter>[];
    final sections = mainBody.findElements('section').toList();

    if (sections.isNotEmpty) {
      for (final sec in sections) {
        _processSection(sec, chapters);
      }
    } else {
      // Книга без разделов <section>, текст прямо в <body>
      final paragraphs = _extractParagraphs(mainBody);
      if (paragraphs.isNotEmpty) {
        chapters.add(
          BookChapter(
            id: 'ch_1',
            number: '1',
            title: title.isNotEmpty ? title : 'Начало',
            content: paragraphs.join('\n\n'),
          ),
        );
      }
    }

    if (chapters.isEmpty) {
      throw const FormatException('FictionBook has no readable text sections');
    }

    return ParsedBook(
      title: title,
      author: author,
      genre: genre,
      annotation: annotation,
      chapters: chapters,
    );
  }

  void _processSection(XmlElement sec, List<BookChapter> chapters) {
    final subSections = sec.findElements('section').toList();
    if (subSections.isNotEmpty) {
      // Секция-родитель содержит подразделы
      for (final sub in subSections) {
        _processSection(sub, chapters);
      }
      return;
    }

    // Листовая секция — это глава
    String chapterTitle = '';
    final titleEl = sec.findElements('title').firstOrNull;
    if (titleEl != null) {
      final titleParts = titleEl.findAllElements('p').map((p) => p.innerText.trim()).where((s) => s.isNotEmpty).toList();
      chapterTitle = titleParts.isNotEmpty ? titleParts.join(' ') : titleEl.innerText.trim();
    }

    final paragraphs = <String>[];
    for (final child in sec.children.whereType<XmlElement>()) {
      if (child.localName == 'title') continue;
      if (child.localName == 'p') {
        final text = child.innerText.trim();
        if (text.isNotEmpty) paragraphs.add(text);
      } else if (child.localName == 'poem') {
        for (final v in child.findAllElements('v')) {
          final verse = v.innerText.trim();
          if (verse.isNotEmpty) paragraphs.add(verse);
        }
      }
    }

    if (paragraphs.isNotEmpty) {
      final index = chapters.length + 1;
      final effectiveTitle = chapterTitle.isNotEmpty ? chapterTitle : 'Глава $index';
      chapters.add(
        BookChapter(
          id: 'ch_$index',
          number: '$index',
          title: effectiveTitle,
          content: paragraphs.join('\n\n'),
        ),
      );
    }
  }

  List<String> _extractParagraphs(XmlElement parent) {
    final paragraphs = <String>[];
    for (final child in parent.children.whereType<XmlElement>()) {
      if (child.localName == 'title') continue;
      if (child.localName == 'p') {
        final text = child.innerText.trim();
        if (text.isNotEmpty) paragraphs.add(text);
      } else if (child.localName == 'poem') {
        for (final v in child.findAllElements('v')) {
          final verse = v.innerText.trim();
          if (verse.isNotEmpty) paragraphs.add(verse);
        }
      }
    }
    return paragraphs;
  }
}
