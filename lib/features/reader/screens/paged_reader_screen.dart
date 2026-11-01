import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../../../core/widgets/frosted_glass.dart';
import '../../catalog/models/manga.dart';
import '../models/chapter.dart';
import '../../sources/manga_source.dart';
import '../../sources/source_manager.dart';
import '../../library/state/library_provider.dart';

class PagedReaderScreen extends StatefulWidget {
  final Manga manga;
  final Chapter chapter;

  const PagedReaderScreen({
    super.key,
    required this.manga,
    required this.chapter,
  });

  @override
  State<PagedReaderScreen> createState() => _PagedReaderScreenState();
}

class _PagedReaderScreenState extends State<PagedReaderScreen> {
  final MangaSource _source = SourceManager.currentSource;
  List<String> _pageUrls = [];
  bool _isLoading = true;
  bool _showControls = true;
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadPages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final library = context.read<LibraryProvider>();
      library.updateProgress(
        mangaId: widget.manga.id,
        chapterId: widget.chapter.id,
        chapterNumber: widget.chapter.chapterNumber,
        title: widget.manga.title,
        coverUrl: widget.manga.coverUrl,
      );
    });
  }

  Future<void> _loadPages() async {
    final pages = await _source.getChapterPages(widget.chapter.id);
    if (mounted) {
      setState(() {
        _pageUrls = pages;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: ShadcnColors.primary),
            )
          else
            GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: PageView.builder(
                controller: _pageController,
                reverse: true, // Постранично справа-налево (традиционная манга)
                itemCount: _pageUrls.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    maxScale: 3.0,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: _pageUrls[index],
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ShadcnColors.border,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Верхний аппбар
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showControls ? 0 : -90,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: FrostedGlass(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: ShadcnColors.foreground),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.chapter.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ShadcnColors.foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Нижняя плашка с номером страницы
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _showControls ? 20 : -70,
            left: 0,
            right: 0,
            child: Center(
              child: FrostedGlass(
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '${_currentIndex + 1} / ${_pageUrls.length}',
                  style: const TextStyle(
                    color: ShadcnColors.foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
