import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';
import '../models/book_item.dart';

class ParsedEpub {
  final String title;
  final String author;
  final String description;
  final List<BookChapter> chapters;

  const ParsedEpub({
    required this.title,
    required this.author,
    this.description = '',
    required this.chapters,
  });
}

class EpubBookParser {
  /// Разбор EPUB из массива байтов архива
  ParsedEpub parseBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('Empty EPUB bytes');
    }

    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw const FormatException('Invalid EPUB archive signature (not a ZIP archive)');
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (e) {
      throw FormatException('Failed to decompress EPUB archive: $e');
    }

    final fileMap = <String, ArchiveFile>{};
    for (final file in archive) {
      final normalizedName = file.name.replaceAll('\\', '/').toLowerCase();
      fileMap[normalizedName] = file;
    }

    // 1. Читаем META-INF/container.xml
    final containerFile = fileMap['meta-inf/container.xml'];
    if (containerFile == null || containerFile.content == null) {
      throw const FormatException('Missing META-INF/container.xml in EPUB');
    }

    final containerXml = utf8.decode(containerFile.content as List<int>, allowMalformed: true);
    final XmlDocument containerDoc;
    try {
      containerDoc = XmlDocument.parse(containerXml);
    } catch (e) {
      throw FormatException('Malformed META-INF/container.xml: $e');
    }

    final rootfileEl = containerDoc.findAllElements('rootfile').firstOrNull;
    final opfPath = rootfileEl?.getAttribute('full-path')?.replaceAll('\\', '/');
    if (opfPath == null || opfPath.isEmpty) {
      throw const FormatException('No rootfile path found in META-INF/container.xml');
    }

    // 2. Читаем .opf файл пакета (OPF)
    final opfFile = fileMap[opfPath.toLowerCase()];
    if (opfFile == null || opfFile.content == null) {
      throw FormatException('Package OPF file not found in EPUB: $opfPath');
    }

    final opfXml = utf8.decode(opfFile.content as List<int>, allowMalformed: true);
    final XmlDocument opfDoc;
    try {
      opfDoc = XmlDocument.parse(opfXml);
    } catch (e) {
      throw FormatException('Malformed package OPF XML: $e');
    }

    // Каталог OPF файла для разрешения относительных путей
    final opfDir = opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1) : '';

    // 3. Метаданные книги
    String title = '';
    String author = '';
    String description = '';

    for (final el in opfDoc.findAllElements('dc:title')) {
      if (el.innerText.trim().isNotEmpty) {
        title = el.innerText.trim();
        break;
      }
    }
    if (title.isEmpty) {
      for (final el in opfDoc.findAllElements('title')) {
        if (el.innerText.trim().isNotEmpty) {
          title = el.innerText.trim();
          break;
        }
      }
    }

    for (final el in opfDoc.findAllElements('dc:creator')) {
      if (el.innerText.trim().isNotEmpty) {
        author = el.innerText.trim();
        break;
      }
    }
    if (author.isEmpty) {
      for (final el in opfDoc.findAllElements('creator')) {
        if (el.innerText.trim().isNotEmpty) {
          author = el.innerText.trim();
          break;
        }
      }
    }

    for (final el in opfDoc.findAllElements('dc:description')) {
      if (el.innerText.trim().isNotEmpty) {
        description = el.innerText.trim();
        break;
      }
    }

    // 4. Манифест: id -> относительный путь к файлу
    final manifestMap = <String, String>{};
    for (final item in opfDoc.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) {
        final fullItemPath = (opfDir + href).replaceAll('\\', '/');
        manifestMap[id] = fullItemPath;
      }
    }

    // 5. Spine: порядок чтения глав
    final spineIds = <String>[];
    for (final itemref in opfDoc.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      if (idref != null && manifestMap.containsKey(idref)) {
        spineIds.add(idref);
      }
    }

    // 6. Извлечение глав в порядке spine
    final chapters = <BookChapter>[];

    for (final id in spineIds) {
      final itemPath = manifestMap[id]!;
      final chapterFile = fileMap[itemPath.toLowerCase()];
      if (chapterFile == null || chapterFile.content == null) continue;

      final chapterHtml = utf8.decode(chapterFile.content as List<int>, allowMalformed: true);
      final document = html_parser.parse(chapterHtml);

      // Извлечение заголовка главы
      String chapterTitle = '';
      final headerEl = document.querySelector('h1, h2, h3, title');
      if (headerEl != null && headerEl.text.trim().isNotEmpty) {
        chapterTitle = headerEl.text.trim();
      }

      // Извлечение абзацев текста
      final paragraphs = <String>[];
      final pElements = document.querySelectorAll('p');
      if (pElements.isNotEmpty) {
        for (final p in pElements) {
          final t = p.text.trim();
          if (t.isNotEmpty) paragraphs.add(t);
        }
      } else {
        // Если нет тегов <p>, берем текст body, разбивая по строкам
        final bodyText = document.body?.text.trim() ?? '';
        final lines = bodyText.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty);
        paragraphs.addAll(lines);
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

    if (chapters.isEmpty) {
      throw const FormatException('No readable text chapters found in EPUB spine');
    }

    return ParsedEpub(
      title: title,
      author: author,
      description: description,
      chapters: chapters,
    );
  }
}
