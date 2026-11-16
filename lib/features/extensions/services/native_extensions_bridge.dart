import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/bridge_dtos.dart';
import '../models/keiyoushi_extension.dart';
import 'keiyoushi_repository.dart';
export 'keiyoushi_repository.dart' show SecurityException;

class NativeExtensionsBridge {
  static const MethodChannel _defaultMethodChannel = MethodChannel('dev.dcatcher/extensions');
  static const EventChannel _defaultEventChannel = EventChannel('dev.dcatcher/extensions/progress');

  final MethodChannel _channel;
  final EventChannel _eventChannel;
  final bool _bypassPlatformCheckForTesting;

  NativeExtensionsBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _channel = methodChannel ?? _defaultMethodChannel,
        _eventChannel = eventChannel ?? _defaultEventChannel,
        _bypassPlatformCheckForTesting = false;

  @visibleForTesting
  NativeExtensionsBridge.forTesting({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _channel = methodChannel ?? _defaultMethodChannel,
        _eventChannel = eventChannel ?? _defaultEventChannel,
        _bypassPlatformCheckForTesting = true;

  bool get isSupported {
    if (_bypassPlatformCheckForTesting) return true;
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  void _ensureSupported() {
    if (!isSupported) {
      throw const UnsupportedPlatformException(
        'Keiyoushi Android extensions are only supported on Android. On Web or desktop platforms, native APK classloading is unavailable.',
      );
    }
  }

  Future<List<NativePackageDto>> listInstalled() async {
    _ensureSupported();
    final result = await _channel.invokeMethod<List<dynamic>>('listInstalled');
    if (result == null) return [];

    return result.map((m) {
      if (m is! Map) {
        throw FormatException('Invalid package item in listInstalled: expected Map, got ${m.runtimeType}');
      }
      return NativePackageDto.fromJson(Map<String, dynamic>.from(m));
    }).toList();
  }

  Future<bool> install({
    required String packageName,
    required String apkUrl,
    required String versionCode,
    required bool trustConfirmed,
  }) async {
    _ensureSupported();
    if (!trustConfirmed) {
      throw const SecurityException(
        'Explicit user trust confirmation is required before installing third-party APK extensions',
      );
    }

    KeiyoushiRepository.validateApkUrl(apkUrl);

    final result = await _channel.invokeMethod<bool>('install', {
      'packageName': packageName,
      'apkUrl': apkUrl,
      'versionCode': versionCode,
      'trustConfirmed': trustConfirmed,
    });
    return result ?? false;
  }

  Future<bool> uninstall(String packageName) async {
    _ensureSupported();
    final result = await _channel.invokeMethod<bool>('uninstall', {
      'packageName': packageName,
    });
    return result ?? false;
  }

  Future<ExtensionCatalogPage> getCatalog({
    required String sourceId,
    int page = 1,
    String? query,
    String? type,
    List<String>? includedGenres,
    List<String>? excludedGenres,
  }) async {
    _ensureSupported();
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getCatalog', {
      'sourceId': sourceId,
      'page': page,
      if (query != null && query.isNotEmpty) 'query': query,
      if (type != null && type.isNotEmpty) 'type': type,
      if (includedGenres != null && includedGenres.isNotEmpty) 'includedGenres': includedGenres,
      if (excludedGenres != null && excludedGenres.isNotEmpty) 'excludedGenres': excludedGenres,
    });

    if (result == null) {
      return const ExtensionCatalogPage(items: [], hasNextPage: false);
    }
    return ExtensionCatalogPage.fromJson(Map<String, dynamic>.from(result));
  }

  Future<ExtensionMangaDetails> getMangaDetails({
    required String sourceId,
    required String mangaUrl,
  }) async {
    _ensureSupported();
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getMangaDetails', {
      'sourceId': sourceId,
      'mangaUrl': mangaUrl,
    });

    if (result == null) {
      throw Exception('Failed to load manga details for source $sourceId at $mangaUrl');
    }
    return ExtensionMangaDetails.fromJson(Map<String, dynamic>.from(result));
  }

  Future<List<ExtensionChapterItem>> getChapters({
    required String sourceId,
    required String mangaUrl,
  }) async {
    _ensureSupported();
    final result = await _channel.invokeMethod<List<dynamic>>('getChapters', {
      'sourceId': sourceId,
      'mangaUrl': mangaUrl,
    });

    if (result == null) return [];
    return result.map((m) {
      if (m is! Map) {
        throw FormatException('Invalid chapter item in getChapters: expected Map, got ${m.runtimeType}');
      }
      return ExtensionChapterItem.fromJson(Map<String, dynamic>.from(m));
    }).toList();
  }

  Future<List<String>> getChapterPages({
    required String sourceId,
    required String chapterUrl,
  }) async {
    _ensureSupported();
    final result = await _channel.invokeMethod<List<dynamic>>('getChapterPages', {
      'sourceId': sourceId,
      'chapterUrl': chapterUrl,
    });

    if (result == null) return [];
    return result.map((e) => e.toString()).toList();
  }

  Future<Uint8List> fetchImage({
    required String sourceId,
    required String url,
  }) async {
    _ensureSupported();
    final result = await _channel.invokeMethod<Uint8List>('fetchImage', {
      'sourceId': sourceId,
      'url': url,
    });

    if (result == null) {
      throw Exception('Failed to fetch image from native source $sourceId: $url');
    }
    return result;
  }

  Future<Map<String, String>> getHeaders({
    required String sourceId,
  }) async {
    _ensureSupported();
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getHeaders', {
      'sourceId': sourceId,
    });

    if (result == null) return {};
    return Map<String, String>.from(result);
  }

  Stream<ExtensionInstallProgress> watchInstallProgress(String packageName) {
    if (!isSupported) {
      return const Stream.empty();
    }

    return _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map && event['packageName'] == packageName)
        .map((event) {
      final map = Map<String, dynamic>.from(event as Map);
      return ExtensionInstallProgress(
        packageName: packageName,
        received: (map['received'] as num?)?.toInt() ?? 0,
        total: (map['total'] as num?)?.toInt() ?? 0,
      );
    });
  }
}
