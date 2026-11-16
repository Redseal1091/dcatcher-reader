class NovelChapter {
  final String id;
  final String title;
  final String chapterNumber;
  final String content;
  final DateTime publishedAt;
  final String? url;
  final String? volume;

  const NovelChapter({
    required this.id,
    required this.title,
    required this.chapterNumber,
    required this.content,
    required this.publishedAt,
    this.url,
    this.volume,
  });

  NovelChapter copyWith({
    String? id,
    String? title,
    String? chapterNumber,
    String? content,
    DateTime? publishedAt,
    String? url,
    String? volume,
  }) {
    return NovelChapter(
      id: id ?? this.id,
      title: title ?? this.title,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      content: content ?? this.content,
      publishedAt: publishedAt ?? this.publishedAt,
      url: url ?? this.url,
      volume: volume ?? this.volume,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'number': chapterNumber,
    'content': content,
    'publishedAt': publishedAt.toIso8601String(),
    'url': url,
    'volume': volume,
  };

  factory NovelChapter.fromJson(Map<String, dynamic> json) => NovelChapter(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    chapterNumber: (json['number'] ?? json['chapterNumber'] ?? '1').toString(),
    content: json['content'] as String? ?? '',
    publishedAt: json['publishedAt'] != null
        ? DateTime.tryParse(json['publishedAt']) ?? DateTime.now()
        : DateTime.now(),
    url: json['url'] as String?,
    volume: json['volume'] as String?,
  );
}
