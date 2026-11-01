import 'package:flutter/material.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../services/novel_repository.dart';
import '../screens/novel_reader_screen.dart';

class RanobeCatalogScreen extends StatefulWidget {
  const RanobeCatalogScreen({super.key});

  @override
  State<RanobeCatalogScreen> createState() => _RanobeCatalogScreenState();
}

class _RanobeCatalogScreenState extends State<RanobeCatalogScreen> {
  final NovelRepository _repo = NovelRepository();
  final TextEditingController _searchCtrl = TextEditingController();
  List<NovelBook> _novels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNovels();
  }

  Future<void> _loadNovels() async {
    setState(() => _isLoading = true);
    final all = await _repo.getAllNovels();
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? all
        : all.where((b) => b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q)).toList();

    if (mounted) {
      setState(() {
        _novels = filtered;
        _isLoading = false;
      });
    }
  }

  void _showNovelChapters(NovelBook book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        decoration: const BoxDecoration(
          color: Color(0xFA121215),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: ShadcnColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: ShadcnColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 70,
                        height: 95,
                        decoration: BoxDecoration(
                          color: ShadcnColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ShadcnColors.border),
                        ),
                        child: const Icon(Icons.auto_stories, color: Color(0xFFE11D48), size: 36),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(book.title, style: const TextStyle(color: ShadcnColors.foreground, fontSize: 17, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(book.author, style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0x22E11D48), borderRadius: BorderRadius.circular(6)),
                              child: Text('Ранобэ • ${book.chapters.length} глав', style: const TextStyle(color: Color(0xFFE11D48), fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Описание', style: TextStyle(color: ShadcnColors.foreground, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(book.description, style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 18),
                  const Text('Главы новеллы', style: TextStyle(color: ShadcnColors.foreground, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  ...book.chapters.map((ch) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: ShadcnColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: ShadcnColors.border)),
                        child: ListTile(
                          title: Text(ch.title, style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13, fontWeight: FontWeight.w500)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: ShadcnColors.accent, size: 13),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NovelReaderScreen(novelTitle: book.title, chapter: ch),
                              ),
                            );
                          },
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Поиск
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: ShadcnColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ShadcnColors.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: ShadcnColors.foreground, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Поиск ранобэ, новеллы...',
                hintStyle: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 14),
                icon: const Icon(Icons.search, color: ShadcnColors.mutedForeground, size: 20),
                border: InputBorder.none,
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: ShadcnColors.mutedForeground, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadNovels();
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _loadNovels(),
            ),
          ),
        ),

        // Список ранобэ
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: ShadcnColors.primary, strokeWidth: 2))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: _novels.length,
                  itemBuilder: (context, index) {
                    final novel = _novels[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: ShadcnColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ShadcnColors.border),
                      ),
                      child: InkWell(
                        onTap: () => _showNovelChapters(novel),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 55,
                                height: 75,
                                decoration: BoxDecoration(
                                  color: ShadcnColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: ShadcnColors.border),
                                ),
                                child: const Icon(Icons.auto_stories, color: Color(0xFFE11D48), size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      novel.title,
                                      style: const TextStyle(color: ShadcnColors.foreground, fontSize: 15, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      novel.author,
                                      style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0x22E11D48), borderRadius: BorderRadius.circular(4)),
                                          child: Text('${novel.chapters.length} глав', style: const TextStyle(color: Color(0xFFE11D48), fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('Лайт-новелла', style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 11)),
                                      ],
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
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _showNovelChapters(novel),
                                child: const Text('Главы', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
