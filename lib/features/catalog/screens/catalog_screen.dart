import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/shadcn_button.dart';
import '../../../core/widgets/tri_state_chip.dart';
import '../state/catalog_provider.dart';
import '../models/manga.dart';
import '../../library/state/library_provider.dart';
import 'widgets/manga_card.dart';
import 'widgets/filter_bottom_sheet.dart';
import 'manga_detail_screen.dart';
import '../../sources/manga_source.dart';
import '../../sources/source_manager.dart';
import '../../books/screens/books_catalog_screen.dart';
import '../../novel_reader/screens/ranobe_catalog_screen.dart';
import '../../settings/screens/settings_screen.dart';

enum CatalogSection {
  manhwa, // Корея
  manhua, // Китай
  manga,  // Япония
  ranobe, // Азиатские новеллы
  books,  // Литература и классика
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  CatalogSection _activeSection = CatalogSection.manhwa;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _switchSection(_activeSection);
      }
    });
  }

  String get _currentSectionLabel {
    switch (_activeSection) {
      case CatalogSection.manhwa:
        return '🇰🇷 Манхва';
      case CatalogSection.manhua:
        return '🇨🇳 Маньхуа';
      case CatalogSection.manga:
        return '🇯🇵 Манга';
      case CatalogSection.ranobe:
        return '📖 Ранобе';
      case CatalogSection.books:
        return '📚 Книги';
    }
  }

  void _switchSection(CatalogSection section) {
    setState(() => _activeSection = section);
    final catalog = context.read<CatalogProvider>();
    final library = context.read<LibraryProvider>();
    final settings = context.read<AppSettingsProvider>();

    if (section == CatalogSection.manhwa) {
      catalog.filters.publicationTypes = {PublicationType.manhwa};
      catalog.switchSource(SourceManager.getSourceById(settings.manhwaSource), libraryProvider: library);
    } else if (section == CatalogSection.manhua) {
      catalog.filters.publicationTypes = {PublicationType.manhua};
      catalog.switchSource(SourceManager.getSourceById(settings.manhuaSource), libraryProvider: library);
    } else if (section == CatalogSection.manga) {
      catalog.filters.publicationTypes = {PublicationType.manga};
      catalog.switchSource(SourceManager.getSourceById(settings.mangaSource), libraryProvider: library);
    }
  }

  void _openMainMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFA121215),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: ShadcnColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: ShadcnColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              // Шапка меню
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.psychology_alt_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DCatcher Каталоги', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Выберите категорию историй', style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: ShadcnColors.border),
              const SizedBox(height: 8),

              _buildMenuItem(
                icon: Icons.auto_stories,
                color: const Color(0xFF38BDF8),
                title: 'Манхва (Корея)',
                subtitle: 'Цветные вебтуны, вертикальная лента, система, перерождение',
                isSelected: _activeSection == CatalogSection.manhwa,
                onTap: () {
                  Navigator.pop(ctx);
                  _switchSection(CatalogSection.manhwa);
                },
              ),
              _buildMenuItem(
                icon: Icons.bubble_chart,
                color: const Color(0xFFF59E0B),
                title: 'Маньхуа (Китай)',
                subtitle: 'Культивация, боевые искусства, бессмертные, сянься',
                isSelected: _activeSection == CatalogSection.manhua,
                onTap: () {
                  Navigator.pop(ctx);
                  _switchSection(CatalogSection.manhua);
                },
              ),
              _buildMenuItem(
                icon: Icons.menu_book,
                color: const Color(0xFFE11D48),
                title: 'Манга (Япония)',
                subtitle: 'Классическая ч/б манга, чтение справа-налево, сёнэн, исэкай',
                isSelected: _activeSection == CatalogSection.manga,
                onTap: () {
                  Navigator.pop(ctx);
                  _switchSection(CatalogSection.manga);
                },
              ),
              _buildMenuItem(
                icon: Icons.library_books,
                color: const Color(0xFF8B5CF6),
                title: 'Ранобе (Лайт-новеллы)',
                subtitle: 'Азиатские веб-романы и текстовые первоисточники',
                isSelected: _activeSection == CatalogSection.ranobe,
                onTap: () {
                  Navigator.pop(ctx);
                  _switchSection(CatalogSection.ranobe);
                },
              ),
              _buildMenuItem(
                icon: Icons.book,
                color: const Color(0xFF10B981),
                title: 'Книги (Художественные)',
                subtitle: 'Фантастика, детективы, мистика, мировая классика',
                isSelected: _activeSection == CatalogSection.books,
                onTap: () {
                  Navigator.pop(ctx);
                  _switchSection(CatalogSection.books);
                },
              ),
              const Divider(color: ShadcnColors.border),
              _buildMenuItem(
                icon: Icons.settings,
                color: ShadcnColors.foreground,
                title: 'Настройки DCatcher',
                subtitle: 'Темы фона (Паприка, OLED, Zinc), парсеры, 18+ контент',
                isSelected: false,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0x22E11D48) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isSelected ? const Color(0xFFE11D48) : Colors.transparent),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: TextStyle(color: isSelected ? Colors.white : ShadcnColors.foreground, fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 11)),
        trailing: isSelected ? const Icon(Icons.check, color: Color(0xFFE11D48), size: 18) : const Icon(Icons.chevron_right, color: ShadcnColors.mutedForeground, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _openFilters(BuildContext context) {
    final catalog = context.read<CatalogProvider>();
    final library = context.read<LibraryProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet(
        initialFilters: catalog.filters,
        onApply: (newFilters) {
          catalog.updateFilters(newFilters, library);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final library = context.watch<LibraryProvider>();
    final activeFilterCount = catalog.filters.activeFiltersCount;

    return Scaffold(
      backgroundColor: ShadcnColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Верхняя шапка: [ ☰ Меню ] + [ Горизонтальный логотип DCatcher ] + [ Текущий каталог ▼ ]
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  // Кнопка меню слева
                  InkWell(
                    onTap: () => _openMainMenu(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: ShadcnColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ShadcnColors.border),
                      ),
                      child: const Icon(Icons.menu_rounded, color: ShadcnColors.foreground, size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Горизонтальный логотип DCatcher с отсылкой к Паприке
                  InkWell(
                    onTap: () => _openMainMenu(context),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.psychology_alt_rounded, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'DCatcher',
                              style: TextStyle(
                                color: ShadcnColors.foreground,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              'PAPRIKA • DC MINI',
                              style: TextStyle(
                                color: Color(0xFFE11D48),
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Селектор текущего каталога
                  InkWell(
                    onTap: () => _openMainMenu(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: ShadcnColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ShadcnColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentSectionLabel,
                            style: const TextStyle(
                              color: ShadcnColors.foreground,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: ShadcnColors.mutedForeground),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Контент каталога в зависимости от выбранного раздела
            if (_activeSection == CatalogSection.books)
              const Expanded(child: BooksCatalogScreen())
            else if (_activeSection == CatalogSection.ranobe)
              const Expanded(child: RanobeCatalogScreen())
            else ...[
              // Поисковая панель + выбор источника + кнопка фильтров
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    // Селектор источника
                    PopupMenuButton<MangaSource>(
                      initialValue: catalog.source,
                      tooltip: 'Сменить источник каталога',
                      onSelected: (newSource) {
                        final settings = context.read<AppSettingsProvider>();
                        if (_activeSection == CatalogSection.manhwa) {
                          settings.setSource('manhwa', newSource.name);
                        } else if (_activeSection == CatalogSection.manhua) {
                          settings.setSource('manhua', newSource.name);
                        } else if (_activeSection == CatalogSection.manga) {
                          settings.setSource('manga', newSource.name);
                        }
                        catalog.switchSource(newSource, libraryProvider: library);
                      },
                      itemBuilder: (ctx) => SourceManager.sources
                          .map((s) => PopupMenuItem<MangaSource>(
                                value: s,
                                child: Row(
                                  children: [
                                    Icon(
                                      s.id == 'asura'
                                          ? Icons.bolt
                                          : s.id == 'mangalib'
                                              ? Icons.menu_book
                                              : s.id == 'mangabuff'
                                                  ? Icons.bubble_chart
                                                  : Icons.auto_stories,
                                      size: 16,
                                      color: s.id == catalog.source.id ? ShadcnColors.primary : ShadcnColors.mutedForeground,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      s.name,
                                      style: TextStyle(
                                        color: s.id == catalog.source.id ? ShadcnColors.primary : ShadcnColors.foreground,
                                        fontWeight: s.id == catalog.source.id ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
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
                            const Icon(Icons.hub_outlined, color: ShadcnColors.primary, size: 15),
                            const SizedBox(width: 5),
                            Text(
                              catalog.source.name,
                              style: const TextStyle(color: ShadcnColors.foreground, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_drop_down, color: ShadcnColors.mutedForeground, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: ShadcnColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ShadcnColors.border),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13),
                          cursorColor: ShadcnColors.foreground,
                          decoration: InputDecoration(
                            hintText: 'Поиск ${_currentSectionLabel.toLowerCase()}...',
                            hintStyle: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12),
                            icon: const Icon(Icons.search, color: ShadcnColors.mutedForeground, size: 18),
                            border: InputBorder.none,
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: ShadcnColors.mutedForeground, size: 16),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      catalog.filters.searchQuery = '';
                                      catalog.loadCatalog(libraryProvider: library);
                                    },
                                  )
                                : null,
                          ),
                          onSubmitted: (val) {
                            catalog.filters.searchQuery = val;
                            catalog.loadCatalog(libraryProvider: library);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Кнопка фильтров
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openFilters(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                color: activeFilterCount > 0 ? ShadcnColors.primary : ShadcnColors.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: activeFilterCount > 0 ? ShadcnColors.primary : ShadcnColors.border,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.tune,
                                color: activeFilterCount > 0
                                    ? ShadcnColors.primaryForeground
                                    : ShadcnColors.foreground,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        if (activeFilterCount > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: ShadcnColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$activeFilterCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Быстрый горизонтальный скролл фильтров (Популярное, Новое, Рейтинг, Главы, Просмотры)
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildQuickChip(
                      label: '🔥 Популярное',
                      isSelected: catalog.filters.ordering == '-rating' && catalog.filters.statusFilter == null,
                      onTap: () {
                        catalog.filters.ordering = '-rating';
                        catalog.filters.statusFilter = null;
                        catalog.loadCatalog(libraryProvider: library);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildQuickChip(
                      label: '✨ Новинки',
                      isSelected: catalog.filters.ordering == '-id',
                      onTap: () {
                        catalog.filters.ordering = '-id';
                        catalog.filters.statusFilter = null;
                        catalog.loadCatalog(libraryProvider: library);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildQuickChip(
                      label: '📖 По главам',
                      isSelected: catalog.filters.ordering == '-count_chapters',
                      onTap: () {
                        catalog.filters.ordering = '-count_chapters';
                        catalog.filters.statusFilter = null;
                        catalog.loadCatalog(libraryProvider: library);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildQuickChip(
                      label: '👁 Просмотры',
                      isSelected: catalog.filters.ordering == '-total_views',
                      onTap: () {
                        catalog.filters.ordering = '-total_views';
                        catalog.filters.statusFilter = null;
                        catalog.loadCatalog(libraryProvider: library);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildQuickChip(
                      label: '⚡ Онгоинги',
                      isSelected: catalog.filters.statusFilter == 'ongoing',
                      onTap: () {
                        catalog.filters.statusFilter = catalog.filters.statusFilter == 'ongoing' ? null : 'ongoing';
                        catalog.applyLocalFilters(library);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildQuickChip(
                      label: '✅ Завершенные',
                      isSelected: catalog.filters.statusFilter == 'completed',
                      onTap: () {
                        catalog.filters.statusFilter = catalog.filters.statusFilter == 'completed' ? null : 'completed';
                        catalog.applyLocalFilters(library);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Сетка манги
              Expanded(
                child: catalog.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: ShadcnColors.primary,
                          strokeWidth: 2,
                        ),
                      )
                    : catalog.mangaList.isEmpty
                        ? _buildEmptyState(catalog, library)
                        : RefreshIndicator(
                            color: ShadcnColors.foreground,
                            backgroundColor: ShadcnColors.card,
                            onRefresh: () => catalog.loadCatalog(libraryProvider: library),
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.65,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: catalog.mangaList.length,
                              itemBuilder: (context, index) {
                                final manga = catalog.mangaList[index];
                                final status = library.getStatus(manga.id);

                                return MangaCard(
                                  manga: manga,
                                  libraryStatus: status,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MangaDetailScreen(manga: manga),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ShadcnColors.primary : ShadcnColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? ShadcnColors.primary : ShadcnColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? ShadcnColors.primaryForeground : ShadcnColors.foreground,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(CatalogProvider catalog, LibraryProvider library) {
    final hasExclusions = catalog.filters.readingStatus == FilterTriState.exclude ||
        catalog.filters.completedStatus == FilterTriState.exclude;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ShadcnColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: ShadcnColors.border),
              ),
              child: const Icon(Icons.search_off, size: 36, color: ShadcnColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ничего не найдено',
              style: TextStyle(
                color: ShadcnColors.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasExclusions
                  ? 'Возможно, подходящие тайтлы скрыты вашими фильтрами исключения («Читаю» или «Прочитано»).'
                  : 'Попробуйте изменить запрос или сбросить фильтры.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ShadcnColors.mutedForeground,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            ShadcnButton(
              text: 'Сбросить фильтры',
              variant: ButtonVariant.outline,
              onPressed: () {
                catalog.filters.reset();
                catalog.loadCatalog(libraryProvider: library);
              },
            ),
          ],
        ),
      ),
    );
  }
}
