import '../models/chapter.dart';

class ChapterSelection {
  static final RegExp _firstNumberRegex = RegExp(r'(\d+(?:\.\d+)?)');

  /// Extracts the primary numeric value of a chapter number string for sorting.
  /// E.g. "187" -> 187.0, "1.5" -> 1.5, "5-extra" -> 5.0.
  /// If non-numeric, returns null.
  static double? extractNumeric(String chapterNumber) {
    final match = _firstNumberRegex.firstMatch(chapterNumber);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Orders chapters chronologically ascending (e.g. 1, 1.5, 2, 10, 187).
  /// Preserves lossless chapter IDs and compound numbers.
  /// If chapter numbers cannot be parsed numerically, falls back to stable comparison
  /// preserving publishedAt, string comparison, or original list stability.
  static List<Chapter> orderedChapters(List<Chapter> chapters) {
    if (chapters.length <= 1) return List<Chapter>.from(chapters);

    final listWithIndex = chapters.asMap().entries.toList();

    listWithIndex.sort((aEntry, bEntry) {
      final a = aEntry.value;
      final b = bEntry.value;

      final aNum = extractNumeric(a.chapterNumber);
      final bNum = extractNumeric(b.chapterNumber);

      if (aNum != null && bNum != null) {
        final cmp = aNum.compareTo(bNum);
        if (cmp != 0) return cmp;
      } else if (aNum != null && bNum == null) {
        // Numeric chapters usually follow prologues / special prequels
        return 1;
      } else if (aNum == null && bNum != null) {
        return -1;
      } else {
        // Both non-numeric
        final dateCmp = a.publishedAt.compareTo(b.publishedAt);
        if (dateCmp != 0) return dateCmp;
        final strCmp = a.chapterNumber.compareTo(b.chapterNumber);
        if (strCmp != 0) return strCmp;
      }

      // Fallback to original index or ID for deterministic stability
      final idCmp = a.id.compareTo(b.id);
      if (idCmp != 0) return idCmp;
      return aEntry.key.compareTo(bEntry.key);
    });

    return listWithIndex.map((e) => e.value).toList();
  }

  /// Selects the initial chapter:
  /// 1. Exact resume chapter if [resumeChapterId] is provided and exists in [chapters],
  ///    provided it is not paid/locked.
  /// 2. Earliest free chapter (sorted chronologically ascending).
  /// 3. Never bypasses paid status. If all available chapters are paid, returns null.
  static Chapter? initialChapter(
    List<Chapter> chapters, {
    String? resumeChapterId,
  }) {
    if (chapters.isEmpty) return null;

    if (resumeChapterId != null && resumeChapterId.isNotEmpty) {
      final found = chapters.where((c) => c.id == resumeChapterId && !c.isPaid);
      if (found.isNotEmpty) {
        return found.first;
      }
    }

    final sorted = orderedChapters(chapters);
    final freeChapters = sorted.where((c) => !c.isPaid);
    if (freeChapters.isNotEmpty) {
      return freeChapters.first;
    }

    return null;
  }
}
