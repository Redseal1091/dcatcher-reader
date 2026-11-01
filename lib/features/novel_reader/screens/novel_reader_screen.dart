import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../../../core/widgets/frosted_glass.dart';
import '../models/novel_chapter.dart';
import '../models/reader_settings.dart';

class NovelReaderScreen extends StatefulWidget {
  final String novelTitle;
  final NovelChapter chapter;
  final List<NovelChapter> allChapters;

  const NovelReaderScreen({
    super.key,
    required this.novelTitle,
    required this.chapter,
    this.allChapters = const [],
  });

  @override
  State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends State<NovelReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showControls = true;
  double _readPercent = 0.0;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateProgress);
  }

  void _updateProgress() {
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
      final p = (_scrollController.offset / _scrollController.position.maxScrollExtent).clamp(0.0, 1.0);
      setState(() => _readPercent = p);
    }
  }

  @override
  void dispose() {
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
                ],
              ),
            ),
          );
        },
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
    return ChangeNotifierProvider(
      create: (_) => ReaderSettings(),
      child: Consumer<ReaderSettings>(
        builder: (context, settings, _) {
          final paragraphs = widget.chapter.content
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();

          return Scaffold(
            backgroundColor: settings.backgroundColor,
            body: Stack(
              children: [
                // Основной читаемый текст новеллы
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
                                widget.chapter.title,
                                style: TextStyle(
                                  color: settings.textColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
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
                          textAlign: TextAlign.justify,
                          style: TextStyle(
                            color: settings.textColor,
                            fontSize: settings.fontSize,
                            height: settings.lineHeight,
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
                                widget.chapter.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ShadcnColors.foreground,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // Озвучка текста голосом (TTS)
                            IconButton(
                              icon: Icon(
                                _isSpeaking ? Icons.volume_up : Icons.volume_up_outlined,
                                color: _isSpeaking ? ShadcnColors.accent : ShadcnColors.foreground,
                                size: 20,
                              ),
                              tooltip: 'Озвучить главу голосом (TTS)',
                              onPressed: () {
                                setState(() => _isSpeaking = !_isSpeaking);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _isSpeaking
                                          ? 'Голосовое чтение (TTS) запущено'
                                          : 'Голосовое чтение приостановлено',
                                    ),
                                    duration: const Duration(seconds: 1),
                                    backgroundColor: ShadcnColors.surface,
                                  ),
                                );
                              },
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
                                icon: const Icon(Icons.chevron_left, color: ShadcnColors.foreground, size: 20),
                                onPressed: () {},
                              ),
                              Text(
                                'Глава ${widget.chapter.chapterNumber}',
                                style: const TextStyle(color: ShadcnColors.foreground, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, color: ShadcnColors.foreground, size: 20),
                                onPressed: () {},
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
        },
      ),
    );
  }
}
