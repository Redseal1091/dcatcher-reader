enum PublicationType {
  all,
  manga,   // Япония (чтение справа-налево)
  manhwa,  // Корея (Webtoon, вертикальная лента)
  manhua,  // Китай (Webtoon, вертикальная лента)
}

enum ContentRating {
  safe,        // Без ограничений
  suggestive,  // 12+ / 16+
  erotica,     // 18+
}

class Manga {
  final String id;
  final String title;
  final String? altTitle;
  final String description;
  final String coverUrl;
  final PublicationType type;
  final ContentRating contentRating;
  final List<String> genres;
  final String status; // ongoing, completed, hiatus
  final double ratingScore;
  final int? releaseYear;
  final bool isLicensed;
  final int totalChapters;

  const Manga({
    required this.id,
    required this.title,
    this.altTitle,
    required this.description,
    required this.coverUrl,
    required this.type,
    required this.contentRating,
    this.genres = const [],
    this.status = 'ongoing',
    this.ratingScore = 8.5,
    this.releaseYear,
    this.isLicensed = false,
    this.totalChapters = 0,
  });

  String get statusLabel {
    final s = status.toLowerCase();
    if (s.contains('закончен') || s.contains('завершен') || s.contains('complete')) {
      return 'Закончен';
    } else if (s.contains('заморожен') || s.contains('приостановлен') || s.contains('hiatus')) {
      return 'Заморожен';
    } else {
      return 'Онгоинг';
    }
  }

  String get typeLabel {
    switch (type) {
      case PublicationType.manhwa:
        return 'Манхва';
      case PublicationType.manga:
        return 'Манга';
      case PublicationType.manhua:
        return 'Маньхуа';
      case PublicationType.all:
        return 'Все';
    }
  }

  String get ratingLabel {
    switch (contentRating) {
      case ContentRating.safe:
        return '0+';
      case ContentRating.suggestive:
        return '16+';
      case ContentRating.erotica:
        return '18+';
    }
  }
}
