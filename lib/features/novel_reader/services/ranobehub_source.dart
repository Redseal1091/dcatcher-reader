import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../models/novel_chapter.dart';
import 'novel_repository.dart';
import 'ranobe_source.dart';
import 'ranobe_cache_service.dart';

class RanobehubSource implements RanobeSource {
  static const String sourceId = 'RanobeHub';
  static const String sourceName = 'RanobeHub';
  static const String _baseUrl = 'https://ranobehub.org';

  final http.Client _client;

  RanobehubSource({http.Client? client}) : _client = client ?? http.Client();

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
    final uri = Uri.parse('$_baseUrl/ranobe?page=$page');
    try {
      final response = await _client.get(uri, headers: _headers);
      if (response.statusCode != 200) {
        debugPrint('RanobehubSource: getPopularNovels failed with status ${response.statusCode}');
        return [];
      }
      return _parseNovelCards(response.body);
    } catch (e) {
      debugPrint('RanobehubSource: error getting popular novels: $e');
      return [];
    }
  }

  @override
  Future<List<NovelBook>> searchNovels(String query, {int page = 1}) async {
    final q = Uri.encodeQueryComponent(query.trim());
    final uri = Uri.parse('$_baseUrl/ranobe?q=$q&page=$page');
    try {
      final response = await _client.get(uri, headers: _headers);
      if (response.statusCode != 200) {
        debugPrint('RanobehubSource: searchNovels failed with status ${response.statusCode}');
        return [];
      }
      return _parseNovelCards(response.body);
    } catch (e) {
      debugPrint('RanobehubSource: error searching novels: $e');
      return [];
    }
  }

  List<NovelBook> _parseNovelCards(String html) {
    final document = html_parser.parse(html);
    final cards = document.querySelectorAll('.book-card, [data-slot="card"]');
    final List<NovelBook> novels = [];

    for (final card in cards) {
      final link = card.querySelector('a[href^="/ranobe/"]');
      if (link == null) continue;

      final href = link.attributes['href'] ?? '';
      final slug = href.replaceFirst('/ranobe/', '').split('?').first;
      if (slug.isEmpty || slug == 'random' || slug == 'genres' || !slug.contains('-')) {
        continue;
      }

      final img = card.querySelector('img.book-cover-image, img');
      var coverUrl = img?.attributes['src'] ?? '';
      if (coverUrl.contains('/api/media/')) {
        final decoded = Uri.decodeFull(coverUrl);
        final m = RegExp(r'/api/media/(\d+)').firstMatch(decoded);
        if (m != null) {
          coverUrl = '$_baseUrl/api/media/${m.group(1)}?size=medium';
        } else if (coverUrl.startsWith('/')) {
          coverUrl = '$_baseUrl$coverUrl';
        }
      } else if (coverUrl.startsWith('/')) {
        coverUrl = '$_baseUrl$coverUrl';
      }

      final titleEl = card.querySelector('h3, .book-cover-copy strong');
      final title = titleEl?.text.trim() ?? '';
      if (title.isEmpty) continue;

      final descEl = card.querySelector('.book-hover-preview p');
      final desc = descEl?.text.trim() ?? '';

      final ratingEl = card.querySelector('.rating');
      final ratingStr = ratingEl?.text.trim() ?? '';
      final rating = double.tryParse(ratingStr.replaceAll(',', '.'));

      final metaText = card.text;
      final chMatch = RegExp(r'(\d+)\s*(?:<!-- -->)?\s*глав').firstMatch(metaText);
      final chCount = chMatch != null ? int.tryParse(chMatch.group(1)!) : null;

      // Extract author if present
      final authorEl = card.querySelector('.book-author, .author');
      final author = authorEl?.text.trim() ?? 'RanobeHub';

      novels.add(
        NovelBook(
          id: slug,
          title: title,
          author: author,
          coverUrl: coverUrl,
          description: desc,
          chapters: const [],
          source: sourceName,
          url: '$_baseUrl/ranobe/$slug',
          totalChapters: chCount,
          rating: rating,
        ),
      );
    }

    return novels;
  }

  @override
  Future<List<NovelChapter>> getChapters(String novelId, {String? novelUrl}) async {
    // 1. Check local cache first
    final cached = await RanobeCacheService.getCachedChapters(novelId);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // 2. Fetch novel details page
    final cleanSlug = novelId.replaceFirst('$_baseUrl/ranobe/', '').replaceAll('/ranobe/', '');
    final uri = Uri.parse(novelUrl ?? '$_baseUrl/ranobe/$cleanSlug');

    try {
      final response = await _client.get(uri, headers: _headers);
      if (response.statusCode != 200) {
        debugPrint('RanobehubSource: getChapters failed with status ${response.statusCode}');
        return [];
      }

      final html = response.body;
      final List<NovelChapter> chapters = [];

      // A. Try Next.js embedded JSON regex
      final chRegex = RegExp(
        r'\\"id\\":(\d+),\\"bookId\\":(\d+),\\"volume\\":(\d+),\\"number\\":([0-9\.]+),\\"title\\":\\"([^"\\]*)\\"',
      );
      final matches = chRegex.allMatches(html).toList();

      if (matches.isNotEmpty) {
        for (final m in matches) {
          final id = m.group(1)!;
          final vol = m.group(3)!;
          final num = m.group(4)!;
          final rawTitle = m.group(5) ?? '';
          final title = rawTitle.isNotEmpty ? rawTitle : 'Глава $num';

          chapters.add(
            NovelChapter(
              id: id,
              title: title,
              chapterNumber: num,
              content: '',
              publishedAt: DateTime.now(),
              url: '/ranobe/$cleanSlug/chapter/$id',
              volume: 'Том $vol',
            ),
          );
        }
      }

      // B. Fallback: Parse HTML links in DOM if regex yielded 0
      if (chapters.isEmpty) {
        final doc = html_parser.parse(html);
        final links = doc.querySelectorAll('a[href*="/chapter/"]');
        final seenIds = <String>{};

        for (final a in links) {
          final href = a.attributes['href'] ?? '';
          final m = RegExp(r'/chapter/(\d+)').firstMatch(href);
          if (m != null) {
            final id = m.group(1)!;
            if (seenIds.add(id)) {
              final rawTitle = a.text.replaceAll(RegExp(r'\s+'), ' ').trim();
              final title = rawTitle.isNotEmpty && rawTitle != 'Читать' ? rawTitle : 'Глава';
              chapters.add(
                NovelChapter(
                  id: id,
                  title: title,
                  chapterNumber: id,
                  content: '',
                  publishedAt: DateTime.now(),
                  url: href,
                ),
              );
            }
          }
        }
      }

      // Cache chapters list
      if (chapters.isNotEmpty) {
        await RanobeCacheService.saveChapters(novelId, chapters);
      }

      return chapters;
    } catch (e) {
      debugPrint('RanobehubSource: error fetching chapters: $e');
      return [];
    }
  }

  @override
  Future<String> getChapterContent(NovelChapter chapter) async {
    // 1. Check local cache
    final cached = await RanobeCacheService.getCachedChapterContent(chapter.id);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // 2. Resolve URL
    String targetUrl = chapter.url ?? '';
    if (targetUrl.isEmpty) {
      targetUrl = '$_baseUrl/ranobe/c/${chapter.id}';
    } else if (!targetUrl.startsWith('http')) {
      targetUrl = '$_baseUrl$targetUrl';
    }

    try {
      final response = await _client.get(Uri.parse(targetUrl), headers: _headers);
      if (response.statusCode != 200) {
        debugPrint('RanobehubSource: getChapterContent failed with status ${response.statusCode}');
        return 'Ошибка загрузки главы (код ${response.statusCode}). Пожалуйста, попробуйте позже.';
      }

      final doc = html_parser.parse(response.body);
      final readerContent = doc.querySelector('.reader-content');

      String fullText = '';
      if (readerContent != null) {
        final paragraphs = readerContent.querySelectorAll('p');
        if (paragraphs.isNotEmpty) {
          fullText = paragraphs
              .map((p) => _cleanHtmlText(p.text))
              .where((t) => t.isNotEmpty)
              .join('\n\n');
        } else {
          fullText = _cleanHtmlText(readerContent.text);
        }
      }

      // Fallback: look for reader text between markers
      if (fullText.isEmpty) {
        final html = response.body;
        final startIdx = html.indexOf('class="reader-content"');
        if (startIdx != -1) {
          int endIdx = html.indexOf('class="reader-navigation"', startIdx);
          if (endIdx == -1) endIdx = html.indexOf('id="comments"', startIdx);
          if (endIdx == -1) endIdx = startIdx + 30000;
          final section = html.substring(startIdx, endIdx);
          final pMatches = RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true).allMatches(section);
          fullText = pMatches
              .map((m) => _cleanHtmlText(m.group(1) ?? ''))
              .where((t) => t.isNotEmpty)
              .join('\n\n');
        }
      }

      if (fullText.isEmpty) {
        fullText = 'Текст главы не найден или состоит из иллюстраций.';
      }

      // Save to cache
      await RanobeCacheService.saveChapterContent(chapter.id, fullText);
      return fullText;
    } catch (e) {
      debugPrint('RanobehubSource: error fetching chapter content: $e');
      return 'Не удалось загрузить главу: $e';
    }
  }

  String _cleanHtmlText(String text) {
    var s = text.replaceAll(RegExp(r'<[^>]+>'), '');
    s = s.replaceAll('&nbsp;', ' ');
    s = s.replaceAll('&mdash;', '—');
    s = s.replaceAll('&ndash;', '–');
    s = s.replaceAll('&laquo;', '«');
    s = s.replaceAll('&raquo;', '»');
    s = s.replaceAll('&quot;', '"');
    s = s.replaceAll('&#39;', "'");
    s = s.replaceAll('&hellip;', '...');
    s = s.replaceAll('&amp;', '&');
    return s.trim();
  }
}
