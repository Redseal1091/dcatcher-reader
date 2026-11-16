import 'dart:async';
import 'dart:io';
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
import '../../library/models/library_item.dart';
import '../../download/download_manager.dart';
import '../models/manga_reader_settings.dart';
import '../widgets/reader_settings_bottom_sheet.dart';
import 'paged_reader_screen.dart';
import '../services/reader_mode.dart';

class WebtoonReaderScreen extends StatefulWidget {
  final Manga manga;
  final Chapter chapter;
  final MangaSource? source;
  final List<Chapter>? chapters;

  const WebtoonReaderScreen({
    super.key,
    required this.manga,
    required this.chapter,
    this.source,
    this.chapters,
  });

  @override
  State<WebtoonReaderScreen> createState() => _WebtoonReaderScreenState();
}

class _WebtoonReaderScreenState extends State<WebtoonReaderScreen> {
  MangaSource? _source;
  late Chapter _currentChapter;
  List<String> _pageUrls = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _showControls = true;
  bool _isOffline = false;
  int _approxCurrentIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final Set<int> _preloadedIndices = {};

  // Автоскролл
  Timer? _autoScrollTimer;
  double _autoScrollSpeed = 0.0; // 0 = выключен, 1.0, 1.5, 2.0

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
    _scrollController.addListener(_onScroll);

    // Автоматически фиксируем главу и статус чтения
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

