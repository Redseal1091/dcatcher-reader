import 'package:flutter/material.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../models/book_item.dart';
import '../services/books_repository.dart';
import '../../novel_reader/models/novel_chapter.dart';
import '../../novel_reader/screens/novel_reader_screen.dart';

class BooksCatalogScreen extends StatefulWidget {
  const BooksCatalogScreen({super.key});

  @override
  State<BooksCatalogScreen> createState() => _BooksCatalogScreenState();
}

class _BooksCatalogScreenState extends State<BooksCatalogScreen> {
  final BooksRepository _repo = BooksRepository();
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedSource = 'Флибуста (Flibusta)';
  String _selectedGenre = 'Все';
  List<BookItem> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    final list = await _repo.getBooks(
      source: _selectedSource,
      genre: _selectedGenre,
      search: _searchCtrl.text,
    );
    if (mounted) {
      setState(() {
        _books = list;
        _isLoading = false;
      });
    }
  }

  void _openReader(BookItem book, BookChapter chapter) {
    final novelChapter = NovelChapter(
      id: chapter.id,
      title: chapter.title,
      chapterNumber: chapter.number,
      content: chapter.content,
      publishedAt: DateTime(book.year),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelReaderScreen(
          novelTitle: '${book.author} — ${book.title}',
          chapter: novelChapter,
        ),
      ),
    );
  }

  void _showBookDetails(BookItem book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: ShadcnColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: ShadcnColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ShadcnColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          book.coverUrl,
                          width: 80,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 110,
                            color: ShadcnColors.surface,
                            child: const Icon(Icons.book, color: ShadcnColors.mutedForeground),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              style: const TextStyle(
                                color: ShadcnColors.foreground,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              book.author,
                              style: const TextStyle(
                                color: ShadcnColors.mutedForeground,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: ShadcnColors.card,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: ShadcnColors.border),
                                  ),
                                  child: Text(book.genre, style: const TextStyle(fontSize: 11, color: ShadcnColors.foreground)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0x2210B981),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF10B981)),
                                  ),
                                  child: const Text('Флибуста • Бесплатно', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Text('Аннотация книги', style: TextStyle(color: ShadcnColors.foreground, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    book.description,
                    style: const TextStyle(
                      color: ShadcnColors.mutedForeground,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text('Оглавление (${book.chapters.length} глав)', style: const TextStyle(color: ShadcnColors.foreground, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  ...book.chapters.map((ch) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: ShadcnColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ShadcnColors.border),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.menu_book, color: ShadcnColors.foreground, size: 20),
                        title: Text(ch.title, style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: ShadcnColors.mutedForeground, size: 14),
                        onTap: () {
                          Navigator.pop(ctx);
                          _openReader(book, ch);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomBookDialog() {
    final titleCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    final chapterCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String genre = 'Фантастика';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: ShadcnColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: ShadcnColors.border)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ShadcnColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Импорт книги в библиотеку',
                style: TextStyle(color: ShadcnColors.foreground, fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Вставьте текст книги или главы из файла',
                style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12),
              ),
              const SizedBox(height: 14),

              Expanded(
                child: ListView(
                  children: [
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: ShadcnColors.foreground, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Название произведения',
                        labelStyle: const TextStyle(color: ShadcnColors.mutedForeground),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ShadcnColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ShadcnColors.primary)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: authorCtrl,
                      style: const TextStyle(color: ShadcnColors.foreground, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Автор (например, Стругацкие)',
                        labelStyle: const TextStyle(color: ShadcnColors.mutedForeground),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ShadcnColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ShadcnColors.primary)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: genre,
                      dropdownColor: ShadcnColors.card,
                      style: const TextStyle(color: ShadcnColors.foreground, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Жанр',
                        labelStyle: const TextStyle(color: ShadcnColors.mutedForeground),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ShadcnColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ShadcnColors.primary)),
                      ),
                      items: BooksRepository.genres
                          .where((g) => g != 'Все')
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => genre = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: chapterCtrl,
                      style: const TextStyle(color: ShadcnColors.foreground, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Название первой главы',
                        labelStyle: const TextStyle(color: ShadcnColors.mutedForeground),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ShadcnColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ShadcnColors.primary)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 8,
                      style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Текст произведения...',
                        alignLabelWithHint: true,
                        labelStyle: const TextStyle(color: ShadcnColors.mutedForeground),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ShadcnColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ShadcnColors.primary)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ShadcnColors.primary,
                    foregroundColor: ShadcnColors.primaryForeground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                      return;
                    }
                    await _repo.addCustomBook(
                      title: titleCtrl.text.trim(),
                      author: authorCtrl.text.trim(),
                      genre: genre,
                      chapterTitle: chapterCtrl.text.trim(),
                      content: contentCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) _loadBooks();
                  },
                  child: const Text('Сохранить книгу в DCatcher', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Источник и быстрый поиск
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(
            children: [
              // Выбор источника книг
              PopupMenuButton<String>(
                initialValue: _selectedSource,
                onSelected: (val) {
                  setState(() => _selectedSource = val);
                  _loadBooks();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: ShadcnColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ShadcnColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.library_books, color: ShadcnColors.primary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _selectedSource.split(' ')[0],
                        style: const TextStyle(color: ShadcnColors.foreground, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: ShadcnColors.mutedForeground, size: 18),
                    ],
                  ),
                ),
                itemBuilder: (ctx) => BooksRepository.availableSources
                    .map((s) => PopupMenuItem(
                          value: s,
                          child: Text(
                            s,
                            style: TextStyle(
                              color: s == _selectedSource ? ShadcnColors.primary : ShadcnColors.foreground,
                              fontWeight: s == _selectedSource ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ))
                    .toList(),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: ShadcnColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ShadcnColors.border),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Поиск во Флибусте...',
                      hintStyle: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                      icon: const Icon(Icons.search, color: ShadcnColors.mutedForeground, size: 18),
                      border: InputBorder.none,
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: ShadcnColors.mutedForeground, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                _loadBooks();
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _loadBooks(),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: ShadcnColors.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: ShadcnColors.border)),
                  padding: const EdgeInsets.all(10),
                ),
                icon: const Icon(Icons.add, color: ShadcnColors.foreground, size: 18),
                tooltip: 'Добавить книгу',
                onPressed: _showAddCustomBookDialog,
              ),
            ],
          ),
        ),

        // Горизонтальный скролл жанров
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: BooksRepository.genres.length,
            itemBuilder: (context, index) {
              final g = BooksRepository.genres[index];
              final isSel = _selectedGenre == g;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedGenre = g);
                    _loadBooks();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSel ? ShadcnColors.primary : ShadcnColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSel ? ShadcnColors.primary : ShadcnColors.border),
                    ),
                    child: Center(
                      child: Text(
                        g,
                        style: TextStyle(
                          color: isSel ? ShadcnColors.primaryForeground : ShadcnColors.foreground,
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 6),

        // Список книг с ненавязчивой анимацией нажатия
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _books.isEmpty
                  ? Center(
                      child: Text(
                        'Ничего не найдено в источнике $_selectedSource',
                        style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                      itemCount: _books.length,
                      itemBuilder: (context, index) {
                        final book = _books[index];
                        return _BookListItem(
                          book: book,
                          onTap: () => _showBookDetails(book),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _BookListItem extends StatefulWidget {
  final BookItem book;
  final VoidCallback onTap;

  const _BookListItem({required this.book, required this.onTap});

  @override
  State<_BookListItem> createState() => _BookListItemState();
}

class _BookListItemState extends State<_BookListItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final isFlibusta = book.id.startsWith('flibusta_');

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: ShadcnColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ShadcnColors.border),
        ),
        child: InkWell(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    book.coverUrl,
                    width: 65,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 65,
                      height: 90,
                      color: ShadcnColors.surface,
                      child: const Icon(Icons.book, color: ShadcnColors.mutedForeground),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ShadcnColors.foreground,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isFlibusta)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: ShadcnColors.primary.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ФЛИБУСТА',
                                style: TextStyle(color: ShadcnColors.primary, fontSize: 8.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        book.author,
                        style: const TextStyle(
                          color: ShadcnColors.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        book.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ShadcnColors.mutedForeground,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ShadcnColors.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: ShadcnColors.border),
                            ),
                            child: Text(
                              book.genre,
                              style: const TextStyle(fontSize: 10, color: ShadcnColors.foreground),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${book.chapters.length} глав',
                            style: const TextStyle(fontSize: 11, color: ShadcnColors.mutedForeground, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
