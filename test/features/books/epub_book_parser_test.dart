import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_reader_app/features/books/services/epub_book_parser.dart';

void main() {
  group('EpubBookParser Tests', () {
    Uint8List createSampleEpubBytes() {
      final archive = Archive();

      // mimetype (must be first, uncompressed in official EPUB, but ZipEncoder handles fine)
      final mimeBytes = utf8.encode('application/epub+zip');
      archive.addFile(ArchiveFile('mimetype', mimeBytes.length, mimeBytes));

      // META-INF/container.xml
      const containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
      final containerBytes = utf8.encode(containerXml);
      archive.addFile(ArchiveFile('META-INF/container.xml', containerBytes.length, containerBytes));

      // OEBPS/content.opf
      const opfXml = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Пикник на обочине</dc:title>
    <dc:creator>Аркадий и Борис Стругацкие</dc:creator>
    <dc:description>Повесть о Зоне и сталкерах.</dc:description>
  </metadata>
  <manifest>
    <item id="ch1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>''';
      final opfBytes = utf8.encode(opfXml);
      archive.addFile(ArchiveFile('OEBPS/content.opf', opfBytes.length, opfBytes));

      // OEBPS/chapter1.xhtml
      const ch1Xhtml = '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Глава 1: Рэдрик Шухарт</title></head>
<body>
  <h1>Глава 1: Рэдрик Шухарт</h1>
  <p>Мы сидели в буфете и пили кофе.</p>
  <p>Зона была рядом, всего в двухстах метрах.</p>
</body>
</html>''';
      final ch1Bytes = utf8.encode(ch1Xhtml);
      archive.addFile(ArchiveFile('OEBPS/chapter1.xhtml', ch1Bytes.length, ch1Bytes));

      // OEBPS/chapter2.xhtml
      const ch2Xhtml = '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Глава 2: В Зоне</title></head>
<body>
  <h1>Глава 2: В Зоне</h1>
  <p>Утренний туман ещё висел над руинами института.</p>
  <p>Рэдрик проверил гайки в кармане.</p>
</body>
</html>''';
      final ch2Bytes = utf8.encode(ch2Xhtml);
      archive.addFile(ArchiveFile('OEBPS/chapter2.xhtml', ch2Bytes.length, ch2Bytes));

      return Uint8List.fromList(ZipEncoder().encode(archive)!);
    }

    test('parses valid EPUB archive bytes into chapters and metadata in spine order', () {
      final epubBytes = createSampleEpubBytes();
      final parser = EpubBookParser();
      final result = parser.parseBytes(epubBytes);

      expect(result.title, 'Пикник на обочине');
      expect(result.author, 'Аркадий и Борис Стругацкие');
      expect(result.description, contains('Повесть о Зоне'));
      expect(result.chapters.length, 2);

      // Chapter 1 assertions
      final ch1 = result.chapters[0];
      expect(ch1.number, '1');
      expect(ch1.title, 'Глава 1: Рэдрик Шухарт');
      expect(ch1.content, contains('Мы сидели в буфете и пили кофе.'));
      expect(ch1.content, contains('Зона была рядом'));

      // Chapter 2 assertions
      final ch2 = result.chapters[1];
      expect(ch2.number, '2');
      expect(ch2.title, 'Глава 2: В Зоне');
      expect(ch2.content, contains('Утренний туман ещё висел'));
      expect(ch2.content, contains('Рэдрик проверил гайки в кармане.'));
    });

    test('throws FormatException on invalid or non-EPUB ZIP bytes', () {
      final parser = EpubBookParser();

      // Empty bytes
      expect(() => parser.parseBytes(Uint8List(0)), throwsA(isA<FormatException>()));

      // Random non-zip bytes
      expect(() => parser.parseBytes(Uint8List.fromList([1, 2, 3, 4, 5])), throwsA(isA<FormatException>()));

      // Valid zip but missing META-INF/container.xml
      final archive = Archive();
      archive.addFile(ArchiveFile('random.txt', 4, utf8.encode('test')));
      final badZip = Uint8List.fromList(ZipEncoder().encode(archive)!);
      expect(() => parser.parseBytes(badZip), throwsA(isA<FormatException>()));
    });
  });
}
