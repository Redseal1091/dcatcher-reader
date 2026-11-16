import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_reader_app/features/books/services/fb2_book_parser.dart';

void main() {
  group('Fb2BookParser Tests', () {
    const sampleFb2Xml = '''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <genre>sf</genre>
      <author>
        <first-name>Айзек</first-name>
        <last-name>Азимов</last-name>
      </author>
      <book-title>Основание</book-title>
      <annotation>
        <p>Галактическая империя рушится.</p>
      </annotation>
    </title-info>
  </description>
  <body>
    <title>
      <p>Основание</p>
    </title>
    <section>
      <title>
        <p>Глава 1: Психоисторики</p>
      </title>
      <p>Гэри Селдон стоял перед трибуналом.</p>
      <p>Его математические вычисления были неопровержимы.</p>
    </section>
    <section>
      <title>
        <p>Глава 2: Энциклопедисты</p>
      </title>
      <p>Прошло пятьдесят лет с момента суда.</p>
      <p>Терминус развивался по плану Селдона.</p>
    </section>
  </body>
</FictionBook>''';

    test('parses uncompressed FB2 xml string into chapters and metadata', () {
      final parser = Fb2BookParser();
      final result = parser.parseString(sampleFb2Xml);

      expect(result.title, 'Основание');
      expect(result.author, 'Айзек Азимов');
      expect(result.annotation, contains('Галактическая империя'));
      expect(result.chapters.length, 2);

      // Chapter 1 assertions
      final ch1 = result.chapters[0];
      expect(ch1.number, '1');
      expect(ch1.title, 'Глава 1: Психоисторики');
      expect(ch1.content, contains('Гэри Селдон стоял перед трибуналом.'));
      expect(ch1.content, contains('Его математические вычисления были неопровержимы.'));

      // Chapter 2 assertions
      final ch2 = result.chapters[1];
      expect(ch2.number, '2');
      expect(ch2.title, 'Глава 2: Энциклопедисты');
      expect(ch2.content, contains('Прошло пятьдесят лет с момента суда.'));
      expect(ch2.content, contains('Терминус развивался по плану Селдона.'));
    });

    test('parses FB2 with nested sections and poem stanzas', () {
      const nestedFb2Xml = '''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <book-title>Сборник стихов</book-title>
      <author><last-name>Пушкин</last-name></author>
    </title-info>
  </description>
  <body>
    <section>
      <title><p>Часть I</p></title>
      <section>
        <title><p>Глава первая</p></title>
        <p>Мой дядя самых честных правил,</p>
        <poem>
          <stanza>
            <v>Когда не в шутку занемог,</v>
            <v>Он уважать себя заставил</v>
          </stanza>
        </poem>
      </section>
    </section>
  </body>
</FictionBook>''';

      final parser = Fb2BookParser();
      final result = parser.parseString(nestedFb2Xml);

      expect(result.chapters.length, 1);
      final ch = result.chapters[0];
      expect(ch.title, 'Глава первая');
      expect(ch.content, contains('Мой дядя самых честных правил'));
      expect(ch.content, contains('Когда не в шутку занемог'));
      expect(ch.content, contains('Он уважать себя заставил'));
    });

    test('parses compressed .fb2.zip bytes', () {
      // Create in-memory zip archive with test.fb2 inside
      final archive = Archive();
      final xmlBytes = utf8.encode(sampleFb2Xml);
      archive.addFile(ArchiveFile('foundation.fb2', xmlBytes.length, xmlBytes));
      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final parser = Fb2BookParser();
      final result = parser.parseBytes(zipBytes);

      expect(result.title, 'Основание');
      expect(result.chapters.length, 2);
      expect(result.chapters[0].title, 'Глава 1: Психоисторики');
    });

    test('throws FormatException on empty or non-XML bytes', () {
      final parser = Fb2BookParser();
      expect(() => parser.parseBytes(Uint8List(0)), throwsA(isA<FormatException>()));
      expect(() => parser.parseString('this is not xml'), throwsA(isA<FormatException>()));
    });
  });
}
