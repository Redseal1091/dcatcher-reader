import 'package:flutter/material.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../services/source_access_bridge.dart';

enum SourceAccessMenuAction {
  openWebView,
  openSettings,
  checkSession,
  clearCookies,
}

/// Reusable actions button and menu for source authentication, WebView access,
/// settings and session management.
class SourceAccessActions extends StatelessWidget {
  final String sourceId;
  final String sourceName;
  final SourceAccessBridge bridge;
  final Future<void> Function()? onChanged;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final Widget? customTrigger;

  SourceAccessActions({
    super.key,
    required this.sourceId,
    required this.sourceName,
    SourceAccessBridge? bridge,
    this.onChanged,
    this.iconSize = 18.0,
    this.padding = const EdgeInsets.all(8.0),
    this.customTrigger,
  }) : bridge = bridge ?? SourceAccessBridge();

  bool get _isSupported => bridge.isSupported;

  void _showUnsupportedNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Доступ к сайту и настройкам источника поддерживается только на Android.',
          style: TextStyle(color: ShadcnColors.foreground, fontSize: 13),
        ),
        backgroundColor: ShadcnColors.surface,
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _sanitizeErrorMessage(Object error) {
    var msg = error.toString();
    // Native error messages must not leak tokens/sensitive query params
    msg = msg.replaceAll(RegExp(r'(?:token|access_token|auth|key|secret)=([a-zA-Z0-9_\-\.]+)', caseSensitive: false), 'token=***');
    return msg;
  }

  void _showErrorSnackBar(BuildContext context, String title, VoidCallback onRetry) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          title,
          style: const TextStyle(color: ShadcnColors.exclude, fontSize: 13),
        ),
        backgroundColor: ShadcnColors.surface,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Повторить',
          textColor: ShadcnColors.primary,
          onPressed: onRetry,
        ),
      ),
    );
  }

  Future<void> _handleOpenWebView(BuildContext context) async {
    if (!_isSupported) {
      _showUnsupportedNotice(context);
      return;
    }

    try {
      final success = await bridge.openWebView(sourceId);
      if (success && onChanged != null) {
        await onChanged!();
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(
          context,
          'Ошибка открытия сайта: ${_sanitizeErrorMessage(e)}',
          () => _handleOpenWebView(context),
        );
      }
    }
  }

  Future<void> _handleOpenSettings(BuildContext context) async {
    if (!_isSupported) {
      _showUnsupportedNotice(context);
      return;
    }

    try {
      final info = await bridge.getInfo(sourceId);
      if (!info.supportsSettings) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Настройки не поддерживаются для источника "$sourceName".',
                style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13),
              ),
              backgroundColor: ShadcnColors.surface,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final success = await bridge.openSettings(sourceId);
      if (success && onChanged != null) {
        await onChanged!();
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(
          context,
          'Ошибка открытия настроек: ${_sanitizeErrorMessage(e)}',
          () => _handleOpenSettings(context),
        );
      }
    }
  }

  Future<void> _handleCheckSession(BuildContext context) async {
    if (!_isSupported) {
      _showUnsupportedNotice(context);
      return;
    }

    try {
      final info = await bridge.getInfo(sourceId);
      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: ShadcnColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: ShadcnColors.border),
          ),
          title: const Text(
            'Статус сессии источника',
            style: TextStyle(
              color: ShadcnColors.foreground,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Источник: ${info.name.isNotEmpty ? info.name : sourceName}',
                style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Cookies: ${info.hasCookies ? 'есть' : 'нет'}',
                style: TextStyle(
                  color: info.hasCookies ? const Color(0xFF10B981) : ShadcnColors.mutedForeground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Вход проверяется загрузкой контента каталога и глав.',
                style: TextStyle(
                  color: ShadcnColors.mutedForeground,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Закрыть', style: TextStyle(color: ShadcnColors.primary)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(
          context,
          'Ошибка получения статуса: ${_sanitizeErrorMessage(e)}',
          () => _handleCheckSession(context),
        );
      }
    }
  }

  Future<void> _handleClearCookies(BuildContext context) async {
    if (!_isSupported) {
      _showUnsupportedNotice(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: ShadcnColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: ShadcnColors.border),
        ),
        title: const Text(
          'Очистка cookies и кэша сайта',
          style: TextStyle(
            color: ShadcnColors.foreground,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Удалить cookies, хранилище и веб-кэш этого сайта для "$sourceName"?',
              style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cookies, хранилище и веб-кэш этого сайта будут удалены. '
              'Другие домены, библиотека и скачанное не трогаются.',
              style: TextStyle(
                color: ShadcnColors.mutedForeground,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Отмена', style: TextStyle(color: ShadcnColors.mutedForeground)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Очистить', style: TextStyle(color: ShadcnColors.exclude)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await bridge.clearCookies(sourceId, confirmed: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cookies, хранилище и веб-кэш для "$sourceName" очищены.',
              style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13),
            ),
            backgroundColor: ShadcnColors.surface,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      if (onChanged != null) {
        await onChanged!();
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(
          context,
          'Ошибка очистки cookies: ${_sanitizeErrorMessage(e)}',
          () => _handleClearCookies(context),
        );
      }
    }
  }

  void _onMenuSelected(BuildContext context, SourceAccessMenuAction action) {
    switch (action) {
      case SourceAccessMenuAction.openWebView:
        _handleOpenWebView(context);
        break;
      case SourceAccessMenuAction.openSettings:
        _handleOpenSettings(context);
        break;
      case SourceAccessMenuAction.checkSession:
        _handleCheckSession(context);
        break;
      case SourceAccessMenuAction.clearCookies:
        _handleClearCookies(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SourceAccessMenuAction>(
      tooltip: 'Доступ и авторизация источника',
      color: ShadcnColors.card,
      elevation: 4,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: ShadcnColors.border),
      ),
      onSelected: (action) => _onMenuSelected(context, action),
      itemBuilder: (context) => [
        const PopupMenuItem<SourceAccessMenuAction>(
          value: SourceAccessMenuAction.openWebView,
          child: Row(
            children: [
              Icon(Icons.public, color: ShadcnColors.primary, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Войти / открыть сайт',
                  style: TextStyle(color: ShadcnColors.foreground, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<SourceAccessMenuAction>(
          value: SourceAccessMenuAction.openSettings,
          child: Row(
            children: [
              Icon(Icons.settings_outlined, color: ShadcnColors.foreground, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Настройки источника',
                  style: TextStyle(color: ShadcnColors.foreground, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<SourceAccessMenuAction>(
          value: SourceAccessMenuAction.checkSession,
          child: Row(
            children: [
              Icon(Icons.verified_user_outlined, color: ShadcnColors.foreground, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Проверить сессию',
                  style: TextStyle(color: ShadcnColors.foreground, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<SourceAccessMenuAction>(
          value: SourceAccessMenuAction.clearCookies,
          child: Row(
            children: [
              Icon(Icons.cleaning_services_outlined, color: ShadcnColors.exclude, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Очистить cookies сайта',
                  style: TextStyle(color: ShadcnColors.exclude, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
      child: customTrigger ??
          Container(
            padding: padding,
            decoration: BoxDecoration(
              color: ShadcnColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ShadcnColors.border),
            ),
            child: Icon(
              Icons.more_vert,
              color: ShadcnColors.foreground,
              size: iconSize,
            ),
          ),
    );
  }
}
