enum UserMangaStatus {
  reading,    // Читаю
  completed,  // Прочитано
  planned,    // В планах
  dropped,    // Брошено
}

class LibraryItem {
  final String mangaId;
  final UserMangaStatus status;
  final String lastChapterId;
  final String lastChapterNumber;
  final int lastPage;
  final String? title;
  final String? coverUrl;
  final DateTime updatedAt;

  const LibraryItem({
    required this.mangaId,
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
    'status': status.name,
    'lastChapterId': lastChapterId,
    'lastChapterNumber': lastChapterNumber,
    'lastPage': lastPage,
    'title': title,
    'coverUrl': coverUrl,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory LibraryItem.fromJson(Map<String, dynamic> json) => LibraryItem(
    mangaId: json['mangaId'] as String,
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

  LibraryItem copyWith({
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
      status: status ?? this.status,
      lastChapterId: lastChapterId ?? this.lastChapterId,
      lastChapterNumber: lastChapterNumber ?? this.lastChapterNumber,
      lastPage: lastPage ?? this.lastPage,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
