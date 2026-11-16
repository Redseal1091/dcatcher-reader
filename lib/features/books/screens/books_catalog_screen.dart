import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../models/book_item.dart';
import '../services/books_repository.dart';
import '../services/book_progress_service.dart';
import '../widgets/book_offline_actions.dart';
import '../../novel_reader/models/novel_chapter.dart';
import '../../novel_reader/screens/novel_reader_screen.dart';
import '../../library/models/book_shelf_item.dart';
import '../../library/state/book_shelf_provider.dart';

class BooksCatalogScreen extends StatefulWidget {
  final BooksRepository? repository;

  const BooksCatalogScreen({super.key, this.repository});

  @override
  State<BooksCatalogScreen> createState() => _BooksCatalogScreenState();
}

class _BooksCatalogScreenState extends State<BooksCatalogScreen> {
  late final BooksRepository _repo;
  final TextEditingController _searchCtrl = TextEditingController();
  String _appliedSearch = '';
  String _selectedSource = 'Флибуста (Flibusta.site)';
  String _selectedGenre = 'Все';
  List<BookItem> _books = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isLoadingMore = false;
  bool _hasLoadMoreError = false;
  Uri? _nextPageUri;
  final Set<String> _seenBookIds = <String>{};
  final Set<Uri> _visitedUris = <Uri>{};
  int _generation = 0;

