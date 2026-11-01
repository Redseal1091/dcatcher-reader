import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/shadcn_colors.dart';
import '../../../../core/widgets/shadcn_badge.dart';
import '../../models/manga.dart';
import '../../../library/models/library_item.dart';

class MangaCard extends StatefulWidget {
  final Manga manga;
  final UserMangaStatus? libraryStatus;
  final VoidCallback onTap;

  const MangaCard({
    super.key,
    required this.manga,
    this.libraryStatus,
    required this.onTap,
  });

  @override
  State<MangaCard> createState() => _MangaCardState();
}

class _MangaCardState extends State<MangaCard> {
  bool _isPressed = false;

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
    final manga = widget.manga;
    final statusColor = _getStatusColor(manga.statusLabel);

    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
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
                        httpHeaders: const {
                          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                          'Referer': 'https://remanga.org/',
                        },
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 200),
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
                            if (manga.contentRating != ContentRating.safe)
                              ShadcnBadge(
                                label: manga.ratingLabel,
                                variant: BadgeVariant.rating,
                              ),
                          ],
                        ),
                      ),

                      // Статус в личной библиотеке (Читаю / Прочитано)
                      if (widget.libraryStatus != null)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: _buildLibraryStatusBadge(widget.libraryStatus!),
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

                // Название, статус и жанры
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
