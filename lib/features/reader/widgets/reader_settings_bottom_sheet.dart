import 'package:flutter/material.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../../../core/widgets/frosted_glass.dart';
import '../models/chapter.dart';
import '../models/manga_reader_settings.dart';
import '../services/chapter_selection.dart';

class ReaderSettingsBottomSheet extends StatefulWidget {
  final MangaReaderSettings settings;
  final int currentIndex;
  final int totalPages;
  final ValueChanged<int>? onPageSelected;
  final ValueChanged<MangaReadingMode>? onReadingModeChanged;
  final Chapter? currentChapter;
  final List<Chapter>? chapters;
  final ValueChanged<Chapter>? onChapterSelected;

  const ReaderSettingsBottomSheet({
    super.key,
    required this.settings,
    this.currentIndex = 0,
    this.totalPages = 0,
    this.onPageSelected,
    this.onReadingModeChanged,
    this.currentChapter,
    this.chapters,
    this.onChapterSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required MangaReaderSettings settings,
    int currentIndex = 0,
    int totalPages = 0,
    ValueChanged<int>? onPageSelected,
    ValueChanged<MangaReadingMode>? onReadingModeChanged,
    Chapter? currentChapter,
    List<Chapter>? chapters,
    ValueChanged<Chapter>? onChapterSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReaderSettingsBottomSheet(
        settings: settings,
        currentIndex: currentIndex,
        totalPages: totalPages,
        onPageSelected: onPageSelected,
        onReadingModeChanged: onReadingModeChanged,
        currentChapter: currentChapter,
        chapters: chapters,
        onChapterSelected: onChapterSelected,
      ),
    );
  }

  @override
  State<ReaderSettingsBottomSheet> createState() => _ReaderSettingsBottomSheetState();
}

class _ReaderSettingsBottomSheetState extends State<ReaderSettingsBottomSheet> {
  late double _pageSliderValue;

  @override
  void initState() {
    super.initState();
    _pageSliderValue = (widget.currentIndex + 1).toDouble().clamp(
      1.0,
      widget.totalPages > 0 ? widget.totalPages.toDouble() : 1.0,
    );
  }

  Chapter? get _prevChapter {
    if (widget.chapters == null || widget.currentChapter == null) return null;
    final ordered = ChapterSelection.orderedChapters(widget.chapters!);
    final idx = ordered.indexWhere((c) => c.id == widget.currentChapter!.id);
    if (idx > 0) {
      return ordered[idx - 1];
    }
    return null;
  }

