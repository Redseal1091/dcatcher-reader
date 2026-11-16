import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../../../core/widgets/shadcn_badge.dart';
import '../../../core/widgets/shadcn_button.dart';
import '../../sources/source_manager.dart';
import '../models/bridge_dtos.dart';
import '../models/keiyoushi_extension.dart';
import '../services/keiyoushi_repository.dart';
import '../services/native_extensions_bridge.dart';

class ExtensionsScreen extends StatefulWidget {
  final KeiyoushiRepository? repository;
  final NativeExtensionsBridge? bridge;

  const ExtensionsScreen({
    super.key,
    this.repository,
    this.bridge,
  });

  @override
  State<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends State<ExtensionsScreen> {
  late final KeiyoushiRepository _repository;
  late final NativeExtensionsBridge _bridge;

  bool _isLoading = true;
  String? _errorMessage;

  List<KeiyoushiExtension> _allExtensions = [];
  final Map<String, NativePackageDto> _installedMap = {};
  final Map<String, double> _installingProgress = {};
  final Map<String, String> _installErrors = {};
  final Map<String, StreamSubscription<ExtensionInstallProgress>> _progressSubscriptions = {};

  String _searchQuery = '';
  String _selectedLanguage = 'all';
  bool _includeNsfw = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? KeiyoushiRepository();
    _bridge = widget.bridge ?? NativeExtensionsBridge();
    _loadData();
  }

  @override
  void dispose() {
    for (final sub in _progressSubscriptions.values) {
      sub.cancel();
    }
    _progressSubscriptions.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    List<KeiyoushiExtension> storeExtensions = [];
    String? storeError;

    // 1. Fetch available store extensions (gracefully handled on offline/failure)
    try {
      storeExtensions = await _repository.fetchExtensions();
    } catch (e) {
      storeError = e.toString();
      debugPrint('Store fetch error: $e');
    }

    // 2. Query native installed packages from bridge
    _installedMap.clear();
    List<NativePackageDto> installedList = [];
    if (_bridge.isSupported) {
      try {
        installedList = await _bridge.listInstalled();
        for (final pkg in installedList) {
          _installedMap[pkg.packageName] = pkg;
        }
        await _repository.rehydrateFromNativePackages(
          installedList,
          availableRepoExtensions: storeExtensions.isNotEmpty ? storeExtensions : null,
        );
      } catch (e) {
        debugPrint('Error loading native installed packages: $e');
      }
    }

    // 3. Update dynamic SourceManager
    final installedExtensions = await _repository.getInstalledExtensions();
    await SourceManager.updateFromExtensions(installedExtensions, bridge: _bridge);

    // If store fetch failed, still show native installed extensions rather than blocking the UI!
    final displayExtensions = storeExtensions.isNotEmpty
        ? storeExtensions
        : installedExtensions;

    setState(() {
      _allExtensions = displayExtensions;
      _isLoading = false;
      _errorMessage = (storeExtensions.isEmpty && installedExtensions.isEmpty) ? storeError : null;
    });
  }

