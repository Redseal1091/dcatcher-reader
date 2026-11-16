import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../extensions/models/keiyoushi_extension.dart';
import '../extensions/services/keiyoushi_repository.dart';
import '../extensions/services/native_extensions_bridge.dart';
import 'extension_manga_source.dart';
import 'manga_source.dart';

class SourceManager {
  static const String _activeSourcePrefKey = 'active_keiyoushi_source_id';

  /// List of currently installed and loaded dynamic extension sources (initially zero)
  static final List<ExtensionMangaSource> _installedSources = [];

  static MangaSource? _currentSource;
  static bool _isInitialized = false;

  static List<ExtensionMangaSource> get sources => List.unmodifiable(_installedSources);

  static MangaSource? get currentSource => _currentSource;

  static bool get hasSources => _installedSources.isNotEmpty;

  static bool get isInitialized => _isInitialized;

  /// Initializes the dynamic source manager from installed Keiyoushi extensions.
  /// Starts with ZERO sources until installed extensions are discovered.
  static Future<void> initialize({
    KeiyoushiRepository? repository,
    NativeExtensionsBridge? bridge,
  }) async {
    final repo = repository ?? KeiyoushiRepository();
    final nativeBridge = bridge ?? NativeExtensionsBridge();

    // Rehydrate from native runtime if supported
    if (nativeBridge.isSupported) {
      try {
        final nativePackages = await nativeBridge.listInstalled();
        await repo.rehydrateFromNativePackages(nativePackages);
      } catch (e) {
        debugPrint('Failed to rehydrate extensions from native bridge: $e');
      }
    }

    final installedExtensions = await repo.getInstalledExtensions();
    await updateFromExtensions(installedExtensions, bridge: nativeBridge);
    _isInitialized = true;
  }

  /// Updates the loaded sources list given a list of installed extensions.
  static Future<void> updateFromExtensions(
    List<KeiyoushiExtension> extensions, {
    NativeExtensionsBridge? bridge,
  }) async {
    final nativeBridge = bridge ?? NativeExtensionsBridge();

    _installedSources.clear();
    final seenIds = <String>{};
    for (final ext in extensions) {
      for (final src in ext.sources) {
        if (seenIds.add(src.id)) {
          _installedSources.add(
            ExtensionMangaSource(
              source: src,
              packageName: ext.packageName,
              bridge: nativeBridge,
            ),
          );
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final savedSourceId = prefs.getString(_activeSourcePrefKey);

    if (savedSourceId != null && _installedSources.any((s) => s.id == savedSourceId)) {
      _currentSource = _installedSources.firstWhere((s) => s.id == savedSourceId);
    } else if (_installedSources.isNotEmpty) {
      _currentSource = _installedSources.first;
      await prefs.setString(_activeSourcePrefKey, _currentSource!.id);
    } else {
      _currentSource = null;
    }
  }

  /// Sets the currently active source.
  /// If the source is found, saves to SharedPreferences.
  /// If not found, does NOT silently fallback to another source.
  static Future<bool> setCurrentSource(String id) async {
    final match = getSourceById(id);
    if (match != null) {
      _currentSource = match;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeSourcePrefKey, match.id);
      return true;
    }
    return false;
  }

  /// Finds a source by ID.
  /// Returns null if not found (strictly no silent default fallback).
  static MangaSource? getSourceById(String id) {
    for (final s in _installedSources) {
      if (s.id == id) {
        return s;
      }
    }
    for (final s in _installedSources) {
      if (s.name.toLowerCase() == id.toLowerCase()) {
        return s;
      }
    }
    return null;
  }

  @visibleForTesting
  static void setMockSources(List<ExtensionMangaSource> mockSources) {
    _installedSources.clear();
    _installedSources.addAll(mockSources);
    _currentSource = mockSources.isNotEmpty ? mockSources.first : null;
  }

  @visibleForTesting
  static void resetForTesting() {
    _installedSources.clear();
    _currentSource = null;
    _isInitialized = false;
  }
}
