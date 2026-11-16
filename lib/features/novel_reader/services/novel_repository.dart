import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/novel_chapter.dart';
import 'ranobe_source.dart';
import 'curated_ranobe_source.dart';
import 'ranobehub_source.dart';
import 'rulate_source.dart';

class NovelBook {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String description;
  final List<NovelChapter> chapters;
  final bool isCustom;
  final String source;
  final String? url;
  final int? totalChapters;
  final double? rating;

  const NovelBook({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.description,
    required this.chapters,
    this.isCustom = false,
    this.source = 'DCatcher Novels',
    this.url,
    this.totalChapters,
    this.rating,
  });

  NovelBook copyWith({
    String? id,
    String? title,
    String? author,
    String? coverUrl,
    String? description,
    List<NovelChapter>? chapters,
    bool? isCustom,
    String? source,
    String? url,
    int? totalChapters,
    double? rating,
  }) {
    return NovelBook(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      chapters: chapters ?? this.chapters,
      isCustom: isCustom ?? this.isCustom,
      source: source ?? this.source,
      url: url ?? this.url,
      totalChapters: totalChapters ?? this.totalChapters,
      rating: rating ?? this.rating,
    );
  }
}

class NovelRepository {
  static final NovelRepository _instance = NovelRepository._internal();
  factory NovelRepository() => _instance;
  NovelRepository._internal();

  static const List<String> availableSources = [
    'DCatcher Novels',
    'RanobeHub',
    'RuLate',
  ];

  final CuratedRanobeSource _curatedSource = CuratedRanobeSource();
  final RanobehubSource _ranobehubSource = RanobehubSource();
  final RulateSource _rulateSource = RulateSource();

  RanobeSource getSource(String? sourceName) {
    switch (sourceName) {
      case 'RanobeHub':
        return _ranobehubSource;
      case 'RuLate':
        return _rulateSource;
      case 'DCatcher Novels':
      default:
        return _curatedSource;
    }
  }

  Future<List<NovelBook>> getAllNovels({String? source, int page = 1}) async {
    final activeSource = getSource(source);
    return activeSource.getPopularNovels(page: page);
  }

  Future<List<NovelBook>> searchNovels(String query, {String? source, int page = 1}) async {
    final activeSource = getSource(source);
    return activeSource.searchNovels(query, page: page);
  }

  Future<List<NovelChapter>> getNovelChapters(NovelBook book) async {
    if (book.chapters.isNotEmpty && book.chapters.first.content.isNotEmpty) {
      return book.chapters;
    }
    final activeSource = getSource(book.source);
    return activeSource.getChapters(book.id, novelUrl: book.url);
  }

  Future<String> getChapterContent(NovelChapter chapter, {String? source}) async {
    if (chapter.content.isNotEmpty) {
      return chapter.content;
    }
    final activeSource = getSource(source);
    return activeSource.getChapterContent(chapter);
  }

  Future<NovelBook?> getNovelById(String id, {String? source}) async {
    final all = await getAllNovels(source: source);
    try {
      return all.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Поиск первоисточника-ранобэ для манги/манхвы
  Future<NovelBook?> findNovelForManga(String mangaId, String mangaTitle, {String? source}) async {
    final titleLower = mangaTitle.toLowerCase();
    
    // 1. Сначала проверяем локальные кураторские новеллы
    final curated = await _curatedSource.getPopularNovels();
    for (final book in curated) {
      final bTitle = book.title.toLowerCase();
      if (titleLower.contains(bTitle) || bTitle.contains(titleLower)) {
        return book;
      }
      if (titleLower.contains('одиночк') && bTitle.contains('одиночк')) return book;
      if (titleLower.contains('читател') && bTitle.contains('читател')) return book;
      if (titleLower.contains('гонч') && bTitle.contains('гонч')) return book;
      if (titleLower.contains('хуашань') && bTitle.contains('хуашань')) return book;
      if (titleLower.contains('теневой') && bTitle.contains('теневой')) return book;
    }

    // 2. Если не найдено в кураторских, ищем в активном источнике (или RanobeHub)
    try {
      final searchSource = (source != null && source != CuratedRanobeSource.sourceId)
          ? source
          : RanobehubSource.sourceId;
      final onlineMatches = await searchNovels(mangaTitle, source: searchSource);
      if (onlineMatches.isNotEmpty) {
        return onlineMatches.first;
      }
    } catch (_) {}

    return null;
  }

  Future<void> addCustomNovel({
    required String title,
    required String author,
    required String chapterTitle,
    required String content,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('custom_library_novels') ?? [];

    final newNovel = {
      'id': 'novel_${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'author': author.isNotEmpty ? author : 'Пользовательская новелла',
      'coverUrl': 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=400&q=80',
      'description': 'Пользовательское ранобэ',
      'chapters': [
        {
          'id': 'ch_${DateTime.now().millisecondsSinceEpoch}',
          'title': chapterTitle.isNotEmpty ? chapterTitle : 'Глава 1',
          'number': '1',
          'content': content,
        }
      ],
    };

    list.add(jsonEncode(newNovel));
    await prefs.setStringList('custom_library_novels', list);
  }
}
