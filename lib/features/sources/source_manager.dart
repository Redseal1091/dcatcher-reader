import 'manga_source.dart';
import 'remanga/remanga_api.dart';
import 'mangadex/mangadex_api.dart';
import 'asura/asura_scans_api.dart';
import 'mangalib/mangalib_api.dart';
import 'mangabuff/mangabuff_api.dart';

class SourceManager {
  static final RemangaSource remanga = RemangaSource();
  static final MangaDexSource mangadex = MangaDexSource();
  static final AsuraScansSource asura = AsuraScansSource();
  static final MangaLibSource mangalib = MangaLibSource();
  static final MangaBuffSource mangabuff = MangaBuffSource();

  static final List<MangaSource> sources = [
    remanga,
    asura,
    mangalib,
    mangabuff,
    mangadex,
  ];

  static MangaSource currentSource = remanga;

  static MangaSource getSourceById(String id) {
    return sources.firstWhere(
      (s) => s.id == id || s.name.toLowerCase() == id.toLowerCase(),
      orElse: () => currentSource,
    );
  }

  static void setCurrentSource(String id) {
    currentSource = getSourceById(id);
  }
}
