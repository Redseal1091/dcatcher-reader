import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/novel_chapter.dart';

class RanobeCacheService {
  static const String _chapterPrefix = 'ranobe_content_v1_';
  static const String _chaptersListPrefix = 'ranobe_chapters_v1_';

  static Future<String?> getCachedChapterContent(String chapterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_chapterPrefix$chapterId';
      return prefs.getString(key);
    } catch (e) {
      debugPrint('RanobeCacheService: error reading content for $chapterId: $e');
      return null;
    }
  }

  static Future<void> saveChapterContent(String chapterId, String content) async {
    if (content.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_chapterPrefix$chapterId';
      await prefs.setString(key, content);
    } catch (e) {
      debugPrint('RanobeCacheService: error saving content for $chapterId: $e');
    }
  }

  static Future<List<NovelChapter>?> getCachedChapters(String novelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_chaptersListPrefix$novelId';
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final List<dynamic> list = jsonDecode(raw);
      return list.map((item) => NovelChapter.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('RanobeCacheService: error reading chapters for $novelId: $e');
      return null;
    }
  }

  static Future<void> saveChapters(String novelId, List<NovelChapter> chapters) async {
    if (chapters.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_chaptersListPrefix$novelId';
      final raw = jsonEncode(chapters.map((c) => c.toJson()).toList());
      await prefs.setString(key, raw);
    } catch (e) {
      debugPrint('RanobeCacheService: error saving chapters for $novelId: $e');
    }
  }
}
