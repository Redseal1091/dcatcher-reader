import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/keiyoushi_extension.dart';

class SecurityException implements Exception {
  final String message;
  const SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}

abstract class InstalledExtensionsStore {
  Future<List<KeiyoushiExtension>> getInstalledExtensions();
  Future<void> saveInstalledExtension(KeiyoushiExtension extension);
  Future<void> removeInstalledExtension(String packageName);
  Future<bool> isInstalled(String packageName);
}

@visibleForTesting
class MemoryInstalledExtensionsStore implements InstalledExtensionsStore {
  final Map<String, KeiyoushiExtension> _installed = {};

  @override
  Future<List<KeiyoushiExtension>> getInstalledExtensions() async {
    return _installed.values.toList();
  }

  @override
  Future<void> saveInstalledExtension(KeiyoushiExtension extension) async {
    _installed[extension.packageName] = extension;
  }

  @override
  Future<void> removeInstalledExtension(String packageName) async {
    _installed.remove(packageName);
  }

  @override
  Future<bool> isInstalled(String packageName) async {
    return _installed.containsKey(packageName);
  }
}

/// Official native installer backend interface (implemented by MethodChannel bridge on Android)
abstract class ExtensionInstallerBackend {
  Future<List<NativePackageDto>> listInstalledPackages();
  Future<void> installApk(String apkUrl);
  Future<void> uninstallApk(String packageName);
}

@visibleForTesting
class MemoryExtensionInstallerBackend implements ExtensionInstallerBackend {
  final List<NativePackageDto> installedPackages = [];
  bool shouldThrow = false;
  String? errorMessage;

  @override
  Future<List<NativePackageDto>> listInstalledPackages() async => List.unmodifiable(installedPackages);

  @override
  Future<void> installApk(String apkUrl) async {
    if (shouldThrow) {
      throw Exception(errorMessage ?? 'Native installation verification failed');
    }
  }

  @override
  Future<void> uninstallApk(String packageName) async {
    installedPackages.removeWhere((p) => p.packageName == packageName);
  }
}

class KeiyoushiRepository {
  static const String officialRepoUrl =
      'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.json';

  static const String trustedCertificateFingerprint =
      '9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2';

  final InstalledExtensionsStore _installedStore;
  final ExtensionInstallerBackend _installerBackend;
  final http.Client _httpClient;
  final bool _isClientOwned;

  KeiyoushiRepository({
    InstalledExtensionsStore? installedStore,
    ExtensionInstallerBackend? installerBackend,
    http.Client? httpClient,
  })  : _installedStore = installedStore ?? MemoryInstalledExtensionsStore(),
        _installerBackend = installerBackend ?? MemoryExtensionInstallerBackend(),
        _httpClient = httpClient ?? http.Client(),
        _isClientOwned = httpClient == null;

  void dispose() {
    if (_isClientOwned) {
      _httpClient.close();
    }
  }

  static bool isTrustedCertificate(String fingerprint) {
    return fingerprint.trim().toLowerCase() ==
        trustedCertificateFingerprint.toLowerCase();
  }

  static Uri validateApkUrl(String url) {
    if (url.isEmpty) {
      throw const SecurityException('APK URL cannot be empty');
    }

    // Reject raw or encoded path traversal and illegal slashes/backslashes
    final lower = url.toLowerCase();
    if (url.contains(r'\') ||
        lower.contains('%5c') ||
        lower.contains('%2f') ||
        lower.contains('%2e%2e') ||
        url.contains('..')) {
      throw const SecurityException('Illegal path traversal or encoding in APK URL');
    }

    if (url.contains('@')) {
      throw const SecurityException('Embedded user credentials in URL are strictly forbidden');
    }

    final Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      throw SecurityException('Malformed URL: $e');
    }

    if (uri.scheme != 'https') {
      throw SecurityException('Insecure scheme: "${uri.scheme}", only HTTPS is permitted');
    }

    if (uri.hasPort && uri.port != 443) {
      throw SecurityException('Non-standard port ${uri.port} is strictly forbidden');
    }

    if (uri.hasQuery || uri.hasFragment) {
      throw const SecurityException('Query parameters or fragments are strictly forbidden on APK download URLs');
    }

    if (uri.userInfo.isNotEmpty) {
      throw const SecurityException('Embedded user credentials in URL are strictly forbidden');
    }

    // Host spoofing protection: Must strictly equal github.com
    if (uri.host.toLowerCase() != 'github.com') {
      throw SecurityException('Untrusted host: "${uri.host}", only github.com is permitted');
    }

    // Path validation: /keiyoushi/extensions/releases/download/<tag>/<filename>.apk
    final segments = uri.pathSegments;
    if (segments.length != 6 ||
        segments[0].toLowerCase() != 'keiyoushi' ||
        segments[1].toLowerCase() != 'extensions' ||
        segments[2].toLowerCase() != 'releases' ||
        segments[3].toLowerCase() != 'download') {
      throw const SecurityException('URL path must target official keiyoushi/extensions releases');
    }

    final filename = segments[5].toLowerCase();
    if (!filename.endsWith('.apk')) {
      throw const SecurityException('Asset must have a .apk file extension');
    }

    return uri;
  }