  Chapter? get _nextChapter {
    if (widget.chapters == null || widget.currentChapter == null) return null;
    final ordered = ChapterSelection.orderedChapters(widget.chapters!);
    final idx = ordered.indexWhere((c) => c.id == widget.currentChapter!.id);
    if (idx >= 0 && idx < ordered.length - 1) {
      return ordered[idx + 1];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;

    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return FrostedGlass(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          backgroundColor: const Color(0xF7121215),
          padding: EdgeInsets.zero,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Полоса перетаскивания (Drag Handle)
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: ShadcnColors.borderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Заголовок
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune_rounded, color: ShadcnColors.foreground, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Настройки читалки',
                            style: TextStyle(
                              color: ShadcnColors.foreground,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: ShadcnColors.mutedForeground, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 1. Быстрый переход по страницам (Слайдер)
                  if (widget.totalPages > 1) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Страница',
                          style: TextStyle(
                            color: ShadcnColors.mutedForeground,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${_pageSliderValue.round()} из ${widget.totalPages}',
                          style: const TextStyle(
                            color: ShadcnColors.foreground,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: ShadcnColors.primary,
                        inactiveTrackColor: ShadcnColors.border,
                        thumbColor: ShadcnColors.primary,
                        overlayColor: ShadcnColors.primary.withValues(alpha: 0.15),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _pageSliderValue.clamp(1.0, widget.totalPages.toDouble()),
                        min: 1.0,
                        max: widget.totalPages.toDouble(),
                        divisions: widget.totalPages > 1 ? widget.totalPages - 1 : 1,
                        onChanged: (val) {
                          setState(() => _pageSliderValue = val);
                          widget.onPageSelected?.call(val.round() - 1);
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 2. Навигация по главам (если список доступен)
                  if (widget.chapters != null && widget.chapters!.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _prevChapter != null
                                  ? ShadcnColors.foreground
                                  : ShadcnColors.mutedForeground.withValues(alpha: 0.4),
                              side: BorderSide(
                                color: _prevChapter != null ? ShadcnColors.border : ShadcnColors.border.withValues(alpha: 0.2),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.skip_previous_rounded, size: 18),
                            label: const Text('Пред. глава', style: TextStyle(fontSize: 12)),
                            onPressed: _prevChapter != null
                                ? () {
                                    Navigator.pop(context);
                                    widget.onChapterSelected?.call(_prevChapter!);
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _nextChapter != null
                                  ? ShadcnColors.foreground
                                  : ShadcnColors.mutedForeground.withValues(alpha: 0.4),
                              side: BorderSide(
                                color: _nextChapter != null ? ShadcnColors.border : ShadcnColors.border.withValues(alpha: 0.2),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.skip_next_rounded, size: 18),
                            label: const Text('След. глава', style: TextStyle(fontSize: 12)),
                            onPressed: _nextChapter != null
                                ? () {
                                    Navigator.pop(context);
                                    widget.onChapterSelected?.call(_nextChapter!);
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],

                  // 3. Режим чтения
                  const Text(
                    'Режим чтения',
                    style: TextStyle(
                      color: ShadcnColors.mutedForeground,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MangaReadingMode.values.map((mode) {
                      final isSelected = settings.readingMode == mode;
                      return _buildChoiceChip(
                        label: mode.label,
                        icon: mode.icon,
                        isSelected: isSelected,
                        onTap: () {
                          settings.setReadingMode(mode);
                          widget.onReadingModeChanged?.call(mode);
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 4. Цветовая тема фона
                  const Text(
                    'Цвет фона',
                    style: TextStyle(
                      color: ShadcnColors.mutedForeground,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: MangaReaderTheme.values.map((theme) {
                      final isSelected = settings.theme == theme;
                      return Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: _buildThemeCircle(
                          theme: theme,
                          isSelected: isSelected,
                          onTap: () => settings.setTheme(theme),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 5. Масштабирование / Подгонка изображения
                  const Text(
                    'Подгонка изображения',
                    style: TextStyle(
                      color: ShadcnColors.mutedForeground,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MangaImageFit.values.map((fit) {
                      final isSelected = settings.imageFit == fit;
                      return _buildChoiceChip(
                        label: fit.label,
                        isSelected: isSelected,
                        onTap: () => settings.setImageFit(fit),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 6. Отступы между страницами
                  const Text(
                    'Отступ между страницами',
                    style: TextStyle(
                      color: ShadcnColors.mutedForeground,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [0.0, 4.0, 8.0, 16.0].map((spacing) {
                      final isSelected = settings.pageSpacing == spacing;
                      return _buildChoiceChip(
                        label: spacing == 0.0 ? 'Без отступа' : '${spacing.toInt()} px',
                        isSelected: isSelected,
                        onTap: () => settings.setPageSpacing(spacing),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 7. Дополнительные параметры (Переключатели)
                  _buildSwitchTile(
                    title: 'Индикатор страницы в углу',
                    subtitle: 'Отображать номер страницы при скрытых панелях управления',
                    value: settings.showPageNumberOverlay,
                    onChanged: (val) => settings.setShowPageNumberOverlay(val),
                  ),
                  const SizedBox(height: 6),
                  _buildSwitchTile(
                    title: 'Не гасить экран',
                    subtitle: 'Блокировать автовыключение экрана во время чтения',
                    value: settings.keepScreenOn,
                    onChanged: (val) => settings.setKeepScreenOn(val),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChoiceChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ShadcnColors.primary : ShadcnColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? ShadcnColors.primary : ShadcnColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: isSelected ? ShadcnColors.primaryForeground : ShadcnColors.mutedForeground,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? ShadcnColors.primaryForeground : ShadcnColors.foreground,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCircle({
    required MangaReaderTheme theme,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? ShadcnColors.accent : ShadcnColors.borderSubtle,
                width: isSelected ? 2.5 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: ShadcnColors.accent.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 18,
                    color: theme == MangaReaderTheme.light ? Colors.black : Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            theme.label,
            style: TextStyle(
              color: isSelected ? ShadcnColors.foreground : ShadcnColors.mutedForeground,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ShadcnColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadcnColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ShadcnColors.foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ShadcnColors.mutedForeground,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: ShadcnColors.accent,
            activeTrackColor: ShadcnColors.accent.withValues(alpha: 0.4),
            inactiveThumbColor: ShadcnColors.mutedForeground,
            inactiveTrackColor: ShadcnColors.border,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
