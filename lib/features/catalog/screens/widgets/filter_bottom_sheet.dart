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

  @override
  void initState() {
    super.initState();
    _tempFilters = widget.initialFilters.clone();
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

  @override
  Widget build(BuildContext context) {
    return FrostedGlass(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      backgroundColor: const Color(0xFA121215), // Плотное матовое стекло
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                        const Text(
                          'Фильтры каталога',
                          style: TextStyle(
                            color: ShadcnColors.foreground,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
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

                    const SizedBox(height: 24),

                    // Секция 5: Жанры
                    _buildSectionTitle('Жанры'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: MangaGenre.allGenres.map((genre) {
                        final isSelected = _tempFilters.selectedGenreIds.contains(genre.id);
                        return _buildSelectableChip(
                          label: genre.nameRu,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _tempFilters.selectedGenreIds.remove(genre.id);
                              } else {
                                _tempFilters.selectedGenreIds.add(genre.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
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
                        text: 'Сбросить',
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
