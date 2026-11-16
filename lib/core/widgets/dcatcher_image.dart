import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../features/sources/source_manager.dart';
import '../../features/sources/extension_manga_source.dart';
import '../theme/shadcn_colors.dart';

class MissingExtensionSourceException implements Exception {
  final String sourceId;
  final String message;
  const MissingExtensionSourceException(this.sourceId, [this.message = 'Расширение источника не установлено']);

  @override
  String toString() => 'MissingExtensionSourceException: $message (sourceId: $sourceId)';
}

/// Centralized image widget that routes Keiyoushi extension images through native
/// [ExtensionMangaSource.fetchImage] bytes (using interceptors, cookies, and Cloudflare bypass),
/// while preserving standard [CachedNetworkImage] for books and non-extension sources.
///
/// Strictly forbids silent fallback to unintercepted HTTP when an extension source is missing.
class DcatcherImage extends StatefulWidget {
  final String imageUrl;
  final String? sourceId;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final Widget Function(BuildContext, String, dynamic, VoidCallback)? errorRetryWidget;
  final Map<String, String>? headers;
  final int? memCacheWidth;

  const DcatcherImage({
    super.key,
    required this.imageUrl,
    this.sourceId,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.errorRetryWidget,
    this.headers,
    this.memCacheWidth,
  });

  /// In-memory LRU cache bounded by total byte budget (32 MB) to prevent full-page OOM
  @visibleForTesting
  static final Map<String, Uint8List> memoryCache = {};
  @visibleForTesting
  static int currentCacheSizeBytes = 0;
  static const int maxCacheSizeBytes = 32 * 1024 * 1024; // 32 MB

  @visibleForTesting
  static void clearCache() {
    memoryCache.clear();
    currentCacheSizeBytes = 0;
  }

  static bool isExtensionSourceId(String? sourceId) {
    if (sourceId == null || sourceId.isEmpty) return false;
    const nonExtensionSources = {
      'books', 'flibusta', 'classic_books', 'local_files',
      'ranobe', 'novels', 'ranobehub', 'rulate',
    };
    final effectiveId = sourceId.contains('::') ? sourceId.split('::').first : sourceId;
    if (nonExtensionSources.contains(effectiveId.toLowerCase())) {
      return false;
    }
    // Keiyoushi 64-bit decimal string IDs or compound IDs
    if (RegExp(r'^\d+$').hasMatch(effectiveId)) {
      return true;
    }
    final source = SourceManager.getSourceById(effectiveId);
    if (source is ExtensionMangaSource) {
      return true;
    }
    return SourceManager.sources.any((s) => s.id == effectiveId);
  }

  @override
  State<DcatcherImage> createState() => _DcatcherImageState();
}

class _DcatcherImageState extends State<DcatcherImage> {
  Uint8List? _imageBytes;
  bool _isLoading = false;
  dynamic _error;

  String? get _effectiveSourceId {
    final sId = widget.sourceId;
    if (sId == null || sId.isEmpty) return null;
    return sId.contains('::') ? sId.split('::').first : sId;
  }

  bool get _isExtension {
    return DcatcherImage.isExtensionSourceId(widget.sourceId);
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant DcatcherImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl || oldWidget.sourceId != widget.sourceId) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) return;

    if (_isExtension) {
      final effectiveId = _effectiveSourceId!;
      final source = SourceManager.getSourceById(effectiveId);

      // Explicit source identity check: if extension source is missing/uninstalled,
      // fail with typed error rather than silently leaking direct unintercepted HTTP requests
      if (source == null || source is! ExtensionMangaSource) {
        setState(() {
          _isLoading = false;
          _error = MissingExtensionSourceException(
            effectiveId,
            'Расширение источника ($effectiveId) не установлено или недоступно',
          );
        });
        return;
      }

      final cacheKey = '$effectiveId::${widget.imageUrl}';
      if (DcatcherImage.memoryCache.containsKey(cacheKey)) {
        setState(() {
          _imageBytes = DcatcherImage.memoryCache[cacheKey];
          _isLoading = false;
          _error = null;
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final bytes = await source.fetchImage(widget.imageUrl).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Превышено время ожидания загрузки страницы (15 сек)'),
        );
        if (!mounted) return;

        if (bytes != null && bytes.isNotEmpty) {
          // LRU byte-budget eviction
          final entryBytes = bytes.lengthInBytes;
          while (DcatcherImage.currentCacheSizeBytes + entryBytes > DcatcherImage.maxCacheSizeBytes &&
              DcatcherImage.memoryCache.isNotEmpty) {
            final oldestKey = DcatcherImage.memoryCache.keys.first;
            final removed = DcatcherImage.memoryCache.remove(oldestKey);
            if (removed != null) {
              DcatcherImage.currentCacheSizeBytes -= removed.lengthInBytes;
            }
          }

          if (entryBytes <= DcatcherImage.maxCacheSizeBytes) {
            DcatcherImage.memoryCache[cacheKey] = bytes;
            DcatcherImage.currentCacheSizeBytes += entryBytes;
          }

          setState(() {
            _imageBytes = bytes;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _error = Exception('Пустой ответ изображения от нативного моста');
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty) {
      return _buildErrorWidget(context, 'Empty image URL');
    }

    if (_isExtension) {
      if (_isLoading) {
        return widget.placeholder != null
            ? widget.placeholder!(context, widget.imageUrl)
            : _buildDefaultPlaceholder();
      }

      if (_error != null || _imageBytes == null) {
        return _buildErrorWidget(context, _error ?? 'Image not available');
      }

      return Image.memory(
        _imageBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: widget.memCacheWidth,
        errorBuilder: (ctx, err, stack) => _buildErrorWidget(ctx, err),
      );
    }

    // Non-extension behavior (Books, novels, standard URLs)
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      httpHeaders: widget.headers,
      memCacheWidth: widget.memCacheWidth,
      placeholder: widget.placeholder != null
          ? (ctx, url) => widget.placeholder!(ctx, url)
          : (ctx, url) => _buildDefaultPlaceholder(),
      errorWidget: widget.errorRetryWidget != null
          ? (ctx, url, err) => widget.errorRetryWidget!(ctx, url, err, () {
              if (mounted) setState(() {});
            })
          : (widget.errorWidget != null
              ? (ctx, url, err) => widget.errorWidget!(ctx, url, err)
              : (ctx, url, err) => _buildErrorWidget(ctx, err)),
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: ShadcnColors.surface,
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: ShadcnColors.border,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, dynamic error) {
    if (widget.errorRetryWidget != null) {
      return widget.errorRetryWidget!(context, widget.imageUrl, error, _loadImage);
    }
    if (widget.errorWidget != null) {
      return widget.errorWidget!(context, widget.imageUrl, error);
    }
    return InkWell(
      onTap: _loadImage,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: widget.width,
        height: widget.height,
        color: ShadcnColors.surface,
        child: const Center(
          child: Icon(Icons.broken_image, color: ShadcnColors.mutedForeground),
        ),
      ),
    );
  }
}
