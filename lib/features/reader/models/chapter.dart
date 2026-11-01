class Chapter {
  final String id;
  final String mangaId;
  final String chapterNumber;
  final String? title;
  final String language;
  final String scanlationGroup;
  final DateTime publishedAt;
  final int pagesCount;
  final bool isPaid;

  const Chapter({
    required this.id,
    required this.mangaId,
    required this.chapterNumber,
    this.title,
    this.language = 'ru',
    this.scanlationGroup = 'Переводчики',
    required this.publishedAt,
    this.pagesCount = 20,
    this.isPaid = false,
  });

  String get displayName {
    final prefix = isPaid ? '🔒 ' : '';
    if (title != null && title!.isNotEmpty) {
      return '$prefixГлава $chapterNumber: $title';
    }
    return '$prefixГлава $chapterNumber';
  }
}
