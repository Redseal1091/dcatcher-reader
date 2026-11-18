import 'package:flutter/material.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../../../core/widgets/dcatcher_image.dart';
import '../../extensions/services/source_access_bridge.dart';

enum ReaderErrorKind {
  notFound,
  authRequired,
  forbidden,
  generic,
}

/// Shared error and recovery screen for [WebtoonReaderScreen] and [PagedReaderScreen].
///
/// Recognizes HTTP 401/403 authorization/access blocks from sources and offers
/// direct WebView login with automatic reload upon returning.
class ReaderErrorView extends StatefulWidget {
  final String sourceId;
  final String? errorMessage;
  final bool isPagesEmpty;
  final String defaultMessage;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  final SourceAccessBridge? sourceAccessBridge;

  const ReaderErrorView({
    super.key,
    required this.sourceId,
    required this.errorMessage,
    required this.isPagesEmpty,
    required this.defaultMessage,
    required this.onRetry,
    required this.onBack,
    this.sourceAccessBridge,
  });

  static ReaderErrorKind classifyError(String? message, {required bool isPagesEmpty}) {
    final lower = (message ?? '').toLowerCase();
    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        lower.contains('авториз')) {
      return ReaderErrorKind.authRequired;
    }
    if (lower.contains('403') || lower.contains('forbidden')) {
      return ReaderErrorKind.forbidden;
    }
    if (isPagesEmpty && lower.contains('не найдены')) {
      return ReaderErrorKind.notFound;
    }
    return ReaderErrorKind.generic;
  }

  /// Extracts a human-readable error message from a raw `PlatformException(...)` string.
  static String formatRawErrorMessage(String? raw, String fallback) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final match = RegExp(r'^PlatformException\([^,]+,\s*(.+?),\s*null(?:,\s*null)?\)$')
        .firstMatch(raw.trim());
    if (match != null) {
      final inner = match.group(1)?.trim();
      if (inner != null && inner.isNotEmpty) return inner;
    }
    return raw;
  }

  @override
  State<ReaderErrorView> createState() => _ReaderErrorViewState();
}

class _ReaderErrorViewState extends State<ReaderErrorView> {
  late final SourceAccessBridge _bridge;
  bool _openingWebView = false;

  @override
  void initState() {
    super.initState();
    _bridge = widget.sourceAccessBridge ?? SourceAccessBridge();
  }

  Future<void> _openWebViewLogin() async {
    if (_openingWebView) return;
    setState(() => _openingWebView = true);
    try {
      final completed = await _bridge.openWebView(widget.sourceId);
      if (!mounted) return;
      if (completed) {
        widget.onRetry();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось открыть WebView: $e',
            style: const TextStyle(color: ShadcnColors.exclude, fontSize: 13),
          ),
          backgroundColor: ShadcnColors.surface,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingWebView = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = ReaderErrorView.classifyError(
      widget.errorMessage,
      isPagesEmpty: widget.isPagesEmpty,
    );

    final bool canOpenWebView =
        (kind == ReaderErrorKind.authRequired || kind == ReaderErrorKind.forbidden) &&
        DcatcherImage.isExtensionSourceId(widget.sourceId) &&
        _bridge.isSupported;

    final IconData icon;
    final Color iconColor;
    final String title;
    final String description;

    switch (kind) {
      case ReaderErrorKind.authRequired:
        icon = Icons.lock_outline_rounded;
        iconColor = Colors.amber;
        title = 'Требуется авторизация';
        description =
            'Источник ограничил доступ к этой главе (HTTP 401 — например, контент 18+ '
            'или глава только для зарегистрированных пользователей). Войдите в аккаунт '
            'на сайте источника и повторите загрузку.';
      case ReaderErrorKind.forbidden:
        icon = Icons.shield_outlined;
        iconColor = Colors.amber;
        title = 'Доступ ограничен (403)';
        description =
            'Сайт источника отклонил запрос (HTTP 403). Попробуйте открыть сайт через '
            'WebView, пройти проверку или авторизоваться, а затем повторить загрузку.';
      case ReaderErrorKind.notFound:
        icon = Icons.menu_book;
        iconColor = ShadcnColors.mutedForeground;
        title = 'Страницы не найдены';
        description = ReaderErrorView.formatRawErrorMessage(
          widget.errorMessage,
          widget.defaultMessage,
        );
      case ReaderErrorKind.generic:
        icon = Icons.error_outline_rounded;
        iconColor = ShadcnColors.exclude;
        title = 'Ошибка загрузки страниц';
        description = ReaderErrorView.formatRawErrorMessage(
          widget.errorMessage,
          widget.defaultMessage,
        );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ShadcnColors.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ShadcnColors.mutedForeground,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            if (canOpenWebView) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ShadcnColors.primary,
                  foregroundColor: ShadcnColors.primaryForeground,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: _openingWebView ? null : _openWebViewLogin,
                icon: _openingWebView
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.public_rounded, size: 18),
                label: Text(_openingWebView ? 'Открытие...' : 'Войти через WebView'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ShadcnColors.foreground,
                  side: const BorderSide(color: ShadcnColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Повторить попытку'),
              ),
            ] else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ShadcnColors.primary,
                  foregroundColor: ShadcnColors.primaryForeground,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Повторить попытку'),
              ),
            const SizedBox(height: 12),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: ShadcnColors.mutedForeground,
              ),
              onPressed: widget.onBack,
              child: const Text('Назад к списку глав'),
            ),
          ],
        ),
      ),
    );
  }
}
