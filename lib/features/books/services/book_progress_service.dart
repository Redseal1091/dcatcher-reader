import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookProgress {
  final String bookId;
  final String chapterId;
  final String chapterTitle;
  final String chapterNumber;
  final double scrollOffset;
  final double readPercent;
  final DateTime updatedAt;

  const BookProgress({
    required this.bookId,
    required this.chapterId,
    this.chapterTitle = '',
    this.chapterNumber = '',
    this.scrollOffset = 0.0,
    this.readPercent = 0.0,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'chapterId': chapterId,
    'chapterTitle': chapterTitle,
    'chapterNumber': chapterNumber,
    'scrollOffset': scrollOffset,
    'readPercent': readPercent,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory BookProgress.fromJson(Map<String, dynamic> json) {
    return BookProgress(
      bookId: json['bookId']?.toString() ?? '',
      chapterId: json['chapterId']?.toString() ?? '',
      chapterTitle: json['chapterTitle']?.toString() ?? '',
      chapterNumber: json['chapterNumber']?.toString() ?? '',
      scrollOffset: (json['scrollOffset'] as num?)?.toDouble() ?? 0.0,
      readPercent: (json['readPercent'] as num?)?.toDouble() ?? 0.0,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class BookProgressService {
  static const String _keyPrefix = 'book_reading_progress_';

  static Future<void> saveProgress(BookProgress progress) async {
    if (progress.bookId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_keyPrefix${progress.bookId}', jsonEncode(progress.toJson()));
    } catch (e) {
      debugPrint('Failed to save book progress: $e');
    }
  }

  static Future<BookProgress?> getProgress(String bookId) async {
    if (bookId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_keyPrefix$bookId');
      if (raw == null || raw.isEmpty) return null;
      final Map<String, dynamic> decoded = jsonDecode(raw);
      return BookProgress.fromJson(decoded);
    } catch (e) {
      debugPrint('Failed to read book progress: $e');
      return null;
    }
  }

  static Future<void> clearProgress(String bookId) async {
    if (bookId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyPrefix$bookId');
    } catch (e) {
      debugPrint('Failed to clear book progress: $e');
    }
  }
}
