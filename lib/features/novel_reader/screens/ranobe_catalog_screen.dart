import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../services/novel_repository.dart';
import '../models/novel_chapter.dart';
import '../screens/novel_reader_screen.dart';

class RanobeCatalogScreen extends StatefulWidget {
  const RanobeCatalogScreen({super.key});

  @override
  State<RanobeCatalogScreen> createState() => _RanobeCatalogScreenState();
}

class _RanobeCatalogScreenState extends State<RanobeCatalogScreen> {
  final NovelRepository _repo = NovelRepository();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<NovelBook> _novels = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String _activeSource = 'RanobeHub';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<AppSettingsProvider>();
      final savedSource = settings.ranobeSource;
      if (savedSource.isNotEmpty && NovelRepository.availableSources.contains(savedSource)) {
        setState(() => _activeSource = savedSource);
      }
      _loadNovels(reset: true);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (max - current <= 300 && !_isLoading && !_isLoadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadNovels({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _page = 1;
        _hasMore = true;
      });
    }

    final query = _searchCtrl.text.trim();
    try {
      List<NovelBook> list;
      if (query.isNotEmpty) {
        list = await _repo.searchNovels(query, source: _activeSource, page: 1);
      } else {
        list = await _repo.getAllNovels(source: _activeSource, page: 1);
      }

      if (!mounted) return;
      setState(() {
        _novels = list;
        _isLoading = false;
        _hasMore = list.length >= 10;
        _page = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка загрузки каталога ранобэ: $e';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _page + 1;
    final query = _searchCtrl.text.trim();
    try {
      List<NovelBook> nextList;
      if (query.isNotEmpty) {
        nextList = await _repo.searchNovels(query, source: _activeSource, page: nextPage);
      } else {
        nextList = await _repo.getAllNovels(source: _activeSource, page: nextPage);
      }

      if (!mounted) return;
      if (nextList.isEmpty) {
        setState(() {
          _isLoadingMore = false;
          _hasMore = false;
        });
      } else {
        // filter out duplicates by id
        final existingIds = _novels.map((n) => n.id).toSet();
        final filtered = nextList.where((n) => !existingIds.contains(n.id)).toList();
        setState(() {
          _novels.addAll(filtered);
          _page = nextPage;
          _isLoadingMore = false;
          _hasMore = nextList.length >= 10;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _onSourceSelected(String source) {
    if (source == _activeSource) return;
    setState(() {
      _activeSource = source;
    });
    context.read<AppSettingsProvider>().setSource('ranobe', source);
    _loadNovels(reset: true);
  }

  void _showNovelChapters(NovelBook book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NovelChaptersModal(book: book, repo: _repo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Панель источника и поиска
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              // Выбор источника
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: PopupMenuButton<String>(
                  initialValue: _activeSource,
                  tooltip: 'Сменить источник ранобэ',
                  onSelected: _onSourceSelected,
                  color: ShadcnColors.card,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: ShadcnColors.border),
                  ),
                  itemBuilder: (context) {
                    return NovelRepository.availableSources.map((src) {
                      final isSelected = src == _activeSource;
                      final icon = src == 'DCatcher Novels'
                          ? Icons.offline_pin_outlined
                          : Icons.public_rounded;
                      return PopupMenuItem<String>(
                        value: src,
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              size: 16,
                              color: isSelected ? ShadcnColors.primary : ShadcnColors.mutedForeground,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                src,
                                style: TextStyle(
                                  color: isSelected ? ShadcnColors.primary : ShadcnColors.foreground,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check, size: 16, color: ShadcnColors.primary),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: ShadcnColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ShadcnColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _activeSource == 'DCatcher Novels'
                              ? Icons.offline_pin_outlined
                              : Icons.public_rounded,
                          size: 14,
                          color: const Color(0xFFE11D48),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _activeSource,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ShadcnColors.foreground,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: ShadcnColors.mutedForeground),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Поле поиска
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: ShadcnColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ShadcnColors.border),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Поиск новелл...',
                      hintStyle: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                      icon: const Icon(Icons.search, color: ShadcnColors.mutedForeground, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: ShadcnColors.mutedForeground, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _searchCtrl.clear();
                                _loadNovels(reset: true);
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _loadNovels(reset: true),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Список ранобэ
        Expanded(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFE11D48), strokeWidth: 2),
                      SizedBox(height: 12),
                      Text(
                        'Загрузка каталога ранобэ...',
                        style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off_rounded, color: ShadcnColors.mutedForeground, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ShadcnColors.surface,
                                foregroundColor: ShadcnColors.foreground,
                                side: const BorderSide(color: ShadcnColors.border),
                              ),
                              onPressed: () => _loadNovels(reset: true),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Повторить попытку'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _novels.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_stories_outlined, color: ShadcnColors.mutedForeground, size: 48),
                              const SizedBox(height: 12),
                              const Text(
                                'Ничего не найдено',
                                style: TextStyle(color: ShadcnColors.foreground, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Попробуйте изменить поисковый запрос или источник',
                                style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12),
                              ),
                              if (_searchCtrl.text.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                TextButton(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _loadNovels(reset: true);
                                  },
                                  child: const Text('Сбросить поиск', style: TextStyle(color: Color(0xFFE11D48))),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                          itemCount: _novels.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _novels.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: _isLoadingMore
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(color: Color(0xFFE11D48), strokeWidth: 2),
                                        )
                                      : ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: ShadcnColors.surface,
                                            foregroundColor: ShadcnColors.foreground,
                                            side: const BorderSide(color: ShadcnColors.border),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                          onPressed: _loadMore,
                                          child: const Text('Загрузить ещё', style: TextStyle(fontSize: 12)),
                                        ),
                                ),
                              );
                            }

                            final novel = _novels[index];
                            return _NovelCard(
                              novel: novel,
                              onTap: () => _showNovelChapters(novel),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

class _NovelCard extends StatelessWidget {
  final NovelBook novel;
  final VoidCallback onTap;

  const _NovelCard({required this.novel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ShadcnColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShadcnColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Обложка новеллы
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 58,
                  height: 82,
                  color: ShadcnColors.surface,
                  child: novel.coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: novel.coverUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.auto_stories,
                            color: Color(0xFFE11D48),
                            size: 28,
                          ),
                        )
                      : const Icon(
                          Icons.auto_stories,
                          color: Color(0xFFE11D48),
                          size: 28,
                        ),
                ),
              ),

              const SizedBox(width: 14),

              // Информация о новелле
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      novel.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ShadcnColors.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      novel.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Источник
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x22E11D48),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            novel.source,
                            style: const TextStyle(
                              color: Color(0xFFE11D48),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Количество глав
                        if (novel.totalChapters != null || novel.chapters.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ShadcnColors.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: ShadcnColors.border),
                            ),
                            child: Text(
                              '${novel.totalChapters ?? novel.chapters.length} глав',
                              style: const TextStyle(color: ShadcnColors.foreground, fontSize: 10),
                            ),
                          ),

                        // Рейтинг
                        if (novel.rating != null && novel.rating! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  novel.rating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ShadcnColors.surface,
                  foregroundColor: ShadcnColors.foreground,
                  elevation: 0,
                  side: const BorderSide(color: ShadcnColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onTap,
                child: const Text('Главы', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NovelChaptersModal extends StatefulWidget {
  final NovelBook book;
  final NovelRepository repo;

  const _NovelChaptersModal({required this.book, required this.repo});

  @override
  State<_NovelChaptersModal> createState() => _NovelChaptersModalState();
}

class _NovelChaptersModalState extends State<_NovelChaptersModal> {
  List<NovelChapter> _chapters = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    if (widget.book.chapters.isNotEmpty && widget.book.chapters.first.content.isNotEmpty) {
      setState(() {
        _chapters = widget.book.chapters;
        _isLoading = false;
      });
      return;
    }

    try {
      final chs = await widget.repo.getNovelChapters(widget.book);
      if (!mounted) return;
      setState(() {
        _chapters = chs;
        _isLoading = false;
        if (chs.isEmpty) {
          _error = 'Список глав пуст или пока недоступен.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Не удалось загрузить главы: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Color(0xFA121215),
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
              decoration: BoxDecoration(color: ShadcnColors.border, borderRadius: BorderRadius.circular(2)),
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
                      child: Container(
                        width: 70,
                        height: 98,
                        color: ShadcnColors.surface,
                        child: widget.book.coverUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.book.coverUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.auto_stories,
                                  color: Color(0xFFE11D48),
                                  size: 36,
                                ),
                              )
                            : const Icon(
                                Icons.auto_stories,
                                color: Color(0xFFE11D48),
                                size: 36,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book.title,
                            style: const TextStyle(
                              color: ShadcnColors.foreground,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.book.author,
                            style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0x22E11D48),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Ранобэ • ${_chapters.length} глав',
                                  style: const TextStyle(
                                    color: Color(0xFFE11D48),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (widget.book.description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Описание', style: TextStyle(color: ShadcnColors.foreground, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(widget.book.description, style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13, height: 1.4)),
                ],

                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Главы новеллы', style: TextStyle(color: ShadcnColors.foreground, fontWeight: FontWeight.w600, fontSize: 14)),
                    if (_chapters.isNotEmpty)
                      Text(
                        '${_chapters.length} доступно',
                        style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: Color(0xFFE11D48), strokeWidth: 2),
                          SizedBox(height: 12),
                          Text(
                            'Загрузка списка глав...',
                            style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Text(_error!, style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ShadcnColors.surface,
                              foregroundColor: ShadcnColors.foreground,
                              side: const BorderSide(color: ShadcnColors.border),
                            ),
                            onPressed: _loadChapters,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._chapters.map((ch) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: ShadcnColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ShadcnColors.border),
                        ),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            ch.title,
                            style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          subtitle: ch.volume != null
                              ? Text(
                                  ch.volume!,
                                  style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 11),
                                )
                              : null,
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: ShadcnColors.accent, size: 13),
                          onTap: () {
                            final nav = Navigator.of(context, rootNavigator: true);
                            Navigator.pop(context);
                            nav.push(
                              MaterialPageRoute(
                                builder: (_) => NovelReaderScreen(
                                  novelTitle: widget.book.title,
                                  chapter: ch,
                                  allChapters: _chapters,
                                  source: widget.book.source,
                                ),
                              ),
                            );
                          },
                        ),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