  List<KeiyoushiExtension> get _filteredExtensions {
    return _allExtensions.where((ext) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = ext.name.toLowerCase().contains(query);
        final matchPkg = ext.packageName.toLowerCase().contains(query);
        final matchSource = ext.sources.any((s) => s.name.toLowerCase().contains(query));
        if (!matchName && !matchPkg && !matchSource) return false;
      }

      // NSFW filter
      if (!_includeNsfw && ext.isNsfw) {
        return false;
      }

      // Language filter
      if (_selectedLanguage != 'all') {
        final hasLang = ext.sources.any((s) {
          final lang = s.language.toLowerCase();
          return lang == 'all' || lang == _selectedLanguage.toLowerCase();
        });
        if (!hasLang) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _confirmAndInstall(KeiyoushiExtension ext) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ShadcnColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text('Подтверждение доверия', style: TextStyle(color: ShadcnColors.foreground, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Вы собираетесь установить стороннее расширение «${ext.name}» (${ext.packageName}).',
              style: const TextStyle(color: ShadcnColors.foreground, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Сторонний код выполняется на вашем устройстве с доступом к сети. Убедитесь, что вы доверяете источнику Keiyoushi.',
              style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'Сертификат: ${KeiyoushiRepository.trustedCertificateFingerprint.substring(0, 16)}...',
              style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: ShadcnColors.mutedForeground)),
          ),
          ShadcnButton(
            text: 'Доверяю и установить',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _executeInstall(ext);
    }
  }

  Future<void> _executeInstall(KeiyoushiExtension ext) async {
    setState(() {
      _installingProgress[ext.packageName] = 0.0;
      _installErrors.remove(ext.packageName);
    });

    // Listen to progress events from native EventChannel
    _progressSubscriptions[ext.packageName]?.cancel();
    _progressSubscriptions[ext.packageName] = _bridge.watchInstallProgress(ext.packageName).listen((progress) {
      if (mounted) {
        setState(() {
          _installingProgress[ext.packageName] = progress.fraction;
        });
      }
    });

    try {
      final success = await _bridge.install(
        packageName: ext.packageName,
        apkUrl: ext.apkUrl,
        versionCode: ext.versionCode,
        trustConfirmed: true,
      );

      if (success) {
        // Query actual native loaded sources from native bridge (do not synthesize from catalog)
        final actualInstalledList = await _bridge.listInstalled();
        _installedMap.clear();
        for (final pkg in actualInstalledList) {
          _installedMap[pkg.packageName] = pkg;
        }

        // Rehydrate repository from actual DTOs
        await _repository.rehydrateFromNativePackages(
          actualInstalledList,
          availableRepoExtensions: _allExtensions,
        );

        final actualExtensions = await _repository.getInstalledExtensions();
        await SourceManager.updateFromExtensions(actualExtensions, bridge: _bridge);
      } else {
        _installErrors[ext.packageName] = 'Нативная установка не завершена';
      }
    } catch (e) {
      _installErrors[ext.packageName] = e.toString();
    } finally {
      _progressSubscriptions[ext.packageName]?.cancel();
      _progressSubscriptions.remove(ext.packageName);
      if (mounted) {
        setState(() {
          _installingProgress.remove(ext.packageName);
        });
      }
    }
  }

  Future<void> _uninstall(KeiyoushiExtension ext) async {
    try {
      final success = await _bridge.uninstall(ext.packageName);
      if (success) {
        // Query actual native loaded sources after uninstall
        final actualInstalledList = await _bridge.listInstalled();
        _installedMap.clear();
        for (final pkg in actualInstalledList) {
          _installedMap[pkg.packageName] = pkg;
        }

        await _repository.rehydrateFromNativePackages(
          actualInstalledList,
          availableRepoExtensions: _allExtensions,
        );

        final actualExtensions = await _repository.getInstalledExtensions();
        await SourceManager.updateFromExtensions(actualExtensions, bridge: _bridge);

        if (mounted) {
          setState(() {});
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Удаление отклонено нативным модулем')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при удалении: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShadcnColors.background,
      appBar: AppBar(
        title: const Text('Каталог расширений Keiyoushi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Обновить',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Platform compatibility banner for Web/Desktop
          if (!_bridge.isSupported)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.amber, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Выполнение нативных расширений Keiyoushi доступно на Android. На Web и Desktop загрузка APK недоступна.',
                      style: TextStyle(color: ShadcnColors.foreground, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Search and Filters Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              style: const TextStyle(color: ShadcnColors.foreground, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Поиск расширений или источников...',
                hintStyle: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: ShadcnColors.mutedForeground, size: 20),
                filled: true,
                fillColor: ShadcnColors.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: ShadcnColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: ShadcnColors.border),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('Все языки', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Русский (RU)', 'ru'),
                const SizedBox(width: 8),
                _buildFilterChip('English (EN)', 'en'),
                const SizedBox(width: 12),
                FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _includeNsfw ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        size: 14,
                        color: _includeNsfw ? Colors.redAccent : ShadcnColors.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Text('18+ (NSFW)', style: TextStyle(color: _includeNsfw ? Colors.redAccent : ShadcnColors.mutedForeground, fontSize: 12)),
                    ],
                  ),
                  selected: _includeNsfw,
                  selectedColor: Colors.redAccent.withValues(alpha: 0.15),
                  backgroundColor: ShadcnColors.card,
                  side: BorderSide(color: _includeNsfw ? Colors.redAccent : ShadcnColors.border),
                  onSelected: (val) => setState(() => _includeNsfw = val),
                ),
              ],
            ),
          ),

          const Divider(color: ShadcnColors.border, height: 16),

          // Extensions List
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String code) {
    final isSelected = _selectedLanguage == code;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? ShadcnColors.primaryForeground : ShadcnColors.mutedForeground)),
      selected: isSelected,
      selectedColor: ShadcnColors.primary,
      backgroundColor: ShadcnColors.card,
      side: const BorderSide(color: ShadcnColors.border),
      onSelected: (val) {
        if (val) setState(() => _selectedLanguage = code);
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text(
                'Ошибка загрузки каталога расширений:\n$_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ShadcnButton(
                text: 'Повторить',
                onPressed: _loadData,
              ),
            ],
          ),
        ),
      );
    }

    final extensions = _filteredExtensions;
    if (extensions.isEmpty) {
      return const Center(
        child: Text(
          'Расширения не найдены',
          style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: extensions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final ext = extensions[index];
        final isInstalled = _installedMap.containsKey(ext.packageName);
        final installProgress = _installingProgress[ext.packageName];
        final isInstalling = installProgress != null;
        final error = _installErrors[ext.packageName];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ShadcnColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ShadcnColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ext.iconUrl.isNotEmpty
                        ? Image.network(
                            ext.iconUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildFallbackIcon(),
                          )
                        : _buildFallbackIcon(),
                  ),
                  const SizedBox(width: 12),
                  // Name and metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ext.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: ShadcnColors.foreground, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'v${ext.versionName} (${ext.versionCode}) • Lib ${ext.extensionLib}',
                          style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (ext.isNsfw)
                              const ShadcnBadge(label: '18+', variant: BadgeVariant.destructive),
                            ..._sourceBadges(ext),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Action button
                  if (isInstalling)
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        value: installProgress > 0 ? installProgress : null,
                        strokeWidth: 3,
                      ),
                    )
                  else if (isInstalled)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                      tooltip: 'Удалить расширение',
                      onPressed: () => _uninstall(ext),
                    )
                  else
                    ShadcnButton(
                      text: 'Установить',
                      variant: ButtonVariant.secondary,
                      onPressed: _bridge.isSupported ? () => _confirmAndInstall(ext) : null,
                    ),
                ],
              ),

              // Linear progress indicator while downloading/installing
              if (isInstalling) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: installProgress > 0 ? installProgress : null,
                  backgroundColor: ShadcnColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(ShadcnColors.primary),
                ),
              ],

              // Error banner with retry
              if (error != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        error,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _confirmAndInstall(ext),
                      child: const Text('Повторить', style: TextStyle(fontSize: 11, color: ShadcnColors.primary)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _sourceBadges(KeiyoushiExtension ext) {
    final filtered = ext.sources.where((s) {
      if (_selectedLanguage == 'all') return true;
      final lang = s.language.toLowerCase();
      return lang == 'all' || lang == _selectedLanguage.toLowerCase();
    }).toList();

    if (filtered.isEmpty) return const [];

    final groups = <String, List<KeiyoushiSource>>{};
    for (final s in filtered) {
      groups.putIfAbsent(s.name, () => []).add(s);
    }

    return groups.entries.map((entry) {
      final name = entry.key;
      final sources = entry.value;

      final upperLangs = <String>{};
      for (final s in sources) {
        upperLangs.add(s.language.toUpperCase());
      }
      final langList = upperLangs.toList();

      String label;
      if (langList.length == 1) {
        label = '$name · ${langList.first}';
      } else if (langList.length <= 2) {
        label = '$name · ${langList.join(', ')}';
      } else {
        final first2 = langList.take(2).join(', ');
        final remaining = langList.length - 2;
        label = '$name · $first2 +$remaining';
      }

      return Tooltip(
        message: langList.join(', '),
        child: ShadcnBadge(
          label: label,
          variant: BadgeVariant.outline,
          flexibleLabel: true,
        ),
      );
    }).toList();
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: ShadcnColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.extension_rounded, color: ShadcnColors.mutedForeground, size: 24),
    );
  }
}
