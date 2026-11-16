import '../models/novel_chapter.dart';
import 'novel_repository.dart';

abstract class RanobeSource {
  String get id;
  String get name;

  Future<List<NovelBook>> getPopularNovels({int page = 1});
  Future<List<NovelBook>> searchNovels(String query, {int page = 1});
  Future<List<NovelChapter>> getChapters(String novelId, {String? novelUrl});
  Future<String> getChapterContent(NovelChapter chapter);
}
