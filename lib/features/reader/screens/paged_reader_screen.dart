import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/dcatcher_image.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../../../core/widgets/frosted_glass.dart';
import '../../catalog/models/manga.dart';
import '../models/chapter.dart';
import '../../sources/manga_source.dart';
import '../../sources/source_manager.dart';
import '../../library/state/library_provider.dart';
import '../../download/download_manager.dart';
import '../models/manga_reader_settings.dart';
import '../widgets/reader_settings_bottom_sheet.dart';
import 'webtoon_reader_screen.dart';
import '../services/reader_mode.dart';

import 'dart:async';

class PagedReaderScreen extends StatefulWidget {
  final Manga manga;
  final Chapter chapter;
  final MangaSource? source;
  final List<Chapter>? chapters;

  const PagedReaderScreen({
    super.key,
    required this.manga,
    required this.chapter,
    this.source,
    this.chapters,
  });

  @override
  State<PagedReaderScreen> createState() => _PagedReaderScreenState();
}

class _PagedReaderScreenState extends State<PagedReaderScreen> {
  MangaSource? _source;
  late Chapter _currentChapter;
  List<String> _pageUrls = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _showControls = true;
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final Set<int> _preloadedIndices = {};

  static Map<String, String> _getImageHeaders(String url) {
    if (url.contains('mangabuff.ru')) {
      return const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      };
    }
    if (url.contains('remanga.org')) {
      return const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      };
    }
    return const {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    };
  }

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;
    _source = widget.source ?? SourceManager.getSourceById(
      widget.manga.sourceId,
    );
    _loadPages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateProgress();
    });
  }

  void _updateProgress() {
    if (!mounted) return;
    final library = context.read<LibraryProvider>();
    library.updateProgress(
      mangaId: widget.manga.id,
      sourceId: widget.manga.sourceId,
      chapterId: _currentChapter.id,
      chapterNumber: _currentChapter.chapterNumber,
      title: widget.manga.title,
      coverUrl: widget.manga.coverUrl,
    );
  }

  void _preloadAdjacentPages(int currentIndex) {
    if (!mounted || _pageUrls.isEmpty) return;
    // Extension source images must pass through native bridge interceptors
    // and not leak directly via CachedNetworkImage HTTP prefetch
    if (DcatcherImage.isExtensionSourceId(widget.manga.sourceId)) return;

    for (int offset in [-1, 1, 2, 3]) {
      final target = currentIndex + offset;
      if (target >= 0 && target < _pageUrls.length && !_preloadedIndices.contains(target)) {
        _preloadedIndices.add(target);
        final url = _pageUrls[target];
        if (url.startsWith('http')) {
          precacheImage(
            CachedNetworkImageProvider(url, headers: _getImageHeaders(url)),
            context,
          ).catchError((_) {});
        }
      }
    }
  }

  Future<void> _loadPages() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // 1. Check offline downloaded pages first
      final offlinePages = await DownloadManager().getOfflinePages(_currentChapter.id);
      if (offlinePages != null && offlinePages.isNotEmpty) {
        if (mounted) {
          setState(() {
            _pageUrls = offlinePages;
            _isLoading = false;
            _hasError = false;
          });
        }
        return;
      }

      // 2. Otherwise load via source
      final source = _source ?? SourceManager.getSourceById(widget.manga.sourceId);
      if (source == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Источник (${widget.manga.sourceId}) не найден или не установлен';
          });
        }
        return;
      }

      final pages = await source.getChapterPages(_currentChapter.id).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Превышено время ожидания ответа от источника (15 сек)'),
      );

      if (mounted) {
        if (pages.isEmpty) {
          setState(() {
            _pageUrls = [];
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Страницы не найдены. Возможно, глава пуста или защищена платным доступом.';
          });
        } else {
          setState(() {
            _pageUrls = pages;
            _isLoading = false;
            _hasError = false;
            _errorMessage = null;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _preloadAdjacentPages(0);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _switchChapter(Chapter newChapter) {
    setState(() {
      _currentChapter = newChapter;
      _pageUrls = [];
      _currentIndex = 0;
      _preloadedIndices.clear();
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _loadPages();
    _updateProgress();
  }

  void _openSettings() {
    final settings = MangaReaderSettings.of(context, listen: false);
    ReaderSettingsBottomSheet.show(
      context: context,
      settings: settings,
      currentIndex: _currentIndex,
      totalPages: _pageUrls.length,
      onPageSelected: (page) {
        if (_pageController.hasClients && page >= 0 && page < _pageUrls.length) {
          _pageController.jumpToPage(page);
          setState(() => _currentIndex = page);
        }
      },
      onReadingModeChanged: (mode) {
        if (mode == MangaReadingMode.webtoon) {
          ReaderModeResolver.savePreference(
            mangaId: widget.manga.id,
            sourceId: widget.manga.sourceId,
            mode: ReaderMode.webtoon,
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => WebtoonReaderScreen(
                manga: widget.manga,
                chapter: _currentChapter,
                source: _source,
                chapters: widget.chapters,
              ),
            ),
          );
        }
      },
      currentChapter: _currentChapter,
      chapters: widget.chapters,
      onChapterSelected: (newChapter) {
        _switchChapter(newChapter);
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = MangaReaderSettings.of(context, listen: true);
    final isRtl = settings.readingMode == MangaReadingMode.pagedRtl;
    final isVertical = settings.readingMode == MangaReadingMode.pagedVertical;

    return Scaffold(
      backgroundColor: settings.theme.backgroundColor,
      body: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (_hasError || _pageUrls.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _pageUrls.isEmpty && (_errorMessage?.contains('не найдены') ?? false)
                          ? Icons.menu_book
                          : Icons.error_outline_rounded,
                      size: 48,
                      color: _pageUrls.isEmpty && (_errorMessage?.contains('не найдены') ?? false)
                          ? ShadcnColors.mutedForeground
                          : ShadcnColors.exclude,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _pageUrls.isEmpty && (_errorMessage?.contains('не найдены') ?? false)
                          ? 'Страницы не найдены'
                          : 'Ошибка загрузки страниц',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ShadcnColors.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'Не удалось получить страницы главы.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ShadcnColors.mutedForeground,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ShadcnColors.primary,
                        foregroundColor: ShadcnColors.primaryForeground,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _loadPages,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Повторить попытку'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: ShadcnColors.mutedForeground,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Назад к списку глав'),
                    ),
                  ],
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: PageView.builder(
                controller: _pageController,
                reverse: isRtl,
                scrollDirection: isVertical ? Axis.vertical : Axis.horizontal,
                itemCount: _pageUrls.length,
                onPageChanged: (i) {
                  setState(() => _currentIndex = i);
                  _preloadAdjacentPages(i);
                },
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: settings.pageSpacing,
                          horizontal: isVertical ? settings.pageSpacing : 0,
                        ),
                        child: DcatcherImage(
                          sourceId: widget.manga.sourceId,
                          imageUrl: _pageUrls[index],
                          headers: _getImageHeaders(_pageUrls[index]),
                          fit: settings.imageFit.boxFit,
                          memCacheWidth: 1080,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ShadcnColors.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          errorRetryWidget: (context, url, err, retry) => Center(
                            child: InkWell(
                              onTap: retry,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                decoration: BoxDecoration(
                                  color: ShadcnColors.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: ShadcnColors.border),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.refresh_rounded, color: ShadcnColors.primary, size: 36),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Ошибка загрузки стр. ${index + 1}',
                                      style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Нажмите, чтобы повторить',
                                      style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 11),
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
                },
              ),
            ),

          // Ненавязчивый бейдж с номером страницы в углу при скрытых панелях управления
          if (!_showControls && settings.showPageNumberOverlay && !_hasError && _pageUrls.isNotEmpty)
            Positioned(
              bottom: 16,
              right: 16,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${_pageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

          // Верхний аппбар
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutCubic,
            top: (_showControls || _hasError || _pageUrls.isEmpty) ? 0 : -90,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: FrostedGlass(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: ShadcnColors.foreground),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.manga.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ShadcnColors.foreground,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _currentChapter.displayName,
                              style: const TextStyle(
                                color: ShadcnColors.mutedForeground,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Нижняя панель с номерами страниц и кнопкой настроек
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutCubic,
            bottom: (_showControls && !_hasError && _pageUrls.isNotEmpty) ? 0 : -90,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: FrostedGlass(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _pageUrls.isEmpty
                            ? ''
                            : 'Страница ${_currentIndex + 1} из ${_pageUrls.length}',
                        style: const TextStyle(
                          color: ShadcnColors.foreground,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: ShadcnColors.foreground),
                        tooltip: 'Настройки читалки',
                        onPressed: _openSettings,
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
  }
}
