import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../../../core/widgets/shadcn_badge.dart';
import '../../../core/widgets/shadcn_button.dart';
import '../state/library_provider.dart';
import '../models/library_item.dart';
import '../../catalog/state/catalog_provider.dart';
import '../../catalog/screens/widgets/manga_card.dart';
import '../../catalog/screens/manga_detail_screen.dart';
import '../../download/download_manager.dart';
import 'widgets/downloaded_tab.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DownloadManager _dm = DownloadManager();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final catalog = context.watch<CatalogProvider>();

    // Группировка тайтлов по статусам из каталога
    final readingList = catalog.mangaList.where((m) => library.getStatus(m.id) == UserMangaStatus.reading).toList();
    final completedList = catalog.mangaList.where((m) => library.getStatus(m.id) == UserMangaStatus.completed).toList();
    final plannedList = catalog.mangaList.where((m) => library.getStatus(m.id) == UserMangaStatus.planned).toList();
    final blacklistedMap = library.blacklisted;

    return Scaffold(
      backgroundColor: ShadcnColors.background,
      appBar: AppBar(
        title: const Text('Моя библиотека'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined, color: ShadcnColors.foreground, size: 22),
            tooltip: 'Резервная копия (Бэкап)',
            onPressed: () => _showBackupDialog(context, library),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: ShadcnColors.foreground,
          indicatorWeight: 2,
          dividerColor: ShadcnColors.border,
          labelColor: ShadcnColors.foreground,
          unselectedLabelColor: ShadcnColors.mutedForeground,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(text: 'Читаю (${readingList.length})'),
            ListenableBuilder(
              listenable: _dm,
              builder: (context, _) {
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.download_done_rounded, size: 15, color: Color(0xFF10B981)),
                      const SizedBox(width: 5),
                      Text('Скачанное (${_dm.downloadedCount})'),
                    ],
                  ),
                );
              },
            ),
            Tab(text: 'Прочитано (${completedList.length})'),
            Tab(text: 'В планах (${plannedList.length})'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.block, size: 14, color: ShadcnColors.exclude),
                  const SizedBox(width: 6),
                  Text('Черный список (${blacklistedMap.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMangaGrid(readingList, library),
          const DownloadedTab(),
          _buildMangaGrid(completedList, library),
          _buildMangaGrid(plannedList, library),
          _buildBlacklistTab(blacklistedMap, library),
        ],
      ),
    );
  }

  Widget _buildMangaGrid(List mangaItems, LibraryProvider library) {
    if (mangaItems.isEmpty) {
      return const Center(
        child: Text(
          'В этой вкладке пока пусто',
          style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 14),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: mangaItems.length,
      itemBuilder: (context, index) {
        final manga = mangaItems[index];
        final item = library.getItem(manga.id);

        return Stack(
          children: [
            MangaCard(
              manga: manga,
              libraryStatus: library.getStatus(manga.id),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MangaDetailScreen(manga: manga),
                  ),
                );
              },
            ),
            // Индикатор последней прочитанной главы
            if (item != null && item.lastChapterNumber.isNotEmpty)
              Positioned(
                bottom: 46,
                right: 8,
                child: ShadcnBadge(
                  label: 'Гл. ${item.lastChapterNumber}',
                  variant: BadgeVariant.secondary,
                  icon: Icons.history,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBlacklistTab(Map<String, Map<String, String>> blacklisted, LibraryProvider library) {
    if (blacklisted.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: ShadcnColors.mutedForeground),
              SizedBox(height: 16),
              Text(
                'Черный список пуст',
                style: TextStyle(color: ShadcnColors.foreground, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                'Сюда попадают произведения, для которых вы нажали кнопку «Не показывать».',
                textAlign: TextAlign.center,
                style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final entries = blacklisted.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final mangaId = entry.key;
        final title = entry.value['title'] ?? 'Без названия';
        final coverUrl = entry.value['coverUrl'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ShadcnColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ShadcnColors.border),
          ),
          child: Row(
            children: [
              // Мини-обложка
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: coverUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: coverUrl,
                        width: 44,
                        height: 60,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 44,
                          height: 60,
                          color: ShadcnColors.surface,
                          child: const Icon(Icons.broken_image, size: 18, color: ShadcnColors.mutedForeground),
                        ),
                      )
                    : Container(
                        width: 44,
                        height: 60,
                        color: ShadcnColors.surface,
                        child: const Icon(Icons.menu_book, size: 18, color: ShadcnColors.mutedForeground),
                      ),
              ),
              const SizedBox(width: 14),

              // Название тайтла
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ShadcnColors.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Скрыто из каталога',
                      style: TextStyle(
                        color: ShadcnColors.exclude,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Кнопка вытащить из ЧС (Восстановить в каталог)
              ShadcnButton(
                text: 'Вернуть',
                variant: ButtonVariant.outline,
                icon: Icons.restore,
                onPressed: () {
                  library.removeFromBlacklist(mangaId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('«$title» возвращен в каталог!'),
                      backgroundColor: ShadcnColors.surface,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBackupDialog(BuildContext context, LibraryProvider library) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ShadcnColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ShadcnColors.border),
        ),
        title: const Text(
          'Резервная копия библиотеки',
          style: TextStyle(color: ShadcnColors.foreground, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Вы можете сохранить всю вашу историю чтения, закладки и черный список в текстовый JSON-файл или перенести их на новое устройство.',
              style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16, color: ShadcnColors.foreground),
            label: const Text('Скопировать бэкап', style: TextStyle(color: ShadcnColors.foreground)),
            onPressed: () {
              final json = library.exportBackup();
              Clipboard.setData(ClipboardData(text: json));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Бэкап скопирован в буфер обмена!'),
                  backgroundColor: ShadcnColors.surface,
                ),
              );
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ShadcnColors.primary,
              foregroundColor: ShadcnColors.primaryForeground,
            ),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Закрыть'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }
}
