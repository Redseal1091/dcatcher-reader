class UnsupportedPlatformException implements Exception {
  final String message;
  const UnsupportedPlatformException(this.message);

  @override
  String toString() => 'UnsupportedPlatformException: $message';
}

class ExtensionCatalogItem {
  final String url;
  final String title;
  final String thumbnailUrl;
  final String description;
  final String genre;
  final String status;
  final String author;
  final String artist;

  const ExtensionCatalogItem({
    required this.url,
    required this.title,
    this.thumbnailUrl = '',
    this.description = '',
    this.genre = '',
    this.status = 'ongoing',
    this.author = '',
    this.artist = '',
  });

  static String parseStatus(dynamic rawStatus) {
    if (rawStatus == null) return 'unknown';
    final str = rawStatus.toString().trim().toLowerCase();

    switch (str) {
      case '1':
        return 'ongoing';
      case '2':
      case '4':
        return 'completed';
      case '5':
      case '6':
        return 'hiatus';
      case '0':
      case '3':
      case 'unknown':
      case '':
        return 'unknown';
    }

    if (str.contains('complete') || str.contains('закончен') || str.contains('завершен')) {
      return 'completed';
    }
    if (str.contains('hiatus') || str.contains('заморожен') || str.contains('приостановлен') || str.contains('cancel')) {
      return 'hiatus';
    }
    if (str.contains('ongoing') || str.contains('онгоинг') || str.contains('продолж') || str.contains('выход')) {
      return 'ongoing';
    }
    return 'unknown';
  }

  factory ExtensionCatalogItem.fromJson(Map<String, dynamic> json) {
    return ExtensionCatalogItem(
      url: json['url']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? json['thumbnail_url']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      genre: json['genre']?.toString() ?? '',
      status: parseStatus(json['status']),
      author: json['author']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'thumbnailUrl': thumbnailUrl,
    'description': description,
    'genre': genre,
    'status': status,
    'author': author,
    'artist': artist,
  };
}

class ExtensionCatalogPage {
  final List<ExtensionCatalogItem> items;
  final bool hasNextPage;

  const ExtensionCatalogPage({
    required this.items,
    required this.hasNextPage,
  });

  factory ExtensionCatalogPage.fromJson(Map<String, dynamic> json) {
    final rawList = json['items'] as List<dynamic>? ?? [];
    return ExtensionCatalogPage(
      items: rawList.map((raw) {
        if (raw is! Map) {
          throw FormatException('Invalid catalog item shape: expected Map, got ${raw.runtimeType}');
        }
        return ExtensionCatalogItem.fromJson(Map<String, dynamic>.from(raw));
      }).toList(),
      hasNextPage: json['hasNextPage'] as bool? ?? false,
    );
  }
}

class ExtensionMangaDetails {
  final String url;
  final String title;
  final String thumbnailUrl;
  final String description;
  final String genre;
  final String status;
  final String author;
  final String artist;

  const ExtensionMangaDetails({
    required this.url,
    required this.title,
    this.thumbnailUrl = '',
    this.description = '',
    this.genre = '',
    this.status = 'ongoing',
    this.author = '',
    this.artist = '',
  });

  factory ExtensionMangaDetails.fromJson(Map<String, dynamic> json) {
    return ExtensionMangaDetails(
      url: json['url']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      genre: json['genre']?.toString() ?? '',
      status: ExtensionCatalogItem.parseStatus(json['status']),
      author: json['author']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
    );
  }
}

class ExtensionChapterItem {
  final String url;
  final String name;
  final String chapterNumber;
  final String dateUpload;
  final String scanlator;

  const ExtensionChapterItem({
    required this.url,
    required this.name,
    required this.chapterNumber,
    this.dateUpload = '',
    this.scanlator = '',
  });

  factory ExtensionChapterItem.fromJson(Map<String, dynamic> json) {
    return ExtensionChapterItem(
      url: json['url']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      chapterNumber: json['chapterNumber']?.toString() ?? json['chapter_number']?.toString() ?? '1',
      dateUpload: json['dateUpload']?.toString() ?? json['date_upload']?.toString() ?? '',
      scanlator: json['scanlator']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'name': name,
    'chapterNumber': chapterNumber,
    'dateUpload': dateUpload,
    'scanlator': scanlator,
  };
}

class ExtensionInstallProgress {
  final String packageName;
  final int received;
  final int total;

  const ExtensionInstallProgress({
    required this.packageName,
    required this.received,
    required this.total,
  });

  double get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
}