  void _onScroll() {
    if (!_scrollController.hasClients || _pageUrls.isEmpty) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final progress = (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
    final approx = (progress * _pageUrls.length).floor().clamp(0, _pageUrls.isEmpty ? 0 : _pageUrls.length - 1);
    if (approx != _approxCurrentIndex) {
      setState(() => _approxCurrentIndex = approx);
    }

    // Заблаговременно предзагружаем следующие 6 изображений в фоне
    _preloadUpcomingImages(approx, 6);
  }

  void _switchChapter(Chapter newChapter) {
    if (_autoScrollSpeed > 0) {
      _stopAutoScroll();
    }
    setState(() {
      _currentChapter = newChapter;
      _pageUrls = [];
      _approxCurrentIndex = 0;
      _preloadedIndices.clear();
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _loadPages();
    _updateProgress();
  }

  void _openSettings() {
    final settings = MangaReaderSettings.of(context, listen: false);
    ReaderSettingsBottomSheet.show(
      context: context,
      settings: settings,
      currentIndex: _approxCurrentIndex,
      totalPages: _pageUrls.length,
      onPageSelected: (page) {
        if (!_scrollController.hasClients || _pageUrls.isEmpty) return;
        final maxScroll = _scrollController.position.maxScrollExtent;
        final targetOffset = (page / _pageUrls.length) * maxScroll;
        _scrollController.jumpTo(targetOffset);
        setState(() => _approxCurrentIndex = page);
      },
      onReadingModeChanged: (mode) {
        if (mode != MangaReadingMode.webtoon) {
          ReaderModeResolver.savePreference(
            mangaId: widget.manga.id,
            sourceId: widget.manga.sourceId,
            mode: ReaderMode.paged,
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PagedReaderScreen(
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

  void _preloadUpcomingImages(int startIndex, int count) {
    if (!mounted || _isOffline) return;
    // Extension source images must pass through native bridge interceptors
    // and not leak directly via CachedNetworkImage HTTP prefetch
    if (DcatcherImage.isExtensionSourceId(widget.manga.sourceId)) return;

    for (int i = startIndex; i < startIndex + count && i < _pageUrls.length; i++) {
      if (i < 0 || _preloadedIndices.contains(i)) continue;
      _preloadedIndices.add(i);
      final url = _pageUrls[i];
      if (!url.startsWith('http')) continue;

      precacheImage(
        CachedNetworkImageProvider(url, headers: _getImageHeaders(url)),
        context,
      ).catchError((_) {});
    }
  }

  Future<void> _loadPages() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // 1. Проверяем, скачана ли глава офлайн в память телефона
      final offlinePages = await DownloadManager().getOfflinePages(_currentChapter.id);
      if (offlinePages != null && offlinePages.isNotEmpty) {
        if (mounted) {
          setState(() {
            _pageUrls = offlinePages;
            _isOffline = true;
            _isLoading = false;
            _hasError = false;
          });
        }
        return;
      }

      // 2. Иначе грузим из сети
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
            _isOffline = false;
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Страницы не найдены. Возможно, глава пуста или защищена платным доступом.';
          });
        } else {
          setState(() {
            _pageUrls = pages;
            _isOffline = false;
            _isLoading = false;
            _hasError = false;
            _errorMessage = null;
          });

          // Мгновенно запускаем упреждающую предзагрузку первых 5 страниц
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _preloadUpcomingImages(0, 5);
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

  void _toggleAutoScroll() {
    if (_autoScrollSpeed > 0) {
      _stopAutoScroll();
    } else {
      _startAutoScroll(1.0);
    }
  }

  void _startAutoScroll(double speed) {
    _autoScrollTimer?.cancel();
    setState(() {
      _autoScrollSpeed = speed;
      _showControls = false;
    });

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      final current = _scrollController.offset;
      if (current >= max) {
        _stopAutoScroll();
        return;
      }
      _scrollController.jumpTo(current + (speed * 1.8));
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    if (mounted) {
      setState(() {
        _autoScrollSpeed = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = MangaReaderSettings.of(context, listen: true);

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
                padding: const EdgeInsets.all(32),
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
                      style: const TextStyle(color: ShadcnColors.foreground, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'Возможно, глава защищена платным доступом на сайте источника.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
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
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_autoScrollSpeed > 0) {
                  _stopAutoScroll();
                } else {
                  setState(() => _showControls = !_showControls);
                }
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                itemCount: _pageUrls.length,
                cacheExtent: 3500, // Увеличенный кэш-буфер для плавного скролла без дерганий
                itemBuilder: (context, index) {
                  final path = _pageUrls[index];

                  return Padding(
                    padding: EdgeInsets.only(bottom: settings.pageSpacing),
                    child: _WebtoonZoomablePage(
                      sourceId: widget.manga.sourceId,
                      path: path,
                      index: index,
                      isOffline: _isOffline,
                      headers: _getImageHeaders(path),
                      fit: settings.imageFit.boxFit,
                      onTap: () {
                        if (_autoScrollSpeed > 0) {
                          _stopAutoScroll();
                        } else {
                          setState(() => _showControls = !_showControls);
                        }
                      },
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
                    '${_approxCurrentIndex + 1} / ${_pageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

          // Верхняя матовая навигация
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            top: (_showControls || _hasError || _pageUrls.isEmpty) ? 0 : -100,
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
                        icon: const Icon(Icons.arrow_back, color: ShadcnColors.foreground, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.manga.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: ShadcnColors.foreground,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (_isOffline) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'ОФЛАЙН',
                                      style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
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
                      // Кнопка автоскролла
                      IconButton(
                        icon: Icon(
                          _autoScrollSpeed > 0 ? Icons.speed : Icons.play_circle_outline,
                          color: _autoScrollSpeed > 0 ? ShadcnColors.accent : ShadcnColors.foreground,
                          size: 22,
                        ),
                        tooltip: 'Автоскролл',
                        onPressed: _toggleAutoScroll,
                      ),
                      // Кнопка настроек читалки
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: ShadcnColors.foreground, size: 22),
                        tooltip: 'Настройки читалки',
                        onPressed: _openSettings,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Плавающий бейдж активного автоскролла
          if (_autoScrollSpeed > 0)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: FrostedGlass(
                  borderRadius: BorderRadius.circular(20),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  backgroundColor: const Color(0xE0121215),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.motion_photos_on_outlined, size: 14, color: ShadcnColors.accent),
                      const SizedBox(width: 8),
                      Text(
                        'Автоскролл: ${_autoScrollSpeed}x',
                        style: const TextStyle(color: ShadcnColors.foreground, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          if (_autoScrollSpeed == 1.0) {
                            _startAutoScroll(1.5);
                          } else if (_autoScrollSpeed == 1.5) {
                            _startAutoScroll(2.0);
                          } else {
                            _startAutoScroll(1.0);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ShadcnColors.card,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: ShadcnColors.border),
                          ),
                          child: const Text('СКОРОСТЬ', style: TextStyle(color: ShadcnColors.foreground, fontSize: 10)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _stopAutoScroll,
                        child: const Icon(Icons.close, size: 16, color: ShadcnColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Нижняя плавающая матовая плашка управления
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            bottom: (_showControls && !_hasError && _pageUrls.isNotEmpty) ? 20 : -90,
            left: 20,
            right: 20,
            child: SafeArea(
              child: FrostedGlass(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_stories_outlined, size: 16, color: ShadcnColors.mutedForeground),
                        const SizedBox(width: 6),
                        Text(
                          '${_pageUrls.length} стр.',
                          style: const TextStyle(
                            color: ShadcnColors.mutedForeground,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Consumer<LibraryProvider>(
                          builder: (context, library, _) {
                            final isCompleted = library.getStatus(widget.manga.id) == UserMangaStatus.completed;
                            return TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: Icon(
                                isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                                size: 16,
                                color: isCompleted ? ShadcnColors.completed : ShadcnColors.foreground,
                              ),
                              label: Text(
                                isCompleted ? 'Прочитано' : 'Отметить',
                                style: TextStyle(
                                  color: isCompleted ? ShadcnColors.completed : ShadcnColors.foreground,
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: () {
                                library.setStatus(
                                  widget.manga.id,
                                  isCompleted ? UserMangaStatus.reading : UserMangaStatus.completed,
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.settings_outlined, color: ShadcnColors.foreground, size: 20),
                          tooltip: 'Настройки читалки',
                          onPressed: _openSettings,
                        ),
                      ],
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
}

/// Виджет полотна страницы вебтуна с поддержкой увеличения пальцами (Pinch-to-zoom)
/// и двойного нажатия (Double-tap zoom)
class _WebtoonZoomablePage extends StatefulWidget {
  final String path;
  final int index;
  final bool isOffline;
  final Map<String, String> headers;
  final String? sourceId;
  final BoxFit fit;
  final VoidCallback onTap;

  const _WebtoonZoomablePage({
    required this.path,
    required this.index,
    required this.isOffline,
    required this.headers,
    this.sourceId,
    this.fit = BoxFit.fitWidth,
    required this.onTap,
  });

  @override
  State<_WebtoonZoomablePage> createState() => _WebtoonZoomablePageState();
}

class _WebtoonZoomablePageState extends State<_WebtoonZoomablePage> with SingleTickerProviderStateMixin {
  final TransformationController _transformController = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _zoomAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformController.value = _zoomAnimation!.value;
        }
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final currentScale = _transformController.value.getMaxScaleOnAxis();

    if (currentScale > 1.05) {
      // Возвращаем в нормальный масштаб
      _zoomAnimation = Matrix4Tween(
        begin: _transformController.value,
        end: Matrix4.identity(),
      ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
      _animationController.forward(from: 0);
    } else {
      // Увеличиваем в точку двойного клика
      final position = details.localPosition;
      final target = Matrix4.identity()
        ..translate(-position.dx * 1.2, -position.dy * 1.2)
        ..scale(2.2);

      _zoomAnimation = Matrix4Tween(
        begin: _transformController.value,
        end: target,
      ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
      _animationController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTap,
      onDoubleTap: () {},
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 1.0,
        maxScale: 4.5,
        clipBehavior: Clip.none,
        panEnabled: true,
        scaleEnabled: true,
        child: widget.isOffline
            ? Image.file(
                File(widget.path),
                fit: widget.fit,
              )
            : DcatcherImage(
                sourceId: widget.sourceId,
                imageUrl: widget.path,
                headers: widget.headers,
                fit: widget.fit,
                memCacheWidth: 1080,

                placeholder: (context, url) => Container(
                  height: 400,
                  color: const Color(0xFF101014),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ShadcnColors.primary.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Стр. ${widget.index + 1}',
                          style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                errorRetryWidget: (context, url, err, retry) => Container(
                  height: 220,
                  color: const Color(0xFF18181B),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.refresh_rounded, color: ShadcnColors.primary, size: 30),
                        const SizedBox(height: 8),
                        Text(
                          'Стр. ${widget.index + 1} не загрузилась',
                          style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ShadcnColors.primary,
                            foregroundColor: ShadcnColors.primaryForeground,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          onPressed: retry,
                          icon: const Icon(Icons.replay_rounded, size: 16),
                          label: const Text('Повторить загрузку'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
