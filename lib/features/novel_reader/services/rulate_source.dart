import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../models/novel_chapter.dart';
import 'novel_repository.dart';
import 'ranobe_source.dart';
import 'ranobe_cache_service.dart';

class RulateSource implements RanobeSource {
  static const String sourceId = 'RuLate';
  static const String sourceName = 'RuLate';
  static const String _baseUrl = 'https://tl.rulate.ru';

  final http.Client _client;

  RulateSource({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get id => sourceId;

  @override
  String get name => sourceName;

  Map<String, String> get _headers => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  @override
  Future<List<NovelBook>> getPopularNovels({int page = 1}) async {
    final uri = Uri.parse('$_baseUrl/search?sort=2&p=$page');
    try {
      final response = await _client.get(uri, headers: _headers);
      if (response.statusCode != 200) return [];
      return _parseCards(response.body);
    } catch (e) {
      debugPrint('RulateSource: error getting popular novels: $e');
      return [];
    }
  }

  @override
  Future<List<NovelBook>> searchNovels(String query, {int page = 1}) async {
    final q = Uri.encodeQueryComponent(query.trim());
    final uri = Uri.parse('$_baseUrl/search?t=$q&p=$page');
    try {
      final response = await _client.get(uri, headers: _headers);
      if (response.statusCode != 200) return [];
      return _parseCards(response.body);
    } catch (e) {
      debugPrint('RulateSource: error searching novels: $e');
      return [];
    }
  }

  List<NovelBook> _parseCards(String html) {
    final document = html_parser.parse(html);
    final List<NovelBook> novels = [];

    // RuLate search results are typically in .search-results li or table or .book_info
    final items = document.querySelectorAll('.search-results li, .search-row, .table tr');
    for (final item in items) {
      final link = item.querySelector('a[href^="/book/"]');
      if (link == null) continue;

      final href = link.attributes['href'] ?? '';
      final idMatch = RegExp(r'/book/(\d+)').firstMatch(href);
      if (idMatch == null) continue;
      final bookId = idMatch.group(1)!;

      final title = link.text.trim();
      if (title.isEmpty) continue;

      final img = item.querySelector('img');
      var coverUrl = img?.attributes['src'] ?? '';
      if (coverUrl.startsWith('/')) {
        coverUrl = '$_baseUrl$coverUrl';
      }

      final descEl = item.querySelector('.text, .description, p');
      final desc = descEl?.text.trim() ?? '';

      final authorEl = item.querySelector('.author, .user');
      final author = authorEl?.text.trim() ?? 'RuLate';

      novels.add(
        NovelBook(
          id: 'rulate_$bookId',
          title: title,
          author: author,
          coverUrl: coverUrl,
          description: desc,
          chapters: const [],
          source: sourceName,
          url: '$_baseUrl/book/$bookId',
        ),
      );
    }

    return novels;
  }

  @override
  Future<List<NovelChapter>> getChapters(String novelId, {String? novelUrl}) async {
    final cached = await RanobeCacheService.getCachedChapters(novelId);
    if (cached != null && cached.isNotEmpty) return cached;

    final cleanId = novelId.replaceFirst('rulate_', '');
    final uri = Uri.parse(novelUrl ?? '$_baseUrl/book/$cleanId');

    try {
      final response = await _client.get(uri, headers: _headers);
      if (response.statusCode != 200) return [];

      final doc = html_parser.parse(response.body);
      final chapterRows = doc.querySelectorAll('tr.chapter_row, a[href*="/ready"]');
      final List<NovelChapter> chapters = [];
      final seenUrls = <String>{};

      for (final row in chapterRows) {
        final a = row.localName == 'a'
            ? row
            : row.querySelector('a[href*="/ready"]');
        if (a == null) continue;

        final href = a.attributes['href'] ?? '';
        if (href.isEmpty || !seenUrls.add(href)) continue;

        final title = a.text.trim();
        final chIdMatch = RegExp(r'/book/\d+/(\d+)/ready').firstMatch(href);
        final chId = chIdMatch != null ? chIdMatch.group(1)! : href;

        chapters.add(
          NovelChapter(
            id: 'rulate_$chId',
            title: title.isNotEmpty ? title : 'Глава',
            chapterNumber: chId,
            content: '',
            publishedAt: DateTime.now(),
            url: href.startsWith('http') ? href : '$_baseUrl$href',
          ),
        );
      }

      if (chapters.isNotEmpty) {
        await RanobeCacheService.saveChapters(novelId, chapters);
      }
      return chapters;
    } catch (e) {
      debugPrint('RulateSource: error getting chapters: $e');
      return [];
    }
  }

  @override
  Future<String> getChapterContent(NovelChapter chapter) async {
    final cached = await RanobeCacheService.getCachedChapterContent(chapter.id);
    if (cached != null && cached.isNotEmpty) return cached;

    final targetUrl = chapter.url ?? '';
    if (targetUrl.isEmpty) {
      return 'Неверный адрес главы.';
    }

    try {
      final response = await _client.get(Uri.parse(targetUrl), headers: _headers);
      if (response.statusCode != 200) {
        return 'Ошибка загрузки главы (код ${response.statusCode}).';
      }

      final doc = html_parser.parse(response.body);
      final contentEl = doc.querySelector('.content-text, .chapter-content, #content');
      if (contentEl != null) {
        final paragraphs = contentEl.querySelectorAll('p');
        String text = '';
        if (paragraphs.isNotEmpty) {
          text = paragraphs.map((p) => p.text.trim()).where((t) => t.isNotEmpty).join('\n\n');
        } else {
          text = contentEl.text.trim();
        }
        if (text.isNotEmpty) {
          await RanobeCacheService.saveChapterContent(chapter.id, text);
          return text;
        }
      }

      return 'Текст главы не найден.';
    } catch (e) {
      debugPrint('RulateSource: error getting chapter content: $e');
      return 'Не удалось загрузить главу: $e';
    }
  }
}
