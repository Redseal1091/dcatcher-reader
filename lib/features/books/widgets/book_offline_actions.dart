import 'package:flutter/material.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../models/book_item.dart';
import '../services/books_repository.dart';

class BookOfflineActions extends StatefulWidget {
  final BookItem book;
  final BooksRepository repository;
  final Future<List<BookChapter>> Function() loadChapters;
  final VoidCallback onRemoved;

  const BookOfflineActions({
    super.key,
    required this.book,
    required this.repository,
    required this.loadChapters,
    required this.onRemoved,
  });

  @override
  State<BookOfflineActions> createState() => _BookOfflineActionsState();
}

class _BookOfflineActionsState extends State<BookOfflineActions> {
  bool _isDownloaded = false;
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    if (widget.book.isPdfOnly && widget.book.chapters.isEmpty) {
      _isLoading = false;
      return;
    }
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final downloaded = await widget.repository.isBookDownloaded(widget.book.id);
    if (!mounted) return;
    setState(() {
      _isDownloaded = downloaded;
      _isLoading = false;
    });
  }

  Future<void> _saveOffline() async {
    if (_isBusy || _isDownloaded) return;
    if (widget.book.isPdfOnly && widget.book.chapters.isEmpty) return;

    setState(() => _isBusy = true);
    try {
      final chapters = await widget.loadChapters();
      await widget.repository.saveBookOffline(widget.book, chapters: chapters);
      if (!mounted) return;
      setState(() {
        _isDownloaded = true;
        _isBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить книгу: $e')),
      );
    }
  }

  Future<void> _removeOffline() async {
    if (_isBusy || !_isDownloaded) return;

    setState(() => _isBusy = true);
    try {
      await widget.repository.removeBookOffline(widget.book.id);
      if (!mounted) return;
      setState(() {
        _isDownloaded = false;
        _isBusy = false;
      });
      widget.onRemoved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить книгу: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.book.isPdfOnly && widget.book.chapters.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const SizedBox(
        height: 38,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_isDownloaded) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x2210B981),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 16),
                SizedBox(width: 6),
                Text(
                  'Скачано',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: _isBusy ? null : _removeOffline,
              icon: _isBusy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                    )
                  : const Icon(Icons.delete_outline, size: 16),
              label: const Text(
                'Удалить с устройства',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: ShadcnColors.primary,
          foregroundColor: ShadcnColors.primaryForeground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onPressed: _isBusy ? null : _saveOffline,
        icon: _isBusy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ShadcnColors.primaryForeground,
                ),
              )
            : const Icon(Icons.download, size: 16),
        label: const Text(
          'Сохранить офлайн',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
