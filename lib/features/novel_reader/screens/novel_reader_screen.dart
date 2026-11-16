import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../../../core/widgets/frosted_glass.dart';
import '../models/novel_chapter.dart';
import '../models/reader_settings.dart';
import '../services/novel_repository.dart';
import '../../books/services/book_progress_service.dart';
import '../../library/state/book_shelf_provider.dart';

class NovelReaderScreen extends StatefulWidget {
  final String novelTitle;
  final NovelChapter chapter;
  final List<NovelChapter> allChapters;
  final String? bookId;
  final String? source;
  final double? initialScrollOffset;
  final void Function(String chapterId, String chapterTitle, double scrollOffset, double readPercent)? onProgressChanged;

  const NovelReaderScreen({
    super.key,
    required this.novelTitle,
    required this.chapter,
    this.allChapters = const [],
    this.bookId,
    this.source,
    this.initialScrollOffset,
    this.onProgressChanged,
  });

  @override
  State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends State<NovelReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showControls = true;
  double _readPercent = 0.0;
  late NovelChapter _activeChapter;
  Timer? _saveDebounceTimer;
  bool _isLoadingContent = false;
  String? _contentError;

  @override
  void initState() {
    super.initState();
    _activeChapter = widget.chapter;
    _scrollController.addListener(_updateProgress);

    if (_activeChapter.content.trim().isEmpty) {
      _ensureChapterContentLoaded(_activeChapter);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.initialScrollOffset != null && widget.initialScrollOffset! > 0) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(widget.initialScrollOffset!);
        }
      } else if (widget.bookId != null && widget.bookId!.isNotEmpty) {
        final saved = await BookProgressService.getProgress(widget.bookId!);
        if (saved != null && saved.chapterId == _activeChapter.id && saved.scrollOffset > 0) {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(saved.scrollOffset);
            setState(() {
              _readPercent = saved.readPercent;
            });
          }
        }
      }
    });
  }

  Future<void> _ensureChapterContentLoaded(NovelChapter chapter) async {
    if (chapter.content.trim().isNotEmpty) {
      if (mounted) setState(() => _contentError = null);
      return;
    }

    setState(() {
      _isLoadingContent = true;
      _contentError = null;
    });

    try {
      final text = await NovelRepository().getChapterContent(chapter, source: widget.source);
      if (!mounted) return;
      if (text.isEmpty || text.startsWith('Ошибка загрузки главы')) {
        setState(() {
          _isLoadingContent = false;
          _contentError = text.isNotEmpty ? text : 'Не удалось загрузить содержимое главы.';
        });
      } else {
        setState(() {
          _activeChapter = chapter.copyWith(content: text);
          _isLoadingContent = false;
          _contentError = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingContent = false;
        _contentError = 'Ошибка сети: $e';
      });
    }
  }

  void _saveProgress() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final percent = _readPercent;

    if (widget.bookId != null && widget.bookId!.isNotEmpty) {
      BookProgressService.saveProgress(
        BookProgress(
          bookId: widget.bookId!,
          chapterId: _activeChapter.id,
          chapterTitle: _activeChapter.title,
          chapterNumber: _activeChapter.chapterNumber,
          scrollOffset: offset,
          readPercent: percent,
          updatedAt: DateTime.now(),
        ),
      );

      try {
        final shelf = Provider.of<BookShelfProvider>(context, listen: false);
        shelf.updateBookProgress(
          bookId: widget.bookId!,
          chapterId: _activeChapter.id,
          chapterTitle: _activeChapter.title,
          scrollOffset: offset,
          readPercent: percent,
        );
      } catch (_) {}
    }

    widget.onProgressChanged?.call(
      _activeChapter.id,
      _activeChapter.title,
      offset,
      percent,
    );
  }

  void _debouncedSaveProgress() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _saveProgress();
      }
    });
  }

  int get _activeChapterIndex {
    if (widget.allChapters.isEmpty) return -1;
    return widget.allChapters.indexWhere((c) => c.id == _activeChapter.id);
  }

  bool get _hasPreviousChapter {
    final idx = _activeChapterIndex;
    return idx > 0;
  }

  bool get _hasNextChapter {
    final idx = _activeChapterIndex;
    return idx >= 0 && idx < widget.allChapters.length - 1;
  }

  String _formatChapterLabel(NovelChapter chapter) {
    final num = chapter.chapterNumber.trim();
    final title = chapter.title.trim();
    final lowerTitle = title.toLowerCase();

    if (num == '0' || lowerTitle.contains('пролог') || lowerTitle.contains('введение')) {
      if (lowerTitle.contains('введение')) {
        return 'Введение';
      }
      if (lowerTitle.contains('пролог')) {
        return 'Пролог';
      }
      return 'Введение';
    }

    final partMatch = RegExp(r'^Часть\s*(\d+|[IVXLCDM]+)', caseSensitive: false).firstMatch(title);
    if (partMatch != null) {
      return partMatch.group(0)!;
    }
    if (lowerTitle.startsWith('часть')) {
      return 'Часть $num';
    }

    final chapterMatch = RegExp(r'^Глава\s*(\d+|[IVXLCDM]+)', caseSensitive: false).firstMatch(title);
    if (chapterMatch != null) {
      return chapterMatch.group(0)!;
    }

    if (num.isNotEmpty && num != 'null') {
      return 'Глава $num';
    }
    return title.isNotEmpty ? title : 'Глава';
  }

  void _navigateToChapter(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.allChapters.length) return;
    _saveProgress();
    setState(() {
      _activeChapter = widget.allChapters[newIndex];
      _readPercent = 0.0;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
    _ensureChapterContentLoaded(_activeChapter);
    _saveProgress();
  }

  void _updateProgress() {
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
      final p = (_scrollController.offset / _scrollController.position.maxScrollExtent).clamp(0.0, 1.0);
      setState(() => _readPercent = p);
      _debouncedSaveProgress();
    }
  }

  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    _saveProgress();
    _scrollController.dispose();
    super.dispose();
  }

  void _openSettings(BuildContext context, ReaderSettings settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return FrostedGlass(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            backgroundColor: const Color(0xF5121215),
            padding: const EdgeInsets.all(20),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Параметры чтения',
                    style: TextStyle(
                      color: ShadcnColors.foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Выбор темы фона
                  const Text(
                    'Цветовая тема',
                    style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildThemeCircle(NovelReaderTheme.zincDark, 'Zinc', const Color(0xFF09090B), settings, () {
                        settings.setTheme(NovelReaderTheme.zincDark);
                        setModalState(() {});
                      }),
                      const SizedBox(width: 12),
                      _buildThemeCircle(NovelReaderTheme.oledDark, 'OLED', Colors.black, settings, () {
                        settings.setTheme(NovelReaderTheme.oledDark);
                        setModalState(() {});
                      }),
                      const SizedBox(width: 12),
                      _buildThemeCircle(NovelReaderTheme.warmSepia, 'Сепия', const Color(0xFF1E1A16), settings, () {
                        settings.setTheme(NovelReaderTheme.warmSepia);
                        setModalState(() {});
                      }),
                      const SizedBox(width: 12),
                      _buildThemeCircle(NovelReaderTheme.softGreen, 'Мята', const Color(0xFF0F1A14), settings, () {
                        settings.setTheme(NovelReaderTheme.softGreen);
                        setModalState(() {});
                      }),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Размер шрифта
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Размер шрифта',
                        style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                      ),
                      Text(
                        '${settings.fontSize.toInt()} pt',
                        style: const TextStyle(color: ShadcnColors.foreground, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Slider(
                    value: settings.fontSize,
                    min: 13.0,
                    max: 28.0,
                    activeColor: ShadcnColors.primary,
                    inactiveColor: ShadcnColors.border,
                    onChanged: (val) {
                      settings.setFontSize(val);
                      setModalState(() {});
                    },
                  ),

                  // Межстрочный интервал
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Межстрочный интервал',
                        style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                      ),
                      Text(
                        '${settings.lineHeight.toStringAsFixed(1)}x',
                        style: const TextStyle(color: ShadcnColors.foreground, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Slider(
                    value: settings.lineHeight,
                    min: 1.3,
                    max: 2.2,
                    activeColor: ShadcnColors.primary,
                    inactiveColor: ShadcnColors.border,
                    onChanged: (val) {
                      settings.setLineHeight(val);
                      setModalState(() {});
                    },
                  ),

                  const SizedBox(height: 12),

                  // Выбор шрифта
                  const Text(
                    'Шрифт',
                    style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildFontFamilyChip('Sans', 'Roboto', settings, () {
                        settings.setFontFamily('Roboto');
                        setModalState(() {});
                      }),
                      const SizedBox(width: 8),
                      _buildFontFamilyChip('Serif', 'serif', settings, () {
                        settings.setFontFamily('serif');
                        setModalState(() {});
                      }),
                      const SizedBox(width: 8),
                      _buildFontFamilyChip('Mono', 'monospace', settings, () {
                        settings.setFontFamily('monospace');
                        setModalState(() {});
                      }),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Выравнивание текста
                  const Text(
                    'Выравнивание',
                    style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildAlignChip('По ширине', TextAlign.justify, Icons.format_align_justify, settings, () {
                        settings.setTextAlign(TextAlign.justify);
                        setModalState(() {});
                      }),
                      const SizedBox(width: 8),
                      _buildAlignChip('По левому краю', TextAlign.start, Icons.format_align_left, settings, () {
                        settings.setTextAlign(TextAlign.start);
                        setModalState(() {});
                      }),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFontFamilyChip(String label, String family, ReaderSettings settings, VoidCallback onSelect) {
    final isSelected = settings.fontFamily == family;
    return Expanded(
      child: GestureDetector(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? ShadcnColors.primary.withValues(alpha: 0.15) : ShadcnColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? ShadcnColors.primary : ShadcnColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: family,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? ShadcnColors.primary : ShadcnColors.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlignChip(String label, TextAlign align, IconData icon, ReaderSettings settings, VoidCallback onSelect) {
    final isSelected = settings.textAlign == align;
    return Expanded(
      child: GestureDetector(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? ShadcnColors.primary.withValues(alpha: 0.15) : ShadcnColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? ShadcnColors.primary : ShadcnColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? ShadcnColors.primary : ShadcnColors.mutedForeground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? ShadcnColors.primary : ShadcnColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeCircle(NovelReaderTheme theme, String name, Color bg, ReaderSettings settings, VoidCallback onSelect) {
    final isSelected = settings.theme == theme;
    return GestureDetector(
      onTap: onSelect,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? ShadcnColors.primary : ShadcnColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: isSelected ? const Icon(Icons.check, size: 18, color: ShadcnColors.primary) : null,
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              color: isSelected ? ShadcnColors.foreground : ShadcnColors.mutedForeground,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeChapter = _activeChapter;
    final activeIndex = _activeChapterIndex;
    final hasPrev = _hasPreviousChapter;
    final hasNext = _hasNextChapter;

    return ChangeNotifierProvider(
      create: (_) => ReaderSettings(),
      child: Consumer<ReaderSettings>(
        builder: (context, settings, _) {
          final paragraphs = activeChapter.content
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();

          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, result) {
              _saveProgress();
            },
            child: Scaffold(
              backgroundColor: settings.backgroundColor,
              body: SafeArea(
                child: Stack(
                  children: [
                  // Основной читаемый текст новеллы
                  if (_isLoadingContent)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: ShadcnColors.primary, strokeWidth: 2),
                          const SizedBox(height: 16),
                          Text(
                            'Загрузка текста главы...',
                            style: TextStyle(color: settings.textColor.withValues(alpha: 0.7), fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  else if (_contentError != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 44),
                            const SizedBox(height: 12),
                            Text(
                              _contentError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: settings.textColor, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ShadcnColors.primary,
                                foregroundColor: ShadcnColors.primaryForeground,
                              ),
                              onPressed: () => _ensureChapterContentLoaded(_activeChapter),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Повторить попытку'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => setState(() => _showControls = !_showControls),
                      child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 100, 24, 120),
                      itemCount: paragraphs.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.novelTitle,
                                  style: const TextStyle(
                                    color: ShadcnColors.mutedForeground,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  activeChapter.title,
                                  style: TextStyle(
                                    color: settings.textColor,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                    fontFamily: settings.fontFamily,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Divider(color: ShadcnColors.border),
                              ],
                            ),
                          );
                        }

                        final p = paragraphs[index - 1];
                        return Padding(
                          padding: EdgeInsets.only(bottom: settings.fontSize * 0.8),
                          child: Text(
                            p,
                            textAlign: settings.textAlign,
                            style: TextStyle(
                              color: settings.textColor,
                              fontSize: settings.fontSize,
                              height: settings.lineHeight,
                              fontFamily: settings.fontFamily,
                              letterSpacing: 0.1,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Верхний матовый бар
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  top: _showControls ? 0 : -90,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: FrostedGlass(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: ShadcnColors.foreground, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                activeChapter.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ShadcnColors.foreground,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // Кнопка настроек шрифта
                            IconButton(
                              icon: const Icon(Icons.text_fields_rounded, color: ShadcnColors.foreground, size: 20),
                              tooltip: 'Шрифт и тема',
                              onPressed: () => _openSettings(context, settings),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Нижний матовый бар прогресса
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  bottom: _showControls ? 20 : -80,
                  left: 20,
                  right: 20,
                  child: SafeArea(
                    child: FrostedGlass(
                      borderRadius: BorderRadius.circular(20),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Прочитано: ${(_readPercent * 100).toInt()}%',
                            style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.chevron_left,
                                  color: hasPrev ? ShadcnColors.foreground : ShadcnColors.mutedForeground,
                                  size: 20,
                                ),
                                tooltip: 'Предыдущая глава',
                                onPressed: hasPrev ? () => _navigateToChapter(activeIndex - 1) : null,
                              ),
                              Text(
                                _formatChapterLabel(activeChapter),
                                style: const TextStyle(color: ShadcnColors.foreground, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.chevron_right,
                                  color: hasNext ? ShadcnColors.foreground : ShadcnColors.mutedForeground,
                                  size: 20,
                                ),
                                tooltip: 'Следующая глава',
                                onPressed: hasNext ? () => _navigateToChapter(activeIndex + 1) : null,
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
          ),
        ),
      );
        },
      ),
    );
  }
}
