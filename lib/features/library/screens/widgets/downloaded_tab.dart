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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _dm,
      builder: (context, _) {
        return FutureBuilder<List<DownloadedItem>>(
          future: _dm.getDownloadedItems(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: ShadcnColors.primary, strokeWidth: 2),
              );
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
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

            // Вычисляем общий объем занятой памяти
            final totalBytes = items.fold<int>(0, (sum, i) => sum + i.totalSizeBytes);
            final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        const Icon(Icons.offline_pin, color: Color(0xFF10B981), size: 18),
                      ],
                    ),
                  );
                }

                final item = items[index - 1];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: ShadcnColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ShadcnColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
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
                        const SizedBox(width: 8),

                        // Кнопка Читать
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

                        // Кнопка удалить
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: ShadcnColors.mutedForeground, size: 20),
                          tooltip: 'Удалить из памяти',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: ShadcnColors.card,
                                title: const Text('Удалить главу?', style: TextStyle(color: ShadcnColors.foreground)),
                                content: Text(
                                  'Удалить скачанные страницы главы ${item.chapterNumber} тайтла «${item.mangaTitle}»?',
                                  style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text('Отмена'),
                                    onPressed: () => Navigator.pop(ctx, false),
                                  ),
                                  TextButton(
                                    child: const Text('Удалить', style: TextStyle(color: ShadcnColors.exclude)),
                                    onPressed: () => Navigator.pop(ctx, true),
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
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
