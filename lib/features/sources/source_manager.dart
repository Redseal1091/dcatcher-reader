import 'manga_source.dart';
import 'remanga/remanga_api.dart';
import 'mangadex/mangadex_api.dart';

class SourceManager {
  static final RemangaSource remanga = RemangaSource();
  static final MangaDexSource mangadex = MangaDexSource();

  // По умолчанию используем Remanga (крупнейший русскоязычный источник с открытым API)
  static MangaSource currentSource = remanga;
}