  static List<KeiyoushiExtension> parseExtensionsJson(Map<String, dynamic> json) {
    // 1. Validate signingKey against pinned fingerprint
    final signingKey = json['signingKey']?.toString();
    if (signingKey == null || !isTrustedCertificate(signingKey)) {
      throw SecurityException('Untrusted or missing repository signing key: $signingKey');
    }

    // 2. Reject missing or malformed extensionList
    if (!json.containsKey('extensionList') || json['extensionList'] is! Map<String, dynamic>) {
      throw const FormatException('Missing or malformed extensionList in repository index');
    }

    final extList = json['extensionList'] as Map<String, dynamic>;
    if (!extList.containsKey('extensions') || extList['extensions'] is! List) {
      throw const FormatException('Missing or malformed extensions array in extensionList');
    }

    final rawList = extList['extensions'] as List;
    return rawList
        .whereType<Map<String, dynamic>>()
        .map((e) => KeiyoushiExtension.fromJson(e))
        .toList();
  }

  Future<List<KeiyoushiExtension>> fetchExtensions({String? repoUrl}) async {
    final targetUrl = repoUrl ?? officialRepoUrl;
    final uri = Uri.parse(targetUrl);

    // Forbid arbitrary repoUrl override pointing to untrusted domain
    if (uri.scheme != 'https' ||
        (uri.host != 'raw.githubusercontent.com' && uri.host != 'github.com') ||
        !uri.path.startsWith('/keiyoushi/extensions/')) {
      throw SecurityException('Untrusted repository URL: $targetUrl');
    }

    final response = await _httpClient
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Failed to load extension repository: HTTP ${response.statusCode}');
    }

    if (response.bodyBytes.length > 10 * 1024 * 1024) {
      throw const SecurityException('Repository response exceeds maximum allowed size (10MB)');
    }

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return parseExtensionsJson(data);
  }

  Future<List<KeiyoushiExtension>> getInstalledExtensions() async {
    return _installedStore.getInstalledExtensions();
  }

  Future<bool> isInstalled(String packageName) async {
    return _installedStore.isInstalled(packageName);
  }

  /// Real installation method via native backend interface.
  /// Preserves error details on failure for UI retry without swallowing exceptions.
  Future<void> installExtension(KeiyoushiExtension extension) async {
    validateApkUrl(extension.apkUrl);
    // If native installation throws, do NOT catch; let it propagate to UI for retry
    await _installerBackend.installApk(extension.apkUrl);
    await _installedStore.saveInstalledExtension(extension);
  }

  Future<void> uninstallExtension(String packageName) async {
    await _installerBackend.uninstallApk(packageName);
    await _installedStore.removeInstalledExtension(packageName);
  }

  /// Real installer boundary for ad-hoc callback injection.
  /// Preserves error details on failure and propagates exceptions.
  Future<bool> installWithNativeInstaller(
    KeiyoushiExtension extension, {
    required Future<bool> Function(String apkUrl) nativeInstaller,
  }) async {
    validateApkUrl(extension.apkUrl);
    final bool success = await nativeInstaller(extension.apkUrl);
    if (success) {
      await _installedStore.saveInstalledExtension(extension);
      return true;
    }
    return false;
  }

  /// Rehydrate installed extension state from native backend.
  Future<void> rehydrateFromNative({List<KeiyoushiExtension>? availableRepoExtensions}) async {
    final packages = await _installerBackend.listInstalledPackages();
    await rehydrateFromNativePackages(
      packages,
      availableRepoExtensions: availableRepoExtensions,
    );
  }

  /// Rehydrate installed extension state from list of REAL native package DTOs.
  /// Optionally joins verified cached repository metadata, retaining truthful
  /// unknown/empty fields if absent, and NEVER inventing fake versions or URLs.
  Future<void> rehydrateFromNativePackages(
    List<NativePackageDto> nativePackages, {
    List<KeiyoushiExtension>? availableRepoExtensions,
  }) async {
    final current = await _installedStore.getInstalledExtensions();
    final currentPkgs = current.map((e) => e.packageName).toSet();
    final targetPkgMap = {for (final p in nativePackages) p.packageName: p};

    // Remove uninstalled
    for (final pkg in currentPkgs) {
      if (!targetPkgMap.containsKey(pkg)) {
        await _installedStore.removeInstalledExtension(pkg);
      }
    }

    // Map known extensions by packageName for enrichment
    final Map<String, KeiyoushiExtension> knownMap = {
      if (availableRepoExtensions != null)
        for (final ext in availableRepoExtensions) ext.packageName: ext,
    };

    // Add or update from real native DTOs
    for (final nativePkg in nativePackages) {
      final known = knownMap[nativePkg.packageName];
      final extension = nativePkg.toExtension(knownExtension: known);
      await _installedStore.saveInstalledExtension(extension);
    }
  }
}
