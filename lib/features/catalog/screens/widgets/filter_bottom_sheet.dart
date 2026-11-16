import 'package:flutter/material.dart';
import '../../../../core/theme/shadcn_colors.dart';
import '../../../../core/widgets/frosted_glass.dart';
import '../../../../core/widgets/tri_state_chip.dart';
import '../../../../core/widgets/shadcn_button.dart';
import '../../models/catalog_filters.dart';
import '../../models/manga.dart';
import '../../models/genre.dart';

class FilterBottomSheet extends StatefulWidget {
  final CatalogFilters initialFilters;
  final Function(CatalogFilters) onApply;

  const FilterBottomSheet({
    super.key,
    required this.initialFilters,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late CatalogFilters _tempFilters;
  final TextEditingController _genreSearchCtrl = TextEditingController();
  String _genreSearchQuery = '';
  String _selectedCategory = 'Все';

  @override
  void initState() {
    super.initState();
    _tempFilters = widget.initialFilters.clone();
  }

  @override
  void dispose() {
    _genreSearchCtrl.dispose();
    super.dispose();
  }

  FilterTriState _nextState(FilterTriState current) {
    switch (current) {
      case FilterTriState.ignore:
        return FilterTriState.include;
      case FilterTriState.include:
        return FilterTriState.exclude; // 🚫 ИСКЛЮЧИТЬ ИЗ ВЫДАЧИ
      case FilterTriState.exclude:
        return FilterTriState.ignore;
    }
  }

  FilterTriState _nextGenreState(FilterTriState current) {
    switch (current) {
      case FilterTriState.ignore:
        return FilterTriState.include; // 🟢 Включить
      case FilterTriState.include:
        return FilterTriState.exclude; // 🔴 Исключить
      case FilterTriState.exclude:
        return FilterTriState.ignore; // ⚪ Сбросить
    }
  }

  void _applyGenrePreset({required List<String> include, List<String>? exclude}) {
    setState(() {
      for (final id in include) {
        _tempFilters.setGenreState(id, FilterTriState.include);
      }
      if (exclude != null) {
        for (final id in exclude) {
          _tempFilters.setGenreState(id, FilterTriState.exclude);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredGenres = MangaGenre.search(
      _genreSearchQuery,
      category: _selectedCategory,
    );

    final includedCount = _tempFilters.selectedGenreIds.length;
    final excludedCount = _tempFilters.excludedGenres.length;

    return FrostedGlass(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      backgroundColor: const Color(0xFA121215), // Плотное матовое стекло
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Верхний хэндл и заголовок
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Фильтры каталога',
                              style: TextStyle(
                                color: ShadcnColors.foreground,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (_tempFilters.activeFiltersCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ShadcnColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_tempFilters.activeFiltersCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: ShadcnColors.mutedForeground, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(color: ShadcnColors.border),

              // Прокручиваемый список секций
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                    // Секция 1: Исключение по статусам пользователя
                    _buildSectionTitle(
                      'Статусы в библиотеке',
                      subtitle: 'Нажмите 2 раза для исключения (🚫 не показывать в выдаче)',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TriStateChip(
                          label: 'Читаю',
                          state: _tempFilters.readingStatus,
                          defaultIcon: Icons.auto_stories,
                          onTap: () {
                            setState(() {
                              _tempFilters.readingStatus = _nextState(_tempFilters.readingStatus);
                            });
                          },
                        ),
                        TriStateChip(
                          label: 'Прочитано',
                          state: _tempFilters.completedStatus,
                          defaultIcon: Icons.check_circle_outline,
                          onTap: () {
                            setState(() {
                              _tempFilters.completedStatus = _nextState(_tempFilters.completedStatus);
                            });
                          },
                        ),
                        TriStateChip(
                          label: 'В планах',
                          state: _tempFilters.plannedStatus,
                          defaultIcon: Icons.bookmark_border,
                          onTap: () {
                            setState(() {
                              _tempFilters.plannedStatus = _nextState(_tempFilters.plannedStatus);
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Секция 2: Лицензирование
                    _buildSectionTitle(
                      'Лицензирование',
                      subtitle: 'У лицензированных тайтлов главы могут быть заблокированы',
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _tempFilters.hideLicensed = !_tempFilters.hideLicensed;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _tempFilters.hideLicensed ? const Color(0x22EF4444) : ShadcnColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _tempFilters.hideLicensed ? ShadcnColors.exclude : ShadcnColors.border,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _tempFilters.hideLicensed ? Icons.block : Icons.verified_user_outlined,
                              color: _tempFilters.hideLicensed ? ShadcnColors.exclude : ShadcnColors.mutedForeground,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Скрыть лицензированные',
                                    style: TextStyle(
                                      color: _tempFilters.hideLicensed ? ShadcnColors.exclude : ShadcnColors.foreground,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Text(
                                    'Не показывать тайтлы с пометкой «Лицензировано» в каталоге',
                                    style: TextStyle(
                                      color: ShadcnColors.mutedForeground,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _tempFilters.hideLicensed,
                              activeColor: ShadcnColors.exclude,
                              onChanged: (val) {
                                setState(() {
                                  _tempFilters.hideLicensed = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Секция 3: Тип (Манхва / Манга / Маньхуа)
                    _buildSectionTitle('Тип произведения'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSelectableChip(
                          label: '🇰🇷 Манхва (Корея)',
                          isSelected: _tempFilters.publicationTypes.contains(PublicationType.manhwa),
                          onTap: () => _toggleType(PublicationType.manhwa),
                        ),
                        _buildSelectableChip(
                          label: '🇯🇵 Манга (Япония)',
                          isSelected: _tempFilters.publicationTypes.contains(PublicationType.manga),
                          onTap: () => _toggleType(PublicationType.manga),
                        ),
                        _buildSelectableChip(
                          label: '🇨🇳 Маньхуа (Китай)',
                          isSelected: _tempFilters.publicationTypes.contains(PublicationType.manhua),
                          onTap: () => _toggleType(PublicationType.manhua),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Секция 4: Возрастной рейтинг
                    _buildSectionTitle('Возрастной рейтинг'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSelectableChip(
                          label: '0+ Для всех (Safe)',
                          isSelected: _tempFilters.contentRatings.contains(ContentRating.safe),
                          onTap: () => _toggleRating(ContentRating.safe),
                        ),
                        _buildSelectableChip(
                          label: '16+ Подростковый (Suggestive)',
                          isSelected: _tempFilters.contentRatings.contains(ContentRating.suggestive),
                          onTap: () => _toggleRating(ContentRating.suggestive),
                        ),
                        _buildSelectableChip(
                          label: '18+ Взрослый (Erotica)',
                          isSelected: _tempFilters.contentRatings.contains(ContentRating.erotica),
                          onTap: () => _toggleRating(ContentRating.erotica),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // -------------------------------------------------------------
                    // Секция 5: Расширенные жанры и теги (TriState + Поиск + Пресеты)
                    // -------------------------------------------------------------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Жанры и теги',
                                    style: TextStyle(
                                      color: ShadcnColors.foreground,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (includedCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: ShadcnColors.completedBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: ShadcnColors.completed, width: 0.8),
                                      ),
                                      child: Text(
                                        '+$includedCount',
                                        style: const TextStyle(
                                          color: ShadcnColors.completed,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (excludedCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: ShadcnColors.excludeBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: ShadcnColors.exclude, width: 0.8),
                                      ),
                                      child: Text(
                                        '-$excludedCount',
                                        style: const TextStyle(
                                          color: ShadcnColors.exclude,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                '1 тап: включить (+) • 2 тапа: исключить (🚫)',
                                style: TextStyle(
                                  color: ShadcnColors.mutedForeground,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (includedCount > 0 || excludedCount > 0)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _tempFilters.clearGenres();
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Очистить жанры',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Поле быстрого поиска по жанрам
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: ShadcnColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ShadcnColors.border),
                      ),
                      child: TextField(
                        controller: _genreSearchCtrl,
                        style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Поиск жанра (культивация, регрессия, фэнтези...)...',
                          hintStyle: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12),
                          prefixIcon: const Icon(Icons.search, color: ShadcnColors.mutedForeground, size: 16),
                          suffixIcon: _genreSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: ShadcnColors.mutedForeground, size: 16),
                                  onPressed: () {
                                    _genreSearchCtrl.clear();
                                    setState(() => _genreSearchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (val) {
                          setState(() => _genreSearchQuery = val);
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Быстрые пресеты популярных сетов
                    SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildPresetChip(
                            label: '👑 Топ Вебтуны',
                            onTap: () => _applyGenrePreset(
                              include: ['system', 'leveling', 'dungeon'],
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildPresetChip(
                            label: '⚡ Культивация',
                            onTap: () => _applyGenrePreset(
                              include: ['cultivation', 'wuxia'],
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildPresetChip(
                            label: '✨ Чистая романтика',
                            onTap: () => _applyGenrePreset(
                              include: ['423e2eae-a7a2-4a8b-ac03-a8351462d71d'],
                              exclude: ['harem'],
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildPresetChip(
                            label: '🗡️ Тёмное фэнтези',
                            onTap: () => _applyGenrePreset(
                              include: ['dark-fantasy', 'demons'],
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildPresetChip(
                            label: '🔄 Регрессия',
                            onTap: () => _applyGenrePreset(
                              include: ['regression', 'reincarnation'],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Табы категорий жанров
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: MangaGenre.categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (ctx, idx) {
                          final cat = MangaGenre.categories[idx];
                          final isSel = _selectedCategory == cat;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(() => _selectedCategory = cat),
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? ShadcnColors.primary : ShadcnColors.card,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSel ? ShadcnColors.primary : ShadcnColors.border,
                                  ),
                                ),
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    color: isSel ? Colors.white : ShadcnColors.mutedForeground,
                                    fontSize: 11.5,
                                    fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Чипы жанров (TriState: Include / Exclude / Ignore)
                    if (filteredGenres.isEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Жанры по запросу «$_genreSearchQuery» не найдены',
                            style: const TextStyle(
                              color: ShadcnColors.mutedForeground,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: filteredGenres.map((genre) {
                          final state = _tempFilters.getGenreState(genre.id);
                          return _buildGenreTriStateChip(
                            genre: genre,
                            state: state,
                            onTap: () {
                              setState(() {
                                final next = _nextGenreState(state);
                                _tempFilters.setGenreState(genre.id, next);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),

              const Divider(color: ShadcnColors.border),

              // Кнопки управления внизу
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: ShadcnButton(
                        text: 'Сбросить всё',
                        variant: ButtonVariant.outline,
                        onPressed: () {
                          setState(() {
                            _tempFilters.reset();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ShadcnButton(
                        text: 'Применить',
                        variant: ButtonVariant.primary,
                        onPressed: () {
                          widget.onApply(_tempFilters);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x1F3B82F6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x403B82F6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF60A5FA),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenreTriStateChip({
    required MangaGenre genre,
    required FilterTriState state,
    required VoidCallback onTap,
  }) {
    Color bg;
    Color border;
    Color text;
    IconData icon;

    switch (state) {
      case FilterTriState.ignore:
        bg = ShadcnColors.card;
        border = ShadcnColors.border;
        text = ShadcnColors.mutedForeground;
        icon = genre.icon;
        break;
      case FilterTriState.include:
        bg = ShadcnColors.completedBg;
        border = ShadcnColors.completed;
        text = ShadcnColors.completed;
        icon = Icons.check_circle_rounded;
        break;
      case FilterTriState.exclude:
        bg = ShadcnColors.excludeBg;
        border = ShadcnColors.exclude;
        text = ShadcnColors.exclude;
        icon = Icons.block_rounded;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: text),
              const SizedBox(width: 6),
              Text(
                genre.nameRu,
                style: TextStyle(
                  color: text,
                  fontSize: 12,
                  fontWeight: state == FilterTriState.ignore ? FontWeight.w400 : FontWeight.w600,
                  decoration: state == FilterTriState.exclude ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: ShadcnColors.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: ShadcnColors.mutedForeground,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? ShadcnColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? ShadcnColors.primary : ShadcnColors.border,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? ShadcnColors.foreground : ShadcnColors.mutedForeground,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  void _toggleType(PublicationType type) {
    setState(() {
      if (_tempFilters.publicationTypes.contains(type)) {
        if (_tempFilters.publicationTypes.length > 1) {
          _tempFilters.publicationTypes.remove(type);
        }
      } else {
        _tempFilters.publicationTypes.add(type);
      }
    });
  }

  void _toggleRating(ContentRating rating) {
    setState(() {
      if (_tempFilters.contentRatings.contains(rating)) {
        if (_tempFilters.contentRatings.length > 1) {
          _tempFilters.contentRatings.remove(rating);
        }
      } else {
        _tempFilters.contentRatings.add(rating);
      }
    });
  }
}
