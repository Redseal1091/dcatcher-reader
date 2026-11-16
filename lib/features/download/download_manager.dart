import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/dcatcher_image.dart';
import '../sources/extension_manga_source.dart';
import '../sources/manga_source.dart';
import '../sources/source_manager.dart';

class DownloadedItem {
  final String chapterId;
  final String mangaId;
  final String mangaTitle;
  final String chapterNumber;
  final String coverUrl;
  final DateTime downloadedAt;
  final int pagesCount;
  final int totalSizeBytes;

  const DownloadedItem({
    required this.chapterId,
    required this.mangaId,
    required this.mangaTitle,
    required this.chapterNumber,
    this.coverUrl = '',
    required this.downloadedAt,
    required this.pagesCount,
    this.totalSizeBytes = 0,
  });

  String get sizeFormatted {
    if (totalSizeBytes <= 0) return '$pagesCount стр.';
    final mb = totalSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} МБ • $pagesCount стр.';
  }
}

class ActiveDownload {
  final String chapterId;
  final String mangaId;
  final String mangaTitle;
  final String chapterNumber;
  final String coverUrl;

  const ActiveDownload({
    required this.chapterId,
    required this.mangaId,
    required this.mangaTitle,
    required this.chapterNumber,
    this.coverUrl = '',
  });
}

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal() {
    _loadState();
  }

  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloadingChapters = {};
  final Set<String> _downloadedChapters = {};
  final Map<String, Object> _downloadErrors = {};
  final Map<String, ActiveDownload> _activeDownloadsMeta = {};

  Set<String> get downloadedChapterIds => _downloadedChapters;
  int get downloadedCount => _downloadedChapters.length;
  List<ActiveDownload> get activeDownloads => _activeDownloadsMeta.values.toList();
  int get activeDownloadsCount => _downloadingChapters.length;

  bool isDownloading(String chapterId) => _downloadingChapters.contains(chapterId);
  bool isDownloaded(String chapterId) => _downloadedChapters.contains(chapterId);
  double getProgress(String chapterId) => _downloadProgress[chapterId] ?? 0.0;
  Object? getDownloadError(String chapterId) => _downloadErrors[chapterId];

  @visibleForTesting
  static Directory? baseDirectoryForTesting;

  @visibleForTesting
  static void resetForTesting() {
    _instance._downloadProgress.clear();
    _instance._downloadingChapters.clear();
    _instance._downloadedChapters.clear();
    _instance._downloadErrors.clear();
    _instance._activeDownloadsMeta.clear();
  }

  @visibleForTesting
  void setActiveDownloadForTesting(String chapterId, ActiveDownload item, double progress) {
    _activeDownloadsMeta[chapterId] = item;
    _downloadingChapters.add(chapterId);
    _downloadProgress[chapterId] = progress;
    notifyListeners();
  }

  @visibleForTesting
  void addDownloadedChapterForTesting(String chapterId) {
    _downloadedChapters.add(chapterId);
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('downloaded_chapters') ?? [];
      _downloadedChapters.clear();
      _downloadedChapters.addAll(list);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('downloaded_chapters', _downloadedChapters.toList());
    } catch (_) {}
  }

  static String _safeFolder(String chapterId) => chapterId.replaceAll(':', '_');

  Future<String> _getChapterDir(String chapterId) async {
    final String basePath;
    if (baseDirectoryForTesting != null) {
      basePath = baseDirectoryForTesting!.path;
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      basePath = docDir.path;
    }
    final folder = _safeFolder(chapterId);
    final dir = Directory('$basePath/manga_offline/$folder');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }

  /// Получение локальных путей к файлам страниц скачанной главы
  Future<List<String>?> getOfflinePages(String chapterId) async {
    if (!isDownloaded(chapterId)) return null;
    try {
      final path = await _getChapterDir(chapterId);
      final dir = Directory(path);
      if (dir.existsSync()) {
        final files = dir.listSync().whereType<File>().where((f) => !f.path.endsWith('.json')).toList();
        files.sort((a, b) => a.path.compareTo(b.path));
        return files.map((f) => f.path).toList();
      }
    } catch (e) {
      debugPrint('Error getting offline pages: $e');
    }
    return null;
  }

  /// Получение всех скачанных глав с метаданными
  Future<List<DownloadedItem>> getDownloadedItems() async {
    final List<DownloadedItem> items = [];
    final String basePath;
    if (baseDirectoryForTesting != null) {
      basePath = baseDirectoryForTesting!.path;
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      basePath = docDir.path;
    }
    final baseDir = Directory('$basePath/manga_offline');

    if (!baseDir.existsSync()) return [];

    for (final chapterId in _downloadedChapters) {
      try {
        final path = await _getChapterDir(chapterId);
        final dir = Directory(path);
        if (!dir.existsSync()) continue;

        final metaFile = File('${dir.path}/meta.json');
        String mangaTitle = 'Глава $chapterId';
        String chapterNum = '1';
        String mangaId = '';
        String coverUrl = '';
        DateTime downloadedAt = DateTime.now();
        int pagesCount = 0;
        int sizeBytes = 0;

        if (metaFile.existsSync()) {
          final data = jsonDecode(metaFile.readAsStringSync());
          mangaTitle = data['mangaTitle'] ?? mangaTitle;
          chapterNum = data['chapterNumber']?.toString() ?? '1';
          mangaId = data['mangaId'] ?? '';
          coverUrl = data['coverUrl'] ?? '';
          downloadedAt = DateTime.tryParse(data['downloadedAt'] ?? '') ?? DateTime.now();
          pagesCount = data['pagesCount'] ?? 0;
        }

        final files = dir.listSync().whereType<File>().toList();
        for (final f in files) {
          sizeBytes += f.lengthSync();
        }
        if (pagesCount == 0) {
          pagesCount = files.where((f) => !f.path.endsWith('.json')).length;
        }

        items.add(DownloadedItem(
          chapterId: chapterId,
          mangaId: mangaId,
          mangaTitle: mangaTitle,
          chapterNumber: chapterNum,
          coverUrl: coverUrl,
          downloadedAt: downloadedAt,
          pagesCount: pagesCount,
          totalSizeBytes: sizeBytes,
        ));
      } catch (e) {
        debugPrint('Error reading meta for $chapterId: $e');
      }
    }

    items.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return items;
  }

  /// Скачивание всех страниц главы в память телефона
  Future<bool> downloadChapter({
    required String chapterId,
    required String mangaTitle,
    required String chapterNumber,
    String mangaId = '',
    String coverUrl = '',
  }) async {
    if (isDownloaded(chapterId) || isDownloading(chapterId)) return true;

    _downloadingChapters.add(chapterId);
    _downloadProgress[chapterId] = 0.0;
    _downloadErrors.remove(chapterId);
    _activeDownloadsMeta[chapterId] = ActiveDownload(
      chapterId: chapterId,
      mangaId: mangaId,
      mangaTitle: mangaTitle,
      chapterNumber: chapterNumber,
      coverUrl: coverUrl,
    );
    notifyListeners();

    try {
      MangaSource? source;
      if (chapterId.contains('::')) {
        final sourceId = chapterId.split('::').first;
        source = SourceManager.getSourceById(sourceId);
        if (source == null) {
          throw MissingExtensionSourceException(
            sourceId,
            'Установленное расширение источника недоступно для скачивания (ID: $sourceId)',
          );
        }
      } else {
        source = SourceManager.currentSource;
        if (source == null) {
          throw StateError('Источник не найден для скачивания главы: $chapterId');
        }
      }

      final pages = await source.getChapterPages(chapterId);
      if (pages.isEmpty) {
        throw StateError('Список страниц главы пуст для главы: $chapterId');
      }

      final chapterPath = await _getChapterDir(chapterId);
      final total = pages.length;

      for (int i = 0; i < total; i++) {
        final url = pages[i];
        final ext = url.contains('.png') ? 'png' : 'webp';
        final fileName = 'page_${i.toString().padLeft(3, '0')}.$ext';
        final file = File('$chapterPath/$fileName');

        // Validate existing files: must exist AND have non-zero length
        final bool fileValid = await file.exists() && await file.length() > 0;
        if (!fileValid) {
          Uint8List? pageBytes;

          if (source is ExtensionMangaSource) {
            // Strictly route bytes via resolved MangaSource.fetchImage (Keiyoushi cookies/interceptors)
            // No silent fallback to unintercepted HTTP!
            pageBytes = await source.fetchImage(url);
            if (pageBytes == null || pageBytes.isEmpty) {
              throw StateError(
                'Не удалось получить изображение страницы $i для расширения ${source.id}: пустые байты',
              );
            }
          } else {
            // Preserving non-extension / books / legacy sources
            pageBytes = await source.fetchImage(url);
            if (pageBytes == null || pageBytes.isEmpty) {
              final headers = await source.getHeaders();
              final res = await http.get(
                Uri.parse(url),
                headers: headers.isNotEmpty
                    ? headers
                    : const {
                        'User-Agent': 'Mozilla/5.0',
                        'Accept': '*/*',
                      },
              ).timeout(const Duration(seconds: 15));

              if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
                pageBytes = res.bodyBytes;
              } else {
                throw StateError(
                  'HTTP ошибка ${res.statusCode} при скачивании страницы $i ($url)',
                );
              }
            }
          }

          await file.writeAsBytes(pageBytes);
        }

        _downloadProgress[chapterId] = (i + 1) / total;
        notifyListeners();
      }

      // Сохраняем информацию о скачивании
      final metaFile = File('$chapterPath/meta.json');
      await metaFile.writeAsString(jsonEncode({
        'mangaId': mangaId,
        'mangaTitle': mangaTitle,
        'chapterNumber': chapterNumber,
        'coverUrl': coverUrl,
        'downloadedAt': DateTime.now().toIso8601String(),
        'pagesCount': total,
      }));

      _downloadedChapters.add(chapterId);
      _downloadingChapters.remove(chapterId);
      _downloadProgress.remove(chapterId);
      _activeDownloadsMeta.remove(chapterId);
      await _saveState();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Download error for chapter $chapterId: $e');
      _downloadErrors[chapterId] = e;
      _downloadingChapters.remove(chapterId);
      _downloadProgress.remove(chapterId);
      _activeDownloadsMeta.remove(chapterId);
      notifyListeners();
      return false;
    }
  }

  /// Удаление скачанной главы для освобождения памяти
  Future<void> deleteDownloadedChapter(String chapterId) async {
    try {
      final path = await _getChapterDir(chapterId);
      final dir = Directory(path);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
      _downloadedChapters.remove(chapterId);
      await _saveState();
      notifyListeners();
    } catch (e) {
      debugPrint('Delete chapter error: $e');
    }
  }

  /// Пакетное удаление нескольких скачанных глав
  Future<void> batchDelete(Iterable<String> chapterIds) async {
    final toDelete = chapterIds.toList();
    if (toDelete.isEmpty) return;

    for (final chapterId in toDelete) {
      try {
        final path = await _getChapterDir(chapterId);
        final dir = Directory(path);
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
        _downloadedChapters.remove(chapterId);
      } catch (e) {
        debugPrint('Batch delete error for $chapterId: $e');
      }
    }
    await _saveState();
    notifyListeners();
  }

  /// Удаление всех скачанных глав
  Future<void> deleteAll() async {
    await batchDelete(_downloadedChapters.toList());
  }
}
