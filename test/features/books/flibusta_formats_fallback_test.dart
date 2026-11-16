import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_reader_app/features/books/services/flibusta_service.dart';

void main() {
  group('FlibustaService FB2/EPUB Fallback Tests', () {
    Uint8List createSampleEpubBytes() {
      final archive = Archive();
      final mimeBytes = utf8.encode('application/epub+zip');
      archive.addFile(ArchiveFile('mimetype', mimeBytes.length, mimeBytes));

      const containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
      final containerBytes = utf8.encode(containerXml);
      archive.addFile(ArchiveFile('META-INF/container.xml', containerBytes.length, containerBytes));

      const opfXml = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>EPUB Book</dc:title>
  </metadata>
  <manifest>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="ch1"/></spine>
</package>''';
      archive.addFile(ArchiveFile('OEBPS/content.opf', opfXml.length, utf8.encode(opfXml)));

      const ch1Xhtml = '''<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Глава 1: Электронная книга</title></head>
<body><h1>Глава 1: Электронная книга</h1><p>Текст первой главы из EPUB.</p></body>
</html>''';
      archive.addFile(ArchiveFile('OEBPS/ch1.xhtml', ch1Xhtml.length, utf8.encode(ch1Xhtml)));

      return Uint8List.fromList(ZipEncoder().encode(archive)!);
    }

    Uint8List createSampleFb2ZipBytes() {
      final archive = Archive();
      const fb2Xml = '''<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description><title-info><book-title>FB2 Book</book-title></title-info></description>
  <body>
    <section>
      <title><p>Глава 1: Формат FB2</p></title>
      <p>Текст первой главы из архива FB2.zip.</p>
    </section>
  </body>
</FictionBook>''';
      final bytes = utf8.encode(fb2Xml);
      archive.addFile(ArchiveFile('book.fb2', bytes.length, bytes));
      return Uint8List.fromList(ZipEncoder().encode(archive)!);
    }

    test('falls back to /epub when /read is 404 and availableFormats includes epub', () async {
      final epubBytes = createSampleEpubBytes();
      final requestedUrls = <String>[];

      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        if (request.url.path.endsWith('/read')) {
          return http.Response('Not Found', 404);
        }
        if (request.url.path.endsWith('/epub')) {
          return http.Response.bytes(
            epubBytes,
            200,
            headers: {'content-type': 'application/epub+zip'},
          );
        }
        return http.Response('Bad Request', 400);
      });

      final service = FlibustaService(clientFactory: () => mockClient);
      final chapters = await service.fetchBookChapters(
        '999',
        availableFormats: ['application/epub+zip'],
      );

      expect(requestedUrls, contains('https://flibusta.site/b/999/read'));
      expect(requestedUrls, contains('https://flibusta.site/b/999/epub'));
      expect(chapters.length, 1);
      expect(chapters.first.title, 'Глава 1: Электронная книга');
      expect(chapters.first.content, contains('Текст первой главы из EPUB.'));
    });

    test('falls back to /fb2 when /read is 404 and availableFormats includes fb2', () async {
      final fb2Bytes = createSampleFb2ZipBytes();
      final requestedUrls = <String>[];

      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        if (request.url.path.endsWith('/read')) {
          return http.Response('Not Found', 404);
        }
        if (request.url.path.endsWith('/fb2')) {
          return http.Response.bytes(
            fb2Bytes,
            200,
            headers: {'content-type': 'application/fb2+zip'},
          );
        }
        return http.Response('Bad Request', 400);
      });

      final service = FlibustaService(clientFactory: () => mockClient);
      final chapters = await service.fetchBookChapters(
        '888',
        availableFormats: ['application/fb2+zip'],
      );

      expect(requestedUrls, contains('https://flibusta.site/b/888/read'));
      expect(requestedUrls, contains('https://flibusta.site/b/888/fb2'));
      expect(chapters.length, 1);
      expect(chapters.first.title, 'Глава 1: Формат FB2');
      expect(chapters.first.content, contains('Текст первой главы из архива FB2.zip.'));
    });

    test('follows safe same-origin redirect on /download to file archive and parses FB2', () async {
      final fb2Bytes = createSampleFb2ZipBytes();
      final requestedUrls = <String>[];

      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        if (request.url.path.endsWith('/read')) {
          return http.Response('Not Found', 404);
        }
        if (request.url.path == '/b/777/fb2') {
          return http.Response('Not Found', 404);
        }
        if (request.url.path == '/b/777/download') {
          return http.Response(
            '',
            302,
            headers: {'location': 'https://flibusta.site/b.fb2/book.777.fb2.zip'},
          );
        }
        if (request.url.path == '/b.fb2/book.777.fb2.zip') {
          return http.Response.bytes(
            fb2Bytes,
            200,
            headers: {'content-type': 'application/zip'},
          );
        }
        return http.Response('Bad Request', 400);
      });

      final service = FlibustaService(clientFactory: () => mockClient);
      final chapters = await service.fetchBookChapters(
        '777',
        availableFormats: ['application/fb2+zip'],
      );

      expect(requestedUrls, contains('https://flibusta.site/b/777/read'));
      expect(requestedUrls, contains('https://flibusta.site/b/777/fb2'));
      expect(requestedUrls, contains('https://flibusta.site/b/777/download'));
      expect(requestedUrls, contains('https://flibusta.site/b.fb2/book.777.fb2.zip'));
      expect(chapters.length, 1);
      expect(chapters.first.title, 'Глава 1: Формат FB2');
    });

    test('follows safe same-origin redirect on /epub to converter and parses EPUB', () async {
      final epubBytes = createSampleEpubBytes();
      final requestedUrls = <String>[];

      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        if (request.url.path.endsWith('/read')) {
          return http.Response('Not Found', 404);
        }
        if (request.url.path == '/b/666/epub') {
          return http.Response(
            '',
            302,
            headers: {'location': 'https://flibusta.site/converter/get/convert?out=epub&md5=abc123def'},
          );
        }
        if (request.url.path == '/converter/get/convert') {
          return http.Response.bytes(
            epubBytes,
            200,
            headers: {'content-type': 'application/epub+zip'},
          );
        }
        return http.Response('Bad Request', 400);
      });

      final service = FlibustaService(clientFactory: () => mockClient);
      final chapters = await service.fetchBookChapters(
        '666',
        availableFormats: ['application/epub+zip'],
      );

      expect(requestedUrls, contains('https://flibusta.site/b/666/read'));
      expect(requestedUrls, contains('https://flibusta.site/b/666/epub'));
      expect(requestedUrls, contains('https://flibusta.site/converter/get/convert?out=epub&md5=abc123def'));
      expect(chapters.length, 1);
      expect(chapters.first.title, 'Глава 1: Электронная книга');
    });

    test('follows safe subdomain redirect to static.flibusta.site for FB2 archive and parses FB2', () async {
      final fb2Bytes = createSampleFb2ZipBytes();
      final requestedUrls = <String>[];

      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        if (request.url.path.endsWith('/read')) {
          return http.Response('Not Found', 404);
        }
        if (request.url.path == '/b/896080/fb2') {
          return http.Response(
            '',
            302,
            headers: {'location': 'https://flibusta.site/b.fb2/book.896080.fb2.zip'},
          );
        }
        if (request.url.host == 'flibusta.site' && request.url.path == '/b.fb2/book.896080.fb2.zip') {
          return http.Response(
            '',
            302,
            headers: {'location': 'https://static.flibusta.site/b.fb2/book.896080.fb2.zip'},
          );
        }
        if (request.url.host == 'static.flibusta.site' && request.url.path == '/b.fb2/book.896080.fb2.zip') {
          return http.Response.bytes(
            fb2Bytes,
            200,
            headers: {'content-type': 'application/zip'},
          );
        }
        return http.Response('Bad Request', 400);
      });

      final service = FlibustaService(clientFactory: () => mockClient);
      final chapters = await service.fetchBookChapters(
        '896080',
        availableFormats: ['application/fb2+zip'],
      );

      expect(requestedUrls, contains('https://flibusta.site/b/896080/read'));
      expect(requestedUrls, contains('https://flibusta.site/b/896080/fb2'));
      expect(requestedUrls, contains('https://flibusta.site/b.fb2/book.896080.fb2.zip'));
      expect(requestedUrls, contains('https://static.flibusta.site/b.fb2/book.896080.fb2.zip'));
      expect(chapters.length, 1);
      expect(chapters.first.title, 'Глава 1: Формат FB2');
    });

    test('rejects unsafe cross-origin or non-HTTPS redirects', () async {
      final requestedUrls = <String>[];

      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        if (request.url.path.endsWith('/read')) {
          return http.Response(
            '',
            302,
            headers: {'location': 'https://evil-site.com/steal-data'},
          );
        }
        if (request.url.path.endsWith('/fb2') || request.url.path.endsWith('/download')) {
          return http.Response(
            '',
            302,
            headers: {'location': 'http://flibusta.site/insecure-http'},
          );
        }
        if (request.url.path.endsWith('/epub')) {
          return http.Response('Not Found', 404);
        }
        return http.Response('Bad Request', 400);
      });

      final service = FlibustaService(clientFactory: () => mockClient);
      expect(
        () => service.fetchBookChapters('555'),
        throwsA(isA<FormatException>()),
      );

      expect(requestedUrls, isNot(contains('https://evil-site.com/steal-data')));
      expect(requestedUrls, isNot(contains('http://flibusta.site/insecure-http')));
    });
  });
}
