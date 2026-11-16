import '../../catalog/models/manga.dart';

enum UserMangaStatus {
  reading,    // Читаю
  completed,  // Прочитано
  planned,    // В планах
  dropped,    // Брошено
}

class LibraryItem {
  final String mangaId;
  final String sourceId;
  final UserMangaStatus status;
  final String lastChapterId;
  final String lastChapterNumber;
  final int lastPage;
  final String? title;
  final String? coverUrl;
  final DateTime updatedAt;

  const LibraryItem({
    required this.mangaId,
    this.sourceId = '',
    required this.status,
    this.lastChapterId = '',
    this.lastChapterNumber = '',
    this.lastPage = 1,
    this.title,
    this.coverUrl,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'mangaId': mangaId,
    'sourceId': sourceId,
    'status': status.name,
    'lastChapterId': lastChapterId,
    'lastChapterNumber': lastChapterNumber,
    'lastPage': lastPage,
    'title': title,
    'coverUrl': coverUrl,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    final mangaId = json['mangaId'] as String? ?? '';
    String sourceId = json['sourceId'] as String? ?? '';
    if (sourceId.isEmpty && mangaId.contains('::')) {
      sourceId = mangaId.split('::').first;
    }

    return LibraryItem(
      mangaId: mangaId,
      sourceId: sourceId,
      status: UserMangaStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => UserMangaStatus.reading,
      ),
      lastChapterId: json['lastChapterId'] as String? ?? '',
      lastChapterNumber: json['lastChapterNumber'] as String? ?? '',
      lastPage: json['lastPage'] as int? ?? 1,
      title: json['title'] as String?,
      coverUrl: json['coverUrl'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  LibraryItem copyWith({
    String? sourceId,
    UserMangaStatus? status,
    String? lastChapterId,
    String? lastChapterNumber,
    int? lastPage,
    String? title,
    String? coverUrl,
    DateTime? updatedAt,
  }) {
    return LibraryItem(
      mangaId: mangaId,
      sourceId: sourceId ?? this.sourceId,
      status: status ?? this.status,
      lastChapterId: lastChapterId ?? this.lastChapterId,
      lastChapterNumber: lastChapterNumber ?? this.lastChapterNumber,
      lastPage: lastPage ?? this.lastPage,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Manga toManga() {
    return Manga(
      id: mangaId,
      title: title ?? 'Без названия',
      description: '',
      coverUrl: coverUrl ?? '',
      type: PublicationType.all,
      contentRating: ContentRating.safe,
      sourceId: sourceId,
    );
  }
}
