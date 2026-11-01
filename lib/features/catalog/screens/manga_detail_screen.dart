import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../../../core/widgets/shadcn_badge.dart';
import '../models/manga.dart';
import '../../library/state/library_provider.dart';
import '../../library/models/library_item.dart';
import '../../reader/models/chapter.dart';
import '../../reader/screens/webtoon_reader_screen.dart';
import '../../reader/screens/paged_reader_screen.dart';
import '../../sources/manga_source.dart';
import '../../sources/source_manager.dart';
import '../../download/download_manager.dart';
import '../../novel_reader/screens/widgets/novel_chooser_sheet.dart';
import '../../novel_reader/services/novel_repository.dart';

class MangaDetailScreen extends StatefulWidget {
  final Manga manga;

  const MangaDetailScreen({super.key, required this.manga});

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  MangaSource get _source {
    if (widget.manga.sourceId.isNotEmpty) {
      return SourceManager.getSourceById(widget.manga.sourceId);
    }
    return SourceManager.currentSource;
  }
  final ScrollController _scrollController = ScrollController();
  List<Chapter> _chapters = [];
  bool _isLoadingChapters = true;
  String? _description;
  NovelBook? _originalNovel;

  @override
  void initState() {
    super.initState();
    _loadChapters();
    _checkNovelOriginal();
  }

  Future<void> _checkNovelOriginal() async {
    final book = await NovelRepository().findNovelForManga(widget.manga.id, widget.manga.title);
    if (mounted) {
      setState(() => _originalNovel = book);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChapters() async {
    final list = await _source.getChapters(widget.manga.id);
    final desc = await _source.getDescription(widget.manga.id);
    if (mounted) {
      setState(() {
        _chapters = list;
        if (desc.isNotEmpty) _description = desc;
        _isLoadingChapters = false;
      });
    }
  }

  void _openReader(Chapter chapter) {
    final isWebtoon = widget.manga.type == PublicationType.manhwa ||
        widget.manga.type == PublicationType.manhua;

    if (isWebtoon) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WebtoonReaderScreen(
            manga: widget.manga,
            chapter: chapter,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PagedReaderScreen(
            manga: widget.manga,
            chapter: chapter,
          ),
        ),
      );
    }
  }

  void _openInitialOrResumeChapter(LibraryItem? item) {
    if (_chapters.isEmpty) return;

    Chapter? target;
    if (item != null && item.lastChapterId.isNotEmpty) {
      // Ищем главу, на которой остановились
      target = _chapters.firstWhere(
        (c) => c.id == item.lastChapterId,
        orElse: () => _chapters.first,
      );
    } else {
      // Ищем первую бесплатную главу
      target = _chapters.firstWhere((c) => !c.isPaid, orElse: () => _chapters.first);
    }

    _openReader(target);
  }

