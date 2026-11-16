import 'package:flutter/material.dart';
import '../../../../core/theme/shadcn_colors.dart';
import '../../../download/download_manager.dart';
import '../../../catalog/models/manga.dart';
import '../../../reader/models/chapter.dart';
import '../../../reader/screens/webtoon_reader_screen.dart';

class DownloadedTab extends StatefulWidget {
  const DownloadedTab({super.key});

  @override
  State<DownloadedTab> createState() => _DownloadedTabState();
}

class _DownloadedTabState extends State<DownloadedTab> {
  final DownloadManager _dm = DownloadManager();
  bool _isSelectionMode = false;
  final Set<String> _selectedChapterIds = {};

  void _openOfflineReader(DownloadedItem item) {
    final fakeManga = Manga(
      id: item.mangaId.isNotEmpty ? item.mangaId : 'offline_${item.chapterId}',
      title: item.mangaTitle,
      description: 'Скачано офлайн',
      coverUrl: item.coverUrl,
      type: PublicationType.manhwa,
      contentRating: ContentRating.safe,
    );

    final fakeChapter = Chapter(
      id: item.chapterId,
      mangaId: fakeManga.id,
      chapterNumber: item.chapterNumber,
      title: 'Глава ${item.chapterNumber}',
      scanlationGroup: 'Офлайн-хранилище',
      publishedAt: item.downloadedAt,
      isPaid: false,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebtoonReaderScreen(
          manga: fakeManga,
          chapter: fakeChapter,
        ),
      ),
    );
  }

  void _toggleSelection(String chapterId) {
    setState(() {
      if (_selectedChapterIds.contains(chapterId)) {
        _selectedChapterIds.remove(chapterId);
        if (_selectedChapterIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedChapterIds.add(chapterId);
      }
    });
  }

  void _selectAll(List<DownloadedItem> items) {
    setState(() {
      if (_selectedChapterIds.length == items.length) {
        _selectedChapterIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedChapterIds.clear();
        _selectedChapterIds.addAll(items.map((i) => i.chapterId));
      }
    });
  }

  Future<void> _confirmAndBatchDelete(BuildContext context, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ShadcnColors.card,
        title: const Text('Удалить выбранные главы?', style: TextStyle(color: ShadcnColors.foreground)),
        content: Text(
          'Вы уверены, что хотите удалить $count ${count == 1 ? 'главу' : (count < 5 ? 'главы' : 'глав')} из памяти устройства?',
          style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('Отмена'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: const Text('Удалить', style: TextStyle(color: ShadcnColors.exclude, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final toDelete = _selectedChapterIds.toList();
      await _dm.batchDelete(toDelete);
      setState(() {
        _selectedChapterIds.clear();
        _isSelectionMode = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Удалено $count глав из памяти'),
            backgroundColor: ShadcnColors.surface,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _dm,
      builder: (context, _) {
        final activeDownloads = _dm.activeDownloads;

        return FutureBuilder<List<DownloadedItem>>(
          future: _dm.getDownloadedItems(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData && activeDownloads.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: ShadcnColors.primary, strokeWidth: 2),
              );
            }

            final items = snapshot.data ?? [];

            // Prune selection if items were deleted externally
            _selectedChapterIds.removeWhere((id) => !items.any((i) => i.chapterId == id));

            if (items.isEmpty && activeDownloads.isEmpty) {
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
                        child: const Icon(
                          Icons.download_for_offline_outlined,
                          size: 36,
                          color: ShadcnColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Нет скачанных глав',
                        style: TextStyle(
                          color: ShadcnColors.foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Скачивайте главы в карточке любого произведения, чтобы читать их в самолёте или без доступа к интернету.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ShadcnColors.mutedForeground,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final totalBytes = items.fold<int>(0, (sum, i) => sum + i.totalSizeBytes);
            final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    // Секция активных загрузок
                    if (activeDownloads.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ShadcnColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ShadcnColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ShadcnColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Загрузка (${activeDownloads.length})',
                                  style: const TextStyle(
                                    color: ShadcnColors.foreground,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            for (final active in activeDownloads) ...[
                              Builder(builder: (ctx) {
                                final progress = _dm.getProgress(active.chapterId);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '${active.mangaTitle} • Гл. ${active.chapterNumber}',
                                              style: const TextStyle(
                                                color: ShadcnColors.foreground,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            '${(progress * 100).toInt()}%',
                                            style: const TextStyle(
                                              color: ShadcnColors.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: progress.clamp(0.0, 1.0),
                                          backgroundColor: ShadcnColors.surface,
                                          valueColor: const AlwaysStoppedAnimation<Color>(ShadcnColors.primary),
                                          minHeight: 4,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Панель статистики и управления выбором
                    if (items.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: ShadcnColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ShadcnColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder_zip_outlined, color: Color(0xFF10B981), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Скачано: ${items.length} глав • $totalMb МБ',
                                style: const TextStyle(
                                  color: ShadcnColors.foreground,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!_isSelectionMode)
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: ShadcnColors.primary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSelectionMode = true;
                                  });
                                },
                                child: const Text('Выбрать'),
                              )
                            else ...[
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: ShadcnColors.mutedForeground,
                                ),
                                onPressed: () => _selectAll(items),
                                child: Text(
                                  _selectedChapterIds.length == items.length ? 'Снять все' : 'Все',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: ShadcnColors.mutedForeground,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSelectionMode = false;
                                    _selectedChapterIds.clear();
                                  });
                                },
                                child: const Text('Отмена', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Список скачанных глав
                      for (final item in items) ...[
                        Builder(builder: (ctx) {
                          final isSelected = _selectedChapterIds.contains(item.chapterId);

                          return InkWell(
                            onTap: _isSelectionMode ? () => _toggleSelection(item.chapterId) : null,
                            onLongPress: () {
                              if (!_isSelectionMode) {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedChapterIds.add(item.chapterId);
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? ShadcnColors.primary.withValues(alpha: 0.1)
                                    : ShadcnColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? ShadcnColors.primary : ShadcnColors.border,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  if (_isSelectionMode)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: Checkbox(
                                        value: isSelected,
                                        activeColor: ShadcnColors.primary,
                                        onChanged: (_) => _toggleSelection(item.chapterId),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: ShadcnColors.surface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: ShadcnColors.border),
                                      ),
                                      child: const Icon(Icons.bookmark_added, color: Color(0xFF10B981), size: 22),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.mangaTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: ShadcnColors.foreground,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Глава ${item.chapterNumber} • ${item.sizeFormatted}',
                                          style: const TextStyle(
                                            color: ShadcnColors.mutedForeground,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_isSelectionMode) ...[
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ShadcnColors.primary,
                                        foregroundColor: ShadcnColors.primaryForeground,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => _openOfflineReader(item),
                                      child: const Text('Читать', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: ShadcnColors.mutedForeground, size: 20),
                                      tooltip: 'Удалить из памяти',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogCtx) => AlertDialog(
                                            backgroundColor: ShadcnColors.card,
                                            title: const Text('Удалить главу?', style: TextStyle(color: ShadcnColors.foreground)),
                                            content: Text(
                                              'Удалить скачанные страницы главы ${item.chapterNumber} тайтла «${item.mangaTitle}»?',
                                              style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                                            ),
                                            actions: [
                                              TextButton(
                                                child: const Text('Отмена'),
                                                onPressed: () => Navigator.pop(dialogCtx, false),
                                              ),
                                              TextButton(
                                                child: const Text('Удалить', style: TextStyle(color: ShadcnColors.exclude)),
                                                onPressed: () => Navigator.pop(dialogCtx, true),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await _dm.deleteDownloadedChapter(item.chapterId);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Глава удалена из памяти'),
                                                backgroundColor: ShadcnColors.surface,
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ],
                ),

                // Плавающая панель пакетного удаления
                if (_isSelectionMode && _selectedChapterIds.isNotEmpty)
                  Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xF018181B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ShadcnColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Выбрано: ${_selectedChapterIds.length}',
                            style: const TextStyle(
                              color: ShadcnColors.foreground,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ShadcnColors.exclude,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _confirmAndBatchDelete(context, _selectedChapterIds.length),
                            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                            label: Text('Удалить (${_selectedChapterIds.length})'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
