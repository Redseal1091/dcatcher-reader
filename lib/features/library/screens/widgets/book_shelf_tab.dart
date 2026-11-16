import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/shadcn_colors.dart';
import '../../../books/services/books_repository.dart';
import '../../../books/services/book_progress_service.dart';
import '../../../novel_reader/models/novel_chapter.dart';
import '../../../novel_reader/screens/novel_reader_screen.dart';
import '../../models/book_shelf_item.dart';
import '../../state/book_shelf_provider.dart';

class BookShelfTab extends StatelessWidget {
  final BooksRepository? repository;

  const BookShelfTab({super.key, this.repository});

  BooksRepository _getRepo() => repository ?? BooksRepository();

  static const List<Color> _spinePalette = [
    Color(0xFF4A2828), // Deep burgundy
    Color(0xFF1E3A34), // Forest pine
    Color(0xFF1F2D44), // Classic navy
    Color(0xFF4A3525), // Saddle brown
    Color(0xFF38233D), // Royal plum
    Color(0xFF2E3E3E), // Slate dark teal
    Color(0xFF423B2A), // Dark olive
    Color(0xFF5A3326), // Burnt terracotta
    Color(0xFF1F3842), // Deep ocean
    Color(0xFF4B3F2E), // Antique taupe
    Color(0xFF3B2E2E), // Mahogany
    Color(0xFF283B36), // Dark spruce
  ];