  void _openNovel() {
    NovelChooserSheet.show(
      context,
      mangaId: widget.manga.id,
      mangaTitle: widget.manga.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final currentStatus = library.getStatus(widget.manga.id);
    final libraryItem = library.getItem(widget.manga.id);
    final isBlacklisted = library.isBlacklisted(widget.manga.id);

    final hasProgress = libraryItem != null && libraryItem.lastChapterNumber.isNotEmpty;
    final progressChapterNum = libraryItem?.lastChapterNumber ?? '';

    return Scaffold(
      backgroundColor: ShadcnColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        // Исключаем смазывание и дублирование текста на Android при оверскролле
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        slivers: [
          // Шапка с обложкой и кнопкой назад (чистый GPU-рендеринг без шлейфа)
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xDD18181B),
                  shape: BoxShape.circle,
                  border: Border.all(color: ShadcnColors.border),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: ShadcnColors.foreground, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.manga.coverUrl,
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          ShadcnColors.background.withValues(alpha: 0.9),
                          ShadcnColors.background,
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Контентная часть
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Название
                    Text(
                      widget.manga.title,
                      style: const TextStyle(
                        color: ShadcnColors.foreground,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (widget.manga.altTitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.manga.altTitle!,
                        style: const TextStyle(
                          color: ShadcnColors.mutedForeground,
                          fontSize: 13,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Бейджи: тип, возраст, рейтинг, лицензия
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ShadcnBadge(
                          label: widget.manga.typeLabel,
                          variant: BadgeVariant.secondary,
                        ),
                        if (widget.manga.isLicensed)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0x33EF4444),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0x88EF4444)),
                            ),
                            child: const Text(
                              'Лицензировано в РФ',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ShadcnBadge(
                          label: widget.manga.statusLabel,
                          variant: BadgeVariant.outline,
                        ),
                        ShadcnBadge(
                          label: '${widget.manga.totalChapters > 0 ? widget.manga.totalChapters : _chapters.length} глав',
                          variant: BadgeVariant.secondary,
                        ),
                        ShadcnBadge(
                          label: widget.manga.ratingLabel,
                          variant: BadgeVariant.rating,
                        ),
                        ShadcnBadge(
                          label: '★ ${widget.manga.ratingScore}',
                          variant: BadgeVariant.outline,
                        ),
                        if (hasProgress)
                          ShadcnBadge(
                            label: 'Вы читали: Гл. $progressChapterNum',
                            variant: BadgeVariant.reading,
                            icon: Icons.history,
                          ),
                        // Компактная кнопка оригинала ранобэ (ТОЛЬКО если есть оригинал)
                        if (_originalNovel != null)
                          InkWell(
                            onTap: _openNovel,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0x22E11D48),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE11D48)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_stories, color: Color(0xFFE11D48), size: 13),
                                  SizedBox(width: 4),
                                  Text(
                                    'Ранобэ-оригинал',
                                    style: TextStyle(
                                      color: Color(0xFFE11D48),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Статусы в библиотеке (Читаю / Прочитано / В планах)
                    _buildStatusSelector(currentStatus, library, isBlacklisted),

                    const SizedBox(height: 20),

                    // Описание
                    const Text(
                      'Описание',
                      style: TextStyle(
                        color: ShadcnColors.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _description ?? widget.manga.description,
                      style: const TextStyle(
                        color: ShadcnColors.mutedForeground,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Заголовок списка глав
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Главы',
                          style: TextStyle(
                            color: ShadcnColors.foreground,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${_chapters.length} глав',
                          style: const TextStyle(
                            color: ShadcnColors.mutedForeground,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),

          // Список глав с крупными, удобными кнопками
          if (_isLoadingChapters)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: ShadcnColors.primary),
                ),
              ),
            )
          else if (_chapters.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.menu_book, color: ShadcnColors.mutedForeground, size: 36),
                      const SizedBox(height: 12),
                      Text(
                        widget.manga.isLicensed
                            ? 'Главы временно недоступны из-за лицензии правообладателя.'
                            : 'Для этого произведения пока нет доступных глав.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), // Отступ для плавающей кнопки
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final chapter = _chapters[index];
                    final isCurrentLastRead = hasProgress && chapter.id == libraryItem.lastChapterId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isCurrentLastRead ? const Color(0x22F59E0B) : ShadcnColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrentLastRead ? ShadcnColors.reading : ShadcnColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Информация о главе (кликабельна для быстрого перехода)
                          Expanded(
                            child: InkWell(
                              onTap: () => _openReader(chapter),
                              borderRadius: BorderRadius.circular(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (isCurrentLastRead) ...[
                                        const Icon(Icons.bookmark, color: ShadcnColors.reading, size: 18),
                                        const SizedBox(width: 6),
                                      ],
                                      Expanded(
                                        child: Text(
                                          chapter.displayName,
                                          style: TextStyle(
                                            color: isCurrentLastRead ? ShadcnColors.reading : ShadcnColors.foreground,
                                            fontSize: 15,
                                            fontWeight: isCurrentLastRead ? FontWeight.w700 : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    chapter.scanlationGroup,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: ShadcnColors.mutedForeground,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Крупная кнопка "Скачать" (42x42)
                          if (!chapter.isPaid) ...[
                            _buildDownloadButton(chapter),
                            const SizedBox(width: 8),
                          ],

                          // Крупная кнопка "Открыть" / "Платная"
                          chapter.isPaid
                              ? Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0x22F59E0B),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0x66F59E0B)),
                                  ),
                                  child: const Center(
                                    child: Row(
                                      children: [
                                        Icon(Icons.lock_outline, color: ShadcnColors.reading, size: 18),
                                        SizedBox(width: 4),
                                        Text('Платная', style: TextStyle(color: ShadcnColors.reading, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                )
                              : Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _openReader(chapter),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      height: 42,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isCurrentLastRead ? ShadcnColors.reading : ShadcnColors.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Row(
                                          children: [
                                            Text(
                                              'Читать',
                                              style: TextStyle(
                                                color: isCurrentLastRead ? Colors.black : ShadcnColors.primaryForeground,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.play_arrow_rounded,
                                              color: isCurrentLastRead ? Colors.black : ShadcnColors.primaryForeground,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    );
                  },
                  childCount: _chapters.length,
                ),
              ),
            ),
        ],
      ),

      // Плавающая кнопка внизу к первой главе / продолжению чтения
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isLoadingChapters || _chapters.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xF2121215),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: ShadcnColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ShadcnColors.primary,
                        foregroundColor: ShadcnColors.primaryForeground,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: Text(
                        hasProgress
                            ? 'Продолжить: Гл. $progressChapterNum'
                            : 'Читать с 1 главы',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      onPressed: () => _openInitialOrResumeChapter(libraryItem),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: ShadcnColors.foreground),
                      tooltip: 'Вниз к первой главе',
                      onPressed: () {
                        _scrollController.animateTo(
                          480,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusSelector(UserMangaStatus? currentStatus, LibraryProvider library, bool isBlacklisted) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShadcnColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShadcnColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Статус в моей библиотеке',
            style: TextStyle(
              color: ShadcnColors.mutedForeground,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatusBtn(
                  label: 'Читаю',
                  isActive: currentStatus == UserMangaStatus.reading,
                  color: ShadcnColors.reading,
                  onTap: () => library.setStatus(
                    widget.manga.id,
                    currentStatus == UserMangaStatus.reading ? null : UserMangaStatus.reading,
                    title: widget.manga.title,
                    coverUrl: widget.manga.coverUrl,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusBtn(
                  label: 'Прочитано',
                  isActive: currentStatus == UserMangaStatus.completed,
                  color: ShadcnColors.completed,
                  onTap: () => library.setStatus(
                    widget.manga.id,
                    currentStatus == UserMangaStatus.completed ? null : UserMangaStatus.completed,
                    title: widget.manga.title,
                    coverUrl: widget.manga.coverUrl,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusBtn(
                  label: 'В планах',
                  isActive: currentStatus == UserMangaStatus.planned,
                  color: ShadcnColors.planned,
                  onTap: () => library.setStatus(
                    widget.manga.id,
                    currentStatus == UserMangaStatus.planned ? null : UserMangaStatus.planned,
                    title: widget.manga.title,
                    coverUrl: widget.manga.coverUrl,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: ShadcnColors.border),
          const SizedBox(height: 8),

          // Кнопка "Не показывать" (Черный список)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                library.toggleBlacklist(
                  widget.manga.id,
                  title: widget.manga.title,
                  coverUrl: widget.manga.coverUrl,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isBlacklisted
                          ? 'Тайтл убран из черного списка и снова доступен в каталоге.'
                          : 'Тайтл скрыт и отправлен в черный список.',
                    ),
                    backgroundColor: ShadcnColors.surface,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isBlacklisted ? const Color(0x33EF4444) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isBlacklisted ? const Color(0xFFEF4444) : ShadcnColors.border,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isBlacklisted ? Icons.block : Icons.visibility_off_outlined,
                      size: 16,
                      color: isBlacklisted ? const Color(0xFFEF4444) : ShadcnColors.mutedForeground,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isBlacklisted ? 'В черном списке (скрыто из каталога)' : 'Не показывать (в черный список)',
                      style: TextStyle(
                        color: isBlacklisted ? const Color(0xFFEF4444) : ShadcnColors.mutedForeground,
                        fontSize: 12,
                        fontWeight: isBlacklisted ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBtn({
    required String label,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? color : ShadcnColors.border,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? color : ShadcnColors.foreground,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Крупная кнопка скачивания (42x42px)
  Widget _buildDownloadButton(Chapter chapter) {
    final dm = DownloadManager();
    return ListenableBuilder(
      listenable: dm,
      builder: (context, _) {
        final isDownloading = dm.isDownloading(chapter.id);
        final isDownloaded = dm.isDownloaded(chapter.id);

        if (isDownloading) {
          final progress = dm.getProgress(chapter.id);
          return Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ShadcnColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ShadcnColors.border),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 2.5,
                  color: ShadcnColors.accent,
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(fontSize: 9, color: ShadcnColors.foreground, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        if (isDownloaded) {
          return InkWell(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: ShadcnColors.card,
                  title: const Text('Удалить главу?', style: TextStyle(color: ShadcnColors.foreground, fontSize: 16)),
                  content: Text(
                    'Удалить скачанные страницы главы ${chapter.chapterNumber} из памяти телефона?',
                    style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Отмена'),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                    TextButton(
                      child: const Text('Удалить', style: TextStyle(color: ShadcnColors.exclude)),
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await dm.deleteDownloadedChapter(chapter.id);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0x2210B981),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: const Icon(Icons.download_done_rounded, color: Color(0xFF10B981), size: 22),
            ),
          );
        }

        return InkWell(
          onTap: () {
            dm.downloadChapter(
              chapterId: chapter.id,
              mangaId: widget.manga.id,
              mangaTitle: widget.manga.title,
              chapterNumber: chapter.chapterNumber,
              coverUrl: widget.manga.coverUrl,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Скачивание главы ${chapter.chapterNumber} началось...'),
                backgroundColor: ShadcnColors.surface,
                duration: const Duration(seconds: 1),
              ),
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ShadcnColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ShadcnColors.border),
            ),
            child: const Icon(Icons.download_for_offline_outlined, color: ShadcnColors.foreground, size: 22),
          ),
        );
      },
    );
  }
}
