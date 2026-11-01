import 'package:flutter/material.dart';
import '../../../../core/theme/shadcn_colors.dart';
import '../../services/novel_repository.dart';
import '../../models/novel_chapter.dart';
import '../novel_reader_screen.dart';

class NovelChooserSheet extends StatefulWidget {
  final String mangaId;
  final String mangaTitle;

  const NovelChooserSheet({
    super.key,
    required this.mangaId,
    required this.mangaTitle,
  });

  static Future<void> show(BuildContext context, {required String mangaId, required String mangaTitle}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NovelChooserSheet(mangaId: mangaId, mangaTitle: mangaTitle),
    );
  }

  @override
  State<NovelChooserSheet> createState() => _NovelChooserSheetState();
}

class _NovelChooserSheetState extends State<NovelChooserSheet> {
  final NovelRepository _repo = NovelRepository();
  NovelBook? _matchedBook;
  List<NovelBook> _allBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final matched = await _repo.findNovelForManga(widget.mangaId, widget.mangaTitle);
    final all = await _repo.getAllNovels();
    if (mounted) {
      setState(() {
        _matchedBook = matched;
        _allBooks = all;
        _isLoading = false;
      });
    }
  }

  void _openReader(NovelBook book, NovelChapter chapter) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelReaderScreen(
          novelTitle: book.title,
          chapter: chapter,
        ),
      ),
    );
  }

  void _showAddCustomBookDialog() {
    final titleCtrl = TextEditingController(text: widget.mangaTitle);
    final authorCtrl = TextEditingController();
    final chapterTitleCtrl = TextEditingController(text: 'Глава 1');
    final contentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ShadcnColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Добавить свою книгу / ранобэ', style: TextStyle(color: ShadcnColors.foreground, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Название произведения',
                  labelStyle: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: authorCtrl,
                style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Автор (необязательно)',
                  labelStyle: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: chapterTitleCtrl,
                style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Название главы',
                  labelStyle: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Вставьте текст книги или главы сюда...',
                  hintStyle: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Отмена'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ShadcnColors.primary,
              foregroundColor: ShadcnColors.primaryForeground,
            ),
            child: const Text('Сохранить и читать'),
            onPressed: () async {
              if (contentCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пожалуйста, вставьте текст главы')),
                );
                return;
              }
              await _repo.addCustomNovel(
                title: titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : 'Моя книга',
                author: authorCtrl.text.trim(),
                chapterTitle: chapterTitleCtrl.text.trim(),
                content: contentCtrl.text.trim(),
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFA121215),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: ShadcnColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Верхняя полоска
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
                      const Row(
                        children: [
                          Icon(Icons.menu_book, color: ShadcnColors.accent, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Ранобэ и Книги',
                            style: TextStyle(
                              color: ShadcnColors.foreground,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

            const Divider(color: ShadcnColors.border, height: 1),

            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: ShadcnColors.primary, strokeWidth: 2),
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  children: [
                    // Если найдено соответствие для текущего тайтла манги
                    if (_matchedBook != null) ...[
                      _buildBookCard(_matchedBook!, isPrimary: true),
                      const SizedBox(height: 24),
                    ],

                    // Кнопка добавления своего файла/текста
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ShadcnColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ShadcnColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: ShadcnColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ShadcnColors.border),
                            ),
                            child: const Icon(Icons.add, color: ShadcnColors.foreground, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Добавить свою книгу / текст',
                                  style: TextStyle(
                                    color: ShadcnColors.foreground,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Вставьте текст любой книги или новеллы',
                                  style: TextStyle(
                                    color: ShadcnColors.mutedForeground,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ShadcnColors.surface,
                              foregroundColor: ShadcnColors.foreground,
                              elevation: 0,
                              side: const BorderSide(color: ShadcnColors.border),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _showAddCustomBookDialog,
                            child: const Text('Добавить', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Раздел других доступных ранобэ в библиотеке
                    const Text(
                      'Популярные ранобэ и новеллы',
                      style: TextStyle(
                        color: ShadcnColors.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),

                    ..._allBooks.where((b) => _matchedBook == null || b.id != _matchedBook!.id).map((book) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildBookCard(book, isPrimary: false),
                        )),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard(NovelBook book, {required bool isPrimary}) {
    return Container(
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0x1F3B82F6) : ShadcnColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary ? ShadcnColors.accent : ShadcnColors.border,
          width: isPrimary ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 56,
                decoration: BoxDecoration(
                  color: ShadcnColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ShadcnColors.border),
                ),
                child: const Icon(Icons.auto_stories, color: ShadcnColors.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isPrimary)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x333B82F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ПЕРВОИСТОЧНИК К ЭТОМУ ТАЙТЛУ',
                          style: TextStyle(color: ShadcnColors.accent, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    Text(
                      book.title,
                      style: const TextStyle(
                        color: ShadcnColors.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Автор: ${book.author} • ${book.chapters.length} глав',
                      style: const TextStyle(
                        color: ShadcnColors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            book.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ShadcnColors.mutedForeground,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: ShadcnColors.border),
          const SizedBox(height: 6),
          const Text(
            'Главы новеллы:',
            style: TextStyle(
              color: ShadcnColors.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...book.chapters.map((ch) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: ShadcnColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ShadcnColors.border),
                ),
                child: ListTile(
                  dense: true,
                  title: Text(
                    ch.title,
                    style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Читать', style: TextStyle(color: ShadcnColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, color: ShadcnColors.accent, size: 12),
                    ],
                  ),
                  onTap: () => _openReader(book, ch),
                ),
              )),
        ],
      ),
    );
  }
}
