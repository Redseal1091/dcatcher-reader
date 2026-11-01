import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/shadcn_colors.dart';
import '../../../../core/widgets/shadcn_badge.dart';
import '../../models/manga.dart';
import '../../../library/models/library_item.dart';

class MangaCard extends StatelessWidget {
  final Manga manga;
  final UserMangaStatus? libraryStatus;
  final VoidCallback onTap;

  const MangaCard({
    super.key,
    required this.manga,
    this.libraryStatus,
    required this.onTap,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Закончен':
        return const Color(0xFF10B981); // Emerald
      case 'Заморожен':
        return const Color(0xFFF59E0B); // Amber
      case 'Онгоинг':
      default:
        return const Color(0xFF38BDF8); // Sky blue
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(manga.statusLabel);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: ShadcnColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ShadcnColors.border, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Обложка с бейджами типа, статуса и рейтинга
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: manga.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: ShadcnColors.surface,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ShadcnColors.border,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, err) => Container(
                        color: ShadcnColors.surface,
                        child: const Center(
                          child: Icon(Icons.broken_image, color: ShadcnColors.mutedForeground),
                        ),
                      ),
                    ),

                    // Градиентное затемнение снизу
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            stops: const [0.55, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Бейдж типа (Манхва / Манга / Маньхуа)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xEB121215),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: ShadcnColors.border),
                        ),
                        child: Text(
                          manga.typeLabel,
                          style: const TextStyle(
                            color: ShadcnColors.foreground,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    // Бейдж Лицензировано или возраст
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (manga.isLicensed)
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0x33EF4444),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0x88EF4444)),
                              ),
                              child: const Text(
                                'Лицензия',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (manga.contentRating != ContentRating.safe)
                            ShadcnBadge(
                              label: manga.ratingLabel,
                              variant: BadgeVariant.rating,
                            ),
                        ],
                      ),
                    ),

                    // Статус в личной библиотеке (Читаю / Прочитано)
                    if (libraryStatus != null)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: _buildLibraryStatusBadge(libraryStatus!),
                      ),

                    // Количество глав внизу справа обложки
                    if (manga.totalChapters > 0)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xDD000000),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${manga.totalChapters} гл.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Название (увеличенный читабельный текст), статус и жанры
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Крупный заголовок
                    Text(
                      manga.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ShadcnColors.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Статус (Онгоинг/Закончен/Заморожен) + Жанр
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          manga.statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('•', style: TextStyle(color: ShadcnColors.border, fontSize: 10)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            manga.genres.isNotEmpty ? manga.genres.first : 'Комикс',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ShadcnColors.mutedForeground,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildLibraryStatusBadge(UserMangaStatus status) {
    switch (status) {
      case UserMangaStatus.reading:
        return const ShadcnBadge(
          label: 'Читаю',
          variant: BadgeVariant.reading,
          icon: Icons.auto_stories,
        );
      case UserMangaStatus.completed:
        return const ShadcnBadge(
          label: 'Прочитано',
          variant: BadgeVariant.completed,
          icon: Icons.check_circle,
        );
      case UserMangaStatus.planned:
        return const ShadcnBadge(
          label: 'В планах',
          variant: BadgeVariant.planned,
          icon: Icons.bookmark,
        );
      case UserMangaStatus.dropped:
        return const ShadcnBadge(
          label: 'Брошено',
          variant: BadgeVariant.destructive,
          icon: Icons.close,
        );
    }
  }
}