  static const String _sourcePrefKey = 'books_selected_source_v1';
  bool _userChangedSource = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _repo = widget.repository ?? BooksRepository();
    _initSourceAndLoad();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initSourceAndLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSource = prefs.getString(_sourcePrefKey);
      if (savedSource != null &&
          BooksRepository.availableSources.contains(savedSource) &&
          !_userChangedSource &&
          _generation == 0 &&
          mounted) {
        _selectedSource = savedSource;
      }
    } catch (_) {}
    if (mounted && _generation == 0) {
      _loadBooks();
    }
  }

  String _formatDisplayLabel(String mime) {
    final lower = mime.toLowerCase();
    if (lower.contains('pdf')) return 'PDF';
    if (lower.contains('epub')) return 'EPUB';
    if (lower.contains('fb2')) return 'FB2';
    if (lower.contains('html')) return 'HTML';
    if (lower.contains('plain') || lower.contains('txt')) return 'TXT';
    if (lower.contains('rtf')) return 'RTF';
    if (lower.contains('mobi') || lower.contains('x-mobipocket-ebook')) return 'MOBI';
    return 'Другой формат';
  }

  Future<void> _loadBooks() async {
    final currentGen = ++_generation;
    _appliedSearch = _searchCtrl.text.trim();
    final source = _selectedSource;
    final genre = _selectedGenre;
    final search = _appliedSearch;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _isLoadingMore = false;
      _hasLoadMoreError = false;
      _nextPageUri = null;
      _seenBookIds.clear();
      _visitedUris.clear();
    });
    try {
      final page = await _repo.getBooksPage(
        source: source,
        genre: genre,
        search: search,
      );
      if (currentGen != _generation || !mounted) return;

      if (page.documentUri != null) {
        _visitedUris.add(page.documentUri!);
      }

      final newItems = <BookItem>[];
      for (final item in page.items) {
        if (_seenBookIds.add(item.id)) {
          newItems.add(item);
        }
      }

      Uri? nextUri = page.nextPageUri;
      if (nextUri != null && _visitedUris.contains(nextUri)) {
        nextUri = null;
      }

      setState(() {
        _books = newItems;
        _nextPageUri = nextUri;
      });
    } catch (_) {
      if (currentGen != _generation || !mounted) return;
      setState(() {
        _books = [];
        _hasError = true;
      });
    } finally {
      if (currentGen == _generation && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _nextPageUri == null) return;
    final targetUri = _nextPageUri!;
    if (_visitedUris.contains(targetUri)) {
      setState(() => _nextPageUri = null);
      return;
    }

    final currentGen = _generation;
    final source = _selectedSource;
    final genre = _selectedGenre;
    final search = _appliedSearch;
    setState(() {
      _isLoadingMore = true;
      _hasLoadMoreError = false;
    });

    try {
      final page = await _repo.getBooksPage(
        source: source,
        genre: genre,
        search: search,
        pageUri: targetUri,
      );
      if (currentGen != _generation || !mounted) return;

      _visitedUris.add(targetUri);
      if (page.documentUri != null) {
        _visitedUris.add(page.documentUri!);
      }

      final appended = <BookItem>[];
      for (final item in page.items) {
        if (_seenBookIds.add(item.id)) {
          appended.add(item);
        }
      }

      Uri? nextUri = page.nextPageUri;
      if (nextUri != null && _visitedUris.contains(nextUri)) {
        nextUri = null;
      }

      setState(() {
        _books.addAll(appended);
        _nextPageUri = nextUri;
      });
    } catch (_) {
      if (currentGen != _generation || !mounted) return;
      setState(() {
        _hasLoadMoreError = true;
      });
    } finally {
      if (currentGen == _generation && mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _openReader(BookItem book, BookChapter chapter, [List<BookChapter>? allList]) async {
    final novelChapter = NovelChapter(
      id: chapter.id,
      title: chapter.title,
      chapterNumber: chapter.number,
      content: chapter.content,
      publishedAt: DateTime(book.year),
    );

    final sourceList = allList ?? book.chapters;
    final allNovelChapters = sourceList.map((c) => NovelChapter(
      id: c.id,
      title: c.title,
      chapterNumber: c.number,
      content: c.content,
      publishedAt: DateTime(book.year),
    )).toList();

    double initialOffset = 0.0;
    final savedProgress = await BookProgressService.getProgress(book.id);
    if (savedProgress != null && savedProgress.chapterId == novelChapter.id) {
      initialOffset = savedProgress.scrollOffset;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelReaderScreen(
          bookId: book.id,
          novelTitle: '${book.author} — ${book.title}',
          chapter: novelChapter,
          allChapters: allNovelChapters,
          initialScrollOffset: initialOffset,
        ),
      ),
    );
  }

  String _getSourceBadgeLabel() {
    if (_selectedSource == BooksRepository.downloadedSource) {
      return 'Скачано • Офлайн';
    }
    if (_selectedSource.contains('Классика')) {
      return 'Классика • Свободный доступ';
    }
    if (_selectedSource.contains('Мои книги')) {
      return 'Моя книга • Локально';
    }
    return 'Флибуста • Бесплатно';
  }

  void _showBookDetails(BookItem book) {
    Future<List<BookChapter>>? chaptersFuture;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
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
                          child: (_selectedSource == BooksRepository.downloadedSource ||
                                  book.coverUrl.trim().isEmpty ||
                                  !book.coverUrl.startsWith('http'))
                              ? Container(
                                  width: 80,
                                  height: 110,
                                  color: ShadcnColors.surface,
                                  child: const Icon(
                                    Icons.book,
                                    color: ShadcnColors.mutedForeground,
                                    size: 32,
                                  ),
                                )
                              : Image.network(
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
                                runSpacing: 4,
                                children: [
                                  if (book.genre.trim().isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: ShadcnColors.card,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: ShadcnColors.border),
                                      ),
                                      child: Text(book.genre, style: const TextStyle(fontSize: 11, color: ShadcnColors.foreground)),
                                    ),
                                  if (book.year > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: ShadcnColors.card,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: ShadcnColors.border),
                                      ),
                                      child: Text('${book.year} г.', style: const TextStyle(fontSize: 11, color: ShadcnColors.foreground)),
                                    ),
                                  if (book.rating > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: ShadcnColors.card,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: ShadcnColors.border),
                                      ),
                                      child: Text('★ ${book.rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0x2210B981),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF10B981)),
                                    ),
                                    child: Text(_getSourceBadgeLabel(), style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                  ),
                                  if (book.availableFormats.isNotEmpty)
                                    ...book.availableFormats.map((fmt) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: ShadcnColors.surface,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: ShadcnColors.border),
                                      ),
                                      child: Text(
                                        _formatDisplayLabel(fmt),
                                        style: const TextStyle(fontSize: 10, color: ShadcnColors.mutedForeground, fontWeight: FontWeight.w600),
                                      ),
                                    )),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    BookOfflineActions(
                      book: book,
                      repository: _repo,
                      loadChapters: () => chaptersFuture ??= _repo.getBookChapters(book),
                      onRemoved: () {
                        if (_selectedSource == BooksRepository.downloadedSource) {
                          Navigator.pop(ctx);
                          _loadBooks();
                        }
                      },
                    ),
                    Builder(
                      builder: (bCtx) {
                        BookShelfProvider? shelf;
                        try {
                          shelf = bCtx.watch<BookShelfProvider>();
                        } catch (_) {
                          shelf = null;
                        }
                        if (shelf == null) return const SizedBox.shrink();

                        final isOnShelf = shelf.contains(book.id);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isOnShelf ? const Color(0xFFD4A373) : ShadcnColors.foreground,
                                side: BorderSide(
                                  color: isOnShelf ? const Color(0xFFD4A373) : ShadcnColors.border,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              onPressed: () async {
                                if (isOnShelf) {
                                  await shelf?.removeBook(book.id);
                                } else {
                                  await shelf?.addBook(BookShelfItem.fromBookItem(book));
                                }
                              },
                              icon: Icon(
                                isOnShelf ? Icons.shelves : Icons.bookmark_add_outlined,
                                size: 16,
                                color: isOnShelf ? const Color(0xFFD4A373) : null,
                              ),
                              label: Text(
                                isOnShelf ? 'На книжной полке' : 'Добавить на книжную полку',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isOnShelf ? const Color(0xFFD4A373) : ShadcnColors.foreground,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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
                    if (book.isPdfOnly) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ShadcnColors.card,
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
                      ),
                    ] else if (book.chapters.isNotEmpty) ...[
                      Text('Оглавление (${book.chapters.length} глав)', style: const TextStyle(color: ShadcnColors.foreground, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...book.chapters.map((ch) => _buildChapterTile(ctx, book, ch, book.chapters)),
                    ] else ...[
                      FutureBuilder<List<BookChapter>>(
                        future: chaptersFuture ??= _repo.getBookChapters(book),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(strokeWidth: 2, color: ShadcnColors.primary),
                                    SizedBox(height: 12),
                                    Text('Загрузка глав с Flibusta.site...', style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13)),
                                  ],
                                ),
                              ),
                            );
                          }
                          final chapters = snapshot.data ?? [];
                          if (chapters.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Текст книги временно недоступен', style: TextStyle(color: ShadcnColors.mutedForeground)),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setModalState(() {
                                        chaptersFuture = _repo.getBookChapters(book);
                                      });
                                    },
                                    child: const Text('Повторить'),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ShadcnColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _openReader(book, chapters.first, chapters);
                                  },
                                  icon: const Icon(Icons.chrome_reader_mode_outlined, size: 18),
                                  label: const Text(
                                    'Читать книгу',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text('Оглавление (${chapters.length} глав)', style: const TextStyle(color: ShadcnColors.foreground, fontSize: 14, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              ...chapters.map((ch) => _buildChapterTile(ctx, book, ch, chapters)),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChapterTile(BuildContext ctx, BookItem book, BookChapter ch, List<BookChapter> allChapters) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ShadcnColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadcnColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          leading: const Icon(Icons.menu_book, color: ShadcnColors.foreground, size: 20),
          title: Text(
            ch.title,
            style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: ShadcnColors.mutedForeground, size: 14),
          onTap: () {
            Navigator.pop(ctx);
            _openReader(book, ch, allChapters);
          },
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

  Widget _buildEmptyState() {
    if (_appliedSearch.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 52,
                color: ShadcnColors.mutedForeground.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 14),
              Text(
                'По запросу «$_appliedSearch» ничего не найдено',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ShadcnColors.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Попробуйте изменить поисковый запрос или выбрать другой источник',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ShadcnColors.mutedForeground,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ShadcnColors.foreground,
                  side: const BorderSide(color: ShadcnColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Сбросить поиск'),
                onPressed: () {
                  _searchCtrl.clear();
                  _loadBooks();
                },
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedSource == BooksRepository.downloadedSource) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.download_done_rounded,
                size: 52,
                color: ShadcnColors.mutedForeground.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 14),
              const Text(
                'Нет скачанных книг',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ShadcnColors.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Книги, сохранённые для офлайн-чтения, появятся здесь',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ShadcnColors.mutedForeground,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 52,
              color: ShadcnColors.mutedForeground.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 14),
            Text(
              'Ничего не найдено в источнике $_selectedSource',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ShadcnColors.foreground,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_selectedGenre != 'Все') ...[
              const SizedBox(height: 14),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ShadcnColors.foreground,
                  side: const BorderSide(color: ShadcnColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Показать все жанры'),
                onPressed: () {
                  setState(() => _selectedGenre = 'Все');
                  _loadBooks();
                },
              ),
            ],
          ],
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
                  _userChangedSource = true;
                  setState(() => _selectedSource = val);
                  SharedPreferences.getInstance().then((prefs) {
                    prefs.setString(_sourcePrefKey, val);
                  }).catchError((_) {});
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
                      hintText: _selectedSource == BooksRepository.downloadedSource
                          ? 'Поиск среди скачанных...'
                          : 'Поиск во Флибусте...',
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
              : _hasError
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Не удалось загрузить книги"),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadBooks,
                            child: const Text("Повторить"),
                          ),
                        ],
                      ),
                    )
                  : (_books.isEmpty && _nextPageUri == null)
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadBooks,
                          color: ShadcnColors.primary,
                          backgroundColor: ShadcnColors.card,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                            itemCount: _books.length + (_nextPageUri != null ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _books.length) {
                                if (_isLoadingMore) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                }
                                if (_hasLoadMoreError) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Center(
                                      child: TextButton(
                                        onPressed: _isLoadingMore ? null : _loadMore,
                                        child: const Text('Повторить'),
                                      ),
                                    ),
                                  );
                                }
                                if (_books.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.auto_stories_outlined,
                                            size: 48,
                                            color: ShadcnColors.mutedForeground.withValues(alpha: 0.5),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            _selectedGenre != 'Все'
                                                ? 'В текущей выборке нет книг жанра «$_selectedGenre»'
                                                : 'В текущей выборке нет книг',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: ShadcnColors.foreground,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            'Попробуйте продолжить поиск на следующей странице каталога',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: ShadcnColors.mutedForeground,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          TextButton(
                                            onPressed: _isLoadingMore ? null : _loadMore,
                                            child: const Text('Загрузить ещё'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Center(
                                    child: TextButton(
                                      onPressed: _isLoadingMore ? null : _loadMore,
                                      child: const Text('Загрузить ещё'),
                                    ),
                                  ),
                                );
                              }
                              final book = _books[index];
                              return _BookListItem(
                                book: book,
                                isOfflineSource: _selectedSource == BooksRepository.downloadedSource,
                                onTap: () => _showBookDetails(book),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}
class _BookListItem extends StatefulWidget {
  final BookItem book;
  final bool isOfflineSource;
  final VoidCallback onTap;

  const _BookListItem({
    required this.book,
    this.isOfflineSource = false,
    required this.onTap,
  });

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
                  child: (widget.isOfflineSource ||
                          book.coverUrl.trim().isEmpty ||
                          !book.coverUrl.startsWith('http'))
                      ? Container(
                          width: 65,
                          height: 90,
                          color: ShadcnColors.surface,
                          child: const Icon(
                            Icons.book,
                            color: ShadcnColors.mutedForeground,
                            size: 28,
                          ),
                        )
                      : Image.network(
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
                          Flexible(
                            fit: FlexFit.loose,
                            child: Tooltip(
                              message: book.genre,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ShadcnColors.surface,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: ShadcnColors.border),
                                ),
                                child: Text(
                                  book.genre,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, color: ShadcnColors.foreground),
                                ),
                              ),
                            ),
                          ),
                          if (book.chapters.isNotEmpty) ...[
                            const Spacer(),
                            Text(
                              '${book.chapters.length} глав',
                              style: const TextStyle(fontSize: 11, color: ShadcnColors.mutedForeground, fontWeight: FontWeight.w500),
                            ),
                          ],
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