  static Color getSpineColor(String id) {
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = (hash * 31 + id.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return _spinePalette[hash.abs() % _spinePalette.length];
  }

  static double getSpineHeight(String id) {
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = (hash * 17 + id.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return 170.0 + (hash.abs() % 20); // 170 to 189 dp
  }

  @override
  Widget build(BuildContext context) {
    final shelf = context.watch<BookShelfProvider>();

    if (!shelf.isLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: ShadcnColors.primary, strokeWidth: 2),
      );
    }

    final items = shelf.items;

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF251A14),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF4A3425)),
                ),
                child: const Icon(Icons.shelves, size: 48, color: Color(0xFFD4A373)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Книжная полка пуста',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ShadcnColors.foreground,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Добавленные книги появятся здесь в виде корешков на деревянной полке.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: ShadcnColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 24; // 12 padding each side
        const spineWidth = 44.0;
        const spineSpacing = 8.0;

        final itemsPerRow = ((availableWidth + spineSpacing) / (spineWidth + spineSpacing))
            .floor()
            .clamp(1, 10);

        final List<List<BookShelfItem>> shelves = [];
        for (var i = 0; i < items.length; i += itemsPerRow) {
          shelves.add(items.sublist(i, (i + itemsPerRow).clamp(0, items.length)));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 90),
          itemCount: shelves.length,
          itemBuilder: (context, index) {
            final chunk = shelves[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 195,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final book in chunk) ...[
                        _buildSpine(context, book, shelf),
                        const SizedBox(width: spineSpacing),
                      ],
                    ],
                  ),
                ),
                _buildWoodenShelfLedge(),
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWoodenShelfLedge() {
    return Container(
      height: 14,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF5D4037),
            Color(0xFF3E2723),
            Color(0xFF271915),
          ],
        ),
        borderRadius: BorderRadius.circular(2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            offset: Offset(0, 4),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildSpine(BuildContext context, BookShelfItem book, BookShelfProvider shelf) {
    final spineColor = getSpineColor(book.id);
    final height = getSpineHeight(book.id);

    return Semantics(
      label: 'Книга: ${book.title}, автор: ${book.author}',
      button: true,
      child: Tooltip(
        message: book.author.isNotEmpty ? '${book.title} — ${book.author}' : book.title,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(3),
            onTap: () => _showMetadataDetails(context, book, shelf),
            onLongPress: () => _confirmAndRemove(context, book, shelf),
            child: Container(
              width: 44,
              height: height,
              decoration: BoxDecoration(
                color: spineColor,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(1, 2),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: ClipRect(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                  child: Column(
                    children: [
                      // Top foil band
                      Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: const Color(0x66D4AF37),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        color: const Color(0x40D4AF37),
                      ),
                      const SizedBox(height: 6),

                      // Format indicator if available
                      if (book.availableFormats.isNotEmpty)
                        Text(
                          book.availableFormats.first.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            color: Color(0xA6FFFFFF),
                            letterSpacing: 0.5,
                          ),
                        ),
                      const SizedBox(height: 4),

                      // Rotated Title & Author within available vertical space
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final maxAvailableHeight = constraints.maxHeight;
                            final hasAuthor = book.author.isNotEmpty;
                            final authorHeight = hasAuthor
                                ? (maxAvailableHeight * 0.35).clamp(16.0, 48.0)
                                : 0.0;
                            final titleHeight = (maxAvailableHeight - (hasAuthor ? authorHeight + 4.0 : 0.0)).clamp(16.0, maxAvailableHeight);

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: titleHeight,
                                  child: Center(
                                    child: RotatedBox(
                                      quarterTurns: 3,
                                      child: SizedBox(
                                        width: titleHeight,
                                        child: Text(
                                          book.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Color(0xFFF7F4EE),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (hasAuthor) ...[
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: authorHeight,
                                    child: Center(
                                      child: RotatedBox(
                                        quarterTurns: 3,
                                        child: SizedBox(
                                          width: authorHeight,
                                          child: Text(
                                            book.author,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Color(0xFFD6CEBF),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Bottom foil band
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        color: const Color(0x40D4AF37),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: const Color(0x66D4AF37),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMetadataDetails(BuildContext context, BookShelfItem book, BookShelfProvider shelf) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ShadcnColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ShadcnColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Информация о книге',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ShadcnColors.mutedForeground,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ShadcnColors.foreground,
                    ),
                  ),
                  if (book.author.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: const TextStyle(
                        fontSize: 14,
                        color: ShadcnColors.mutedForeground,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (book.year != null)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: ShadcnColors.surface,
                          label: Text(
                            '${book.year} г.',
                            style: const TextStyle(fontSize: 12, color: ShadcnColors.foreground),
                          ),
                        ),
                      if (book.genre.isNotEmpty)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: ShadcnColors.surface,
                          label: Text(
                            book.genre,
                            style: const TextStyle(fontSize: 12, color: ShadcnColors.foreground),
                          ),
                        ),
                      for (final fmt in book.availableFormats)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFF2C221C),
                          label: Text(
                            fmt.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD4A373),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (book.description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Divider(color: ShadcnColors.border),
                    const SizedBox(height: 8),
                    Text(
                      book.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: ShadcnColors.foreground,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (book.isPdfOnly) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ShadcnColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ShadcnColors.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: ShadcnColors.mutedForeground, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Это издание доступно только в PDF. Встроенная читалка пока не поддерживает этот формат.',
                              style: TextStyle(
                                color: ShadcnColors.mutedForeground,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ShadcnColors.exclude,
                              side: const BorderSide(color: ShadcnColors.exclude),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _confirmAndRemove(context, book, shelf);
                            },
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Удалить с полки'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    if (book.lastReadPercent != null && book.lastReadPercent! > 0) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              book.lastChapterTitle != null && book.lastChapterTitle!.isNotEmpty
                                  ? 'Последняя: ${book.lastChapterTitle}'
                                  : 'Прогресс чтения',
                              style: const TextStyle(fontSize: 12, color: ShadcnColors.mutedForeground),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(book.lastReadPercent! * 100).toInt()}%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ShadcnColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: book.lastReadPercent!.clamp(0.0, 1.0),
                          backgroundColor: ShadcnColors.surface,
                          valueColor: const AlwaysStoppedAnimation<Color>(ShadcnColors.primary),
                          minHeight: 4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ShadcnColors.primary,
                              foregroundColor: ShadcnColors.primaryForeground,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await _openReader(context, book);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.menu_book, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  book.lastReadPercent != null && book.lastReadPercent! > 0
                                      ? 'Продолжить чтение'
                                      : 'Читать',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ShadcnColors.exclude,
                            side: const BorderSide(color: ShadcnColors.exclude),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _confirmAndRemove(context, book, shelf);
                          },
                          child: const Icon(Icons.delete_outline, size: 18),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openReader(BuildContext context, BookShelfItem book) async {
    try {
      final repo = _getRepo();
      var bookItem = await repo.getBookById(book.id);
      bookItem ??= book.toBookItem();

      final chapters = await repo.getBookChapters(bookItem);
      if (!context.mounted) return;

      if (chapters.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Текст книги временно недоступен')),
        );
        return;
      }

      final novelChapters = chapters.map((c) => NovelChapter(
        id: c.id,
        title: c.title,
        chapterNumber: c.number,
        content: c.content,
        publishedAt: DateTime(book.year ?? 0),
      )).toList();

      NovelChapter initialChapter = novelChapters.first;
      double initialOffset = 0.0;

      final savedProgress = await BookProgressService.getProgress(book.id);
      final targetChapterId = book.lastChapterId ?? savedProgress?.chapterId;
      if (targetChapterId != null && targetChapterId.isNotEmpty) {
        final match = novelChapters.where((c) => c.id == targetChapterId);
        if (match.isNotEmpty) {
          initialChapter = match.first;
          initialOffset = book.lastScrollOffset ?? savedProgress?.scrollOffset ?? 0.0;
        }
      }

      final title = book.author.isNotEmpty ? '${book.author} — ${book.title}' : book.title;

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NovelReaderScreen(
            bookId: book.id,
            novelTitle: title,
            chapter: initialChapter,
            allChapters: novelChapters,
            initialScrollOffset: initialOffset,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть книгу: $e')),
        );
      }
    }
  }

  Future<void> _confirmAndRemove(BuildContext context, BookShelfItem book, BookShelfProvider shelf) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ShadcnColors.card,
        title: const Text(
          'Удалить книгу?',
          style: TextStyle(color: ShadcnColors.foreground),
        ),
        content: Text(
          'Вы уверены, что хотите убрать «${book.title}» с книжной полки?',
          style: const TextStyle(color: ShadcnColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ShadcnColors.exclude,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await shelf.removeBook(book.id);
    }
  }
}
