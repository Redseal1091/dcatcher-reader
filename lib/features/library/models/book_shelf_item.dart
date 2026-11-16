import '../../books/models/book_item.dart';

class BookShelfItem {
  final String id;
  final String title;
  final String author;
  final String genre;
  final int? year;
  final String coverUrl;
  final String description;
  final List<String> availableFormats;
  final DateTime addedAt;
  final String? lastChapterId;
  final String? lastChapterTitle;
  final double? lastScrollOffset;
  final double? lastReadPercent;
  final DateTime? lastReadAt;

  const BookShelfItem({
    required this.id,
    required this.title,
    this.author = '',
    this.genre = '',
    this.year,
    this.coverUrl = '',
    this.description = '',
    this.availableFormats = const [],
    required this.addedAt,
    this.lastChapterId,
    this.lastChapterTitle,
    this.lastScrollOffset,
    this.lastReadPercent,
    this.lastReadAt,
  });

  bool get isPdfOnly =>
      availableFormats.isNotEmpty &&
      availableFormats.every((fmt) {
        final f = fmt.toLowerCase();
        return f == 'application/pdf' || f == 'pdf';
      });

  factory BookShelfItem.fromBookItem(BookItem book, {DateTime? addedAt}) {
    return BookShelfItem(
      id: book.id,
      title: book.title,
      author: book.author,
      genre: book.genre,
      year: book.year,
      coverUrl: book.coverUrl,
      description: book.description,
      availableFormats: List.unmodifiable(book.availableFormats),
      addedAt: addedAt ?? DateTime.now(),
    );
  }

  BookItem toBookItem({List<BookChapter> chapters = const []}) {
    return BookItem(
      id: id,
      title: title,
      author: author,
      genre: genre,
      year: year ?? 0,
      coverUrl: coverUrl,
      description: description,
      chapters: chapters,
      availableFormats: availableFormats,
    );
  }

  factory BookShelfItem.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim();
    if (id == null || id.isEmpty) {
      throw const FormatException('BookShelfItem requires a valid non-empty id');
    }

    final title = json['title']?.toString().trim();
    if (title == null || title.isEmpty) {
      throw const FormatException('BookShelfItem requires a valid non-empty title');
    }

    int? parsedYear;
    if (json['year'] != null) {
      parsedYear = int.tryParse(json['year'].toString());
    }

    final List<String> formats = [];
    if (json['availableFormats'] is List) {
      for (final item in json['availableFormats'] as List) {
        final fmt = item?.toString().trim();
        if (fmt != null && fmt.isNotEmpty) {
          formats.add(fmt);
        }
      }
    }

    DateTime parsedAddedAt;
    if (json['addedAt'] != null) {
      parsedAddedAt = DateTime.tryParse(json['addedAt'].toString()) ?? DateTime.now();
    } else {
      parsedAddedAt = DateTime.now();
    }

    final lastChapterId = json['lastChapterId']?.toString();
    final lastChapterTitle = json['lastChapterTitle']?.toString();
    final lastScrollOffset = (json['lastScrollOffset'] as num?)?.toDouble();
    final lastReadPercent = (json['lastReadPercent'] as num?)?.toDouble();
    DateTime? lastReadAt;
    if (json['lastReadAt'] != null) {
      lastReadAt = DateTime.tryParse(json['lastReadAt'].toString());
    }

    return BookShelfItem(
      id: id,
      title: title,
      author: json['author']?.toString() ?? '',
      genre: json['genre']?.toString() ?? '',
      year: parsedYear,
      coverUrl: json['coverUrl']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      availableFormats: List.unmodifiable(formats),
      addedAt: parsedAddedAt,
      lastChapterId: lastChapterId,
      lastChapterTitle: lastChapterTitle,
      lastScrollOffset: lastScrollOffset,
      lastReadPercent: lastReadPercent,
      lastReadAt: lastReadAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'genre': genre,
      'year': year,
      'coverUrl': coverUrl,
      'description': description,
      'availableFormats': availableFormats,
      'addedAt': addedAt.toIso8601String(),
      'lastChapterId': lastChapterId,
      'lastChapterTitle': lastChapterTitle,
      'lastScrollOffset': lastScrollOffset,
      'lastReadPercent': lastReadPercent,
      'lastReadAt': lastReadAt?.toIso8601String(),
    };
  }

  BookShelfItem copyWith({
    String? id,
    String? title,
    String? author,
    String? genre,
    int? year,
    String? coverUrl,
    String? description,
    List<String>? availableFormats,
    DateTime? addedAt,
    String? lastChapterId,
    String? lastChapterTitle,
    double? lastScrollOffset,
    double? lastReadPercent,
    DateTime? lastReadAt,
  }) {
    return BookShelfItem(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      availableFormats: availableFormats ?? this.availableFormats,
      addedAt: addedAt ?? this.addedAt,
      lastChapterId: lastChapterId ?? this.lastChapterId,
      lastChapterTitle: lastChapterTitle ?? this.lastChapterTitle,
      lastScrollOffset: lastScrollOffset ?? this.lastScrollOffset,
      lastReadPercent: lastReadPercent ?? this.lastReadPercent,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookShelfItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'BookShelfItem(id: $id, title: $title, author: $author)';
}
