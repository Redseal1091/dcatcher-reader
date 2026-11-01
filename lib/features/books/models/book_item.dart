class BookChapter {
  final String id;
  final String number;
  final String title;
  final String content;

  const BookChapter({
    required this.id,
    required this.number,
    required this.title,
    required this.content,
  });
}

class BookItem {
  final String id;
  final String title;
  final String author;
  final String genre;
  final String coverUrl;
  final String description;
  final int year;
  final double rating;
  final List<BookChapter> chapters;
  final bool isFree;

  const BookItem({
    required this.id,
    required this.title,
    required this.author,
    required this.genre,
    required this.coverUrl,
    required this.description,
    required this.year,
    this.rating = 9.2,
    required this.chapters,
    this.isFree = true,
  });
}
