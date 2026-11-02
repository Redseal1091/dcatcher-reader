import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

class WebtoonReaderScreen extends StatefulWidget {
  final Manga manga;
  final Chapter chapter;

  const WebtoonReaderScreen({
    super.key,
    required this.manga,
    required this.chapter,
  });

  @override
  State<WebtoonReaderScreen> createState() => _WebtoonReaderScreenState();
}

class _WebtoonReaderScreenState extends State<WebtoonReaderScreen> {
  late final MangaSource _source;
  List<String> _pageUrls = [];
  bool _isLoading = true;
  bool _showControls = true;
  bool _isOffline = false;
  final ScrollController _scrollController = ScrollController();
  final Set<int> _preloadedIndices = {};

  // Автоскролл
  Timer? _autoScrollTimer;
  double _autoScrollSpeed = 0.0; // 0 = выключен, 1.0, 1.5, 2.0

  static Map<String, String> _getImageHeaders(String url) {
    if (url.contains('mangabuff.ru')) {
      return const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://mangabuff.ru/',
        'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      };
    }
    if (url.contains('remanga.org')) {
      return const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://remanga.org/',
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
    _source = SourceManager.getSourceById(
      widget.manga.sourceId.isNotEmpty ? widget.manga.sourceId : 'mangadex',
    );
    _loadPages();
    _scrollController.addListener(_onScroll);

    // Автоматически фиксируем главу и статус чтения
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final library = context.read<LibraryProvider>();
      library.updateProgress(
        mangaId: widget.manga.id,
        chapterId: widget.chapter.id,
        chapterNumber: widget.chapter.chapterNumber,
        title: widget.manga.title,
        coverUrl: widget.manga.coverUrl,
      );
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _pageUrls.isEmpty) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final progress = (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
    final approxCurrentIndex = (progress * _pageUrls.length).floor();

    // Заблаговременно предзагружаем следующие 6 изображений в фоне
    _preloadUpcomingImages(approxCurrentIndex, 6);
  }

  void _preloadUpcomingImages(int startIndex, int count) {
    if (!mounted || _isOffline) return;
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
    // 1. Проверяем, скачана ли глава офлайн в память телефона
    final offlinePages = await DownloadManager().getOfflinePages(widget.chapter.id);
    if (offlinePages != null && offlinePages.isNotEmpty) {
      if (mounted) {
        setState(() {
          _pageUrls = offlinePages;
          _isOffline = true;
          _isLoading = false;
        });
      }
      return;
    }

    // 2. Иначе грузим из сети
    final pages = await _source.getChapterPages(widget.chapter.id);
    if (mounted) {
      setState(() {
        _pageUrls = pages;
        _isOffline = false;
        _isLoading = false;
      });

      // Мгновенно запускаем упреждающую предзагрузку первых 5 страниц
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _preloadUpcomingImages(0, 5);
      });
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (_pageUrls.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.menu_book, size: 48, color: ShadcnColors.mutedForeground),
                    const SizedBox(height: 16),
                    const Text(
                      'Страницы не найдены',
                      style: TextStyle(color: ShadcnColors.foreground, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Возможно, глава защищена платным доступом на сайте источника.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ShadcnColors.primary,
                        foregroundColor: ShadcnColors.primaryForeground,
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

                  return _WebtoonZoomablePage(
                    path: path,
                    index: index,
                    isOffline: _isOffline,
                    headers: _getImageHeaders(path),
                    onTap: () {
                      if (_autoScrollSpeed > 0) {
                        _stopAutoScroll();
                      } else {
                        setState(() => _showControls = !_showControls);
                      }
                    },
                  );
                },
              ),
            ),

          // Верхняя матовая навигация
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            top: _showControls ? 0 : -100,
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
                              widget.chapter.displayName,
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
            bottom: _showControls ? 20 : -90,
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
                      children: [
                        const Icon(Icons.zoom_in, size: 16, color: ShadcnColors.mutedForeground),
                        const SizedBox(width: 4),
                        const Text(
                          'Увеличение пальцами',
                          style: TextStyle(
                            color: ShadcnColors.mutedForeground,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•  ${_pageUrls.length} стр.',
                          style: const TextStyle(
                            color: ShadcnColors.mutedForeground,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Consumer<LibraryProvider>(
                      builder: (context, library, _) {
                        final isCompleted = library.getStatus(widget.manga.id) == UserMangaStatus.completed;
                        return TextButton.icon(
                          icon: Icon(
                            isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                            size: 16,
                            color: isCompleted ? ShadcnColors.completed : ShadcnColors.foreground,
                          ),
                          label: Text(
                            isCompleted ? 'Прочитано' : 'Отметить прочитанным',
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
  final VoidCallback onTap;

  const _WebtoonZoomablePage({
    required this.path,
    required this.index,
    required this.isOffline,
    required this.headers,
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
                fit: BoxFit.fitWidth,
              )
            : CachedNetworkImage(
                imageUrl: widget.path,
                httpHeaders: widget.headers,
                fit: BoxFit.fitWidth,
                memCacheWidth: 1080,
                fadeInDuration: const Duration(milliseconds: 180),
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
                errorWidget: (context, url, err) => Container(
                  height: 200,
                  color: const Color(0xFF18181B),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image, color: ShadcnColors.mutedForeground, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          'Стр. ${widget.index + 1} не загрузилась',
                          style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12),
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
