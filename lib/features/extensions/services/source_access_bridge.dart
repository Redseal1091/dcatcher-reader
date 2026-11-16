import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// DTO representing source access capabilities and status.
///
/// Sensitive fields (tokens, cookies, auth headers) are never stored or exposed.
@immutable
class SourceAccessInfo {
  final String sourceId;
  final String name;
  final String homeUrl;
  final bool supportsSettings;
  final bool hasCookies;
  final bool loginVerified;

  const SourceAccessInfo({
    required this.sourceId,
    required this.name,
    required this.homeUrl,
    required this.supportsSettings,
    required this.hasCookies,
    required this.loginVerified,
  });

  /// Factory constructor to deserialize from native Map.
  ///
  /// Sensitive attributes are discarded; only allowlisted fields are retained.
  /// [loginVerified] is strictly false unless explicitly provided as boolean true
  /// by the native platform (cookie presence never implies verification).
  factory SourceAccessInfo.fromMap(Map<dynamic, dynamic> map) {
    final rawSourceId = map['sourceId']?.toString() ?? '';
    final rawName = map['name']?.toString() ?? '';
    final rawHomeUrl = map['homeUrl']?.toString() ?? '';
    final bool rawSupportsSettings = map['supportsSettings'] == true;
    final bool rawHasCookies = map['hasCookies'] == true;
    final bool rawLoginVerified = map['loginVerified'] == true;

    return SourceAccessInfo(
      sourceId: rawSourceId,
      name: rawName,
      homeUrl: rawHomeUrl,
      supportsSettings: rawSupportsSettings,
      hasCookies: rawHasCookies,
      loginVerified: rawLoginVerified,
    );
  }

  /// Converts the DTO into a JSON/Map containing only allowlisted fields.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sourceId': sourceId,
      'name': name,
      'homeUrl': homeUrl,
      'supportsSettings': supportsSettings,
      'hasCookies': hasCookies,
      'loginVerified': loginVerified,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceAccessInfo &&
          runtimeType == other.runtimeType &&
          sourceId == other.sourceId &&
          name == other.name &&
          homeUrl == other.homeUrl &&
          supportsSettings == other.supportsSettings &&
          hasCookies == other.hasCookies &&
          loginVerified == other.loginVerified;

  @override
  int get hashCode => Object.hash(
        sourceId,
        name,
        homeUrl,
        supportsSettings,
        hasCookies,
        loginVerified,
      );
}

/// Type alias for backward compatibility / explicit DTO naming.
typedef SourceAccessInfoDTO = SourceAccessInfo;

/// Bridge communicating with native platform for source access operations.
class SourceAccessBridge {
  static const String defaultChannelName = 'dev.dcatcher/source_access';

  final MethodChannel channel;
  final bool isSupported;

  SourceAccessBridge({
    MethodChannel? channel,
  })  : channel = channel ?? const MethodChannel(defaultChannelName),
        isSupported = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @visibleForTesting
  SourceAccessBridge.forTesting({
    required this.channel,
    required this.isSupported,
  });

  void _validateSourceId(String sourceId) {
    if (sourceId.trim().isEmpty) {
      throw ArgumentError.value(
        sourceId,
        'sourceId',
        'Source ID must be a non-empty string',
      );
    }
  }

  void _checkSupported() {
    if (!isSupported) {
      throw UnsupportedError(
        'SourceAccessBridge is only supported on Android platforms.',
      );
    }
  }

  /// Fetches source access information and capabilities.
  Future<SourceAccessInfo> getInfo(String sourceId) async {
    _checkSupported();
    _validateSourceId(sourceId);

    final dynamic response = await channel.invokeMethod<dynamic>(
      'getSourceAccessInfo',
      <String, dynamic>{'sourceId': sourceId},
    );

    if (response == null || response is! Map) {
      throw FormatException(
        'Invalid or null native response for getSourceAccessInfo: $response',
      );
    }

    return SourceAccessInfo.fromMap(response);
  }

  /// Opens the source in native WebView.
  Future<bool> openWebView(String sourceId) async {
    _checkSupported();
    _validateSourceId(sourceId);

    final dynamic result = await channel.invokeMethod<dynamic>(
      'openSourceWebView',
      <String, dynamic>{'sourceId': sourceId},
    );

    if (result == null) {
      throw StateError(
        'Native platform returned null response for openSourceWebView',
      );
    }

    return result == true;
  }

  /// Opens native extension/source settings.
  Future<bool> openSettings(String sourceId) async {
    _checkSupported();
    _validateSourceId(sourceId);

    final dynamic result = await channel.invokeMethod<dynamic>(
      'openSourceSettings',
      <String, dynamic>{'sourceId': sourceId},
    );

    if (result == null) {
      throw StateError(
        'Native platform returned null response for openSourceSettings',
      );
    }

    return result == true;
  }

  /// Clears cookies associated with the given source.
  ///
  /// Requires explicit confirmation flag [confirmed] set to true.
  Future<void> clearCookies(
    String sourceId, {
    required bool confirmed,
  }) async {
    _checkSupported();
    _validateSourceId(sourceId);

    if (!confirmed) {
      throw ArgumentError(
        'Explicit confirmation is required to clear source cookies.',
      );
    }

    await channel.invokeMethod<dynamic>(
      'clearSourceCookies',
      <String, dynamic>{
        'sourceId': sourceId,
        'confirmed': true,
      },
    );
  }
}
