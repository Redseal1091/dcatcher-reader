import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal() {
    _loadState();
  }

  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloadingChapters = {};
  final Set<String> _downloadedChapters = {};

  Set<String> get downloadedChapterIds => _downloadedChapters;
  int get downloadedCount => _downloadedChapters.length;

  bool isDownloading(String chapterId) => _downloadingChapters.contains(chapterId);
  bool isDownloaded(String chapterId) => _downloadedChapters.contains(chapterId);
  double getProgress(String chapterId) => _downloadProgress[chapterId] ?? 0.0;

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

  Future<String> _getChapterDir(String chapterId) async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/manga_offline/$chapterId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// Получение локальных путей к файлам страниц скачанной главы
  Future<List<String>?> getOfflinePages(String chapterId) async {
    if (!isDownloaded(chapterId)) return null;
    try {
      final path = await _getChapterDir(chapterId);
      final dir = Directory(path);
      if (await dir.exists()) {
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
    final docDir = await getApplicationDocumentsDirectory();
    final baseDir = Directory('${docDir.path}/manga_offline');

    if (!await baseDir.exists()) return [];

    for (final chapterId in _downloadedChapters) {
      try {
        final dir = Directory('${baseDir.path}/$chapterId');
        if (!await dir.exists()) continue;

        final metaFile = File('${dir.path}/meta.json');
        String mangaTitle = 'Глава $chapterId';
        String chapterNum = '1';
        String mangaId = '';
        String coverUrl = '';
        DateTime downloadedAt = DateTime.now();
        int pagesCount = 0;
        int sizeBytes = 0;

        if (await metaFile.exists()) {
          final data = jsonDecode(await metaFile.readAsString());
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
    notifyListeners();

    try {
      final pages = await SourceManager.currentSource.getChapterPages(chapterId);
      if (pages.isEmpty) {
        _downloadingChapters.remove(chapterId);
        _downloadProgress.remove(chapterId);
        notifyListeners();
        return false;
      }

      final chapterPath = await _getChapterDir(chapterId);
      final total = pages.length;

      for (int i = 0; i < total; i++) {
        final url = pages[i];
        final ext = url.contains('.png') ? 'png' : 'webp';
        final fileName = 'page_${i.toString().padLeft(3, '0')}.$ext';
        final file = File('$chapterPath/$fileName');

        if (!await file.exists()) {
          final res = await http.get(Uri.parse(url), headers: {
            'User-Agent': 'Mozilla/5.0',
            'Referer': 'https://remanga.org/',
          }).timeout(const Duration(seconds: 15));

          if (res.statusCode == 200) {
            await file.writeAsBytes(res.bodyBytes);
          }
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
      await _saveState();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Download error for chapter $chapterId: $e');
      _downloadingChapters.remove(chapterId);
      _downloadProgress.remove(chapterId);
      notifyListeners();
      return false;
    }
  }

  /// Удаление скачанной главы для освобождения памяти
  Future<void> deleteDownloadedChapter(String chapterId) async {
    try {
      final path = await _getChapterDir(chapterId);
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _downloadedChapters.remove(chapterId);
      await _saveState();
      notifyListeners();
    } catch (e) {
      debugPrint('Delete chapter error: $e');
    }
  }
}
