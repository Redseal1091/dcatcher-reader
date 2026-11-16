enum ContentWarning {
  safe,
  nsfw,
  mixed;

  static ContentWarning fromString(String? value) {
    if (value == null) return ContentWarning.safe;
    final upper = value.toUpperCase();
    if (upper.contains('NSFW')) {
      return ContentWarning.nsfw;
    } else if (upper.contains('MIXED')) {
      return ContentWarning.mixed;
    }
    return ContentWarning.safe;
  }

  String toSerializedString() {
    switch (this) {
      case ContentWarning.safe:
        return 'CONTENT_WARNING_SAFE';
      case ContentWarning.nsfw:
        return 'CONTENT_WARNING_NSFW';
      case ContentWarning.mixed:
        return 'CONTENT_WARNING_MIXED';
    }
  }
}

class KeiyoushiSource {
  static final _decimalRegExp = RegExp(r'^\d+$');

  /// 64-bit integer ID preserved as decimal string without precision loss
  final String id;
  final String name;
  final String language;
  final String homeUrl;

  const KeiyoushiSource({
    required this.id,
    required this.name,
    required this.language,
    required this.homeUrl,
  });

  static String validateDecimalString(dynamic value, String fieldName) {
    if (value == null) {
      throw FormatException('$fieldName cannot be null');
    }
    if (value is double) {
      throw FormatException(
        '$fieldName cannot be a floating point number (double), 64-bit precision already lost: $value',
      );
    }
    final str = value.toString().trim();
    if (!_decimalRegExp.hasMatch(str)) {
      throw FormatException(
        '$fieldName must be a canonical decimal string, got: "$value"',
      );
    }
    return str;
  }

  factory KeiyoushiSource.fromJson(Map<String, dynamic> json) {
    return KeiyoushiSource(
      id: validateDecimalString(json['id'], 'Source id'),
      name: json['name']?.toString() ?? '',
      language: (json['language'] ?? json['lang'])?.toString() ?? 'all',
      homeUrl: (json['homeUrl'] ?? json['baseUrl'])?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'language': language,
    'homeUrl': homeUrl,
  };
}

class KeiyoushiExtension {
  final String name;
  final String packageName;
  final String versionName;
  /// Version code preserved as decimal string
  final String versionCode;
  final String extensionLib;
  final String apkUrl;
  final String iconUrl;
  final ContentWarning contentWarning;
  final List<KeiyoushiSource> sources;

  const KeiyoushiExtension({
    required this.name,
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.extensionLib,
    required this.apkUrl,
    required this.iconUrl,
    required this.contentWarning,
    required this.sources,
  });

  bool get isNsfw =>
      contentWarning == ContentWarning.nsfw ||
      contentWarning == ContentWarning.mixed;

  factory KeiyoushiExtension.fromJson(Map<String, dynamic> json) {
    final resources = json['resources'] as Map<String, dynamic>? ?? {};
    final apkUrl = resources['apkUrl']?.toString() ?? json['apkUrl']?.toString() ?? '';
    final iconUrl = resources['iconUrl']?.toString() ?? json['iconUrl']?.toString() ?? '';

    final sourcesList = (json['sources'] as List<dynamic>? ?? [])
        .map((s) => KeiyoushiSource.fromJson(s as Map<String, dynamic>))
        .toList();

    return KeiyoushiExtension(
      name: json['name']?.toString() ?? '',
      packageName: (json['packageName'] ?? json['pkgName'])?.toString() ?? '',
      versionName: json['versionName']?.toString() ?? '',
      versionCode: KeiyoushiSource.validateDecimalString(
        json['versionCode'] ?? '0',
        'Extension versionCode',
      ),
      extensionLib: json['extensionLib']?.toString() ?? '1.6',
      apkUrl: apkUrl,
      iconUrl: iconUrl,
      contentWarning: ContentWarning.fromString(json['contentWarning']?.toString()),
      sources: sourcesList,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'packageName': packageName,
    'versionName': versionName,
    'versionCode': versionCode,
    'extensionLib': extensionLib,
    'resources': {
      'apkUrl': apkUrl,
      'iconUrl': iconUrl,
    },
    'contentWarning': contentWarning.toSerializedString(),
    'sources': sources.map((s) => s.toJson()).toList(),
  };
}

/// Real DTO returned from native Android extension manager
class NativePackageDto {
  final String packageName;
  final String versionCode;
  final String versionName;
  final String extensionLib;
  final List<KeiyoushiSource> sources;

  const NativePackageDto({
    required this.packageName,
    required this.versionCode,
    required this.versionName,
    this.extensionLib = '1.6',
    this.sources = const [],
  });

  factory NativePackageDto.fromJson(Map<String, dynamic> json) {
    final pkg = json['packageName']?.toString();
    if (pkg == null || pkg.trim().isEmpty) {
      throw const FormatException('NativePackageDto missing required packageName');
    }
    final rawVersionCode = json['versionCode'];
    if (rawVersionCode == null || rawVersionCode.toString().trim().isEmpty) {
      throw const FormatException('NativePackageDto missing required versionCode');
    }
    final rawExtensionLib = json['extensionLib']?.toString();
    if (rawExtensionLib == null || rawExtensionLib.trim().isEmpty) {
      throw const FormatException('NativePackageDto missing required extensionLib');
    }

    final rawSources = json['sources'] as List<dynamic>? ?? [];
    final sourcesList = rawSources.map((raw) {
      if (raw is! Map) {
        throw FormatException('Invalid source shape in NativePackageDto: expected Map, got ${raw.runtimeType}');
      }
      return KeiyoushiSource.fromJson(Map<String, dynamic>.from(raw));
    }).toList();

    return NativePackageDto(
      packageName: pkg,
      versionCode: KeiyoushiSource.validateDecimalString(
        rawVersionCode,
        'NativePackageDto versionCode',
      ),
      versionName: json['versionName']?.toString() ?? '',
      extensionLib: rawExtensionLib,
      sources: sourcesList,
    );
  }

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'versionCode': versionCode,
    'versionName': versionName,
    'extensionLib': extensionLib,
    'sources': sources.map((s) => s.toJson()).toList(),
  };

  /// Converts this native DTO into a full [KeiyoushiExtension], joining with [knownExtension]
  /// if available from store cache, or retaining truthful unknown/empty fields (never fake versions or URLs).
  /// Strictly fails closed: NEVER uses [knownExtension.sources] as installed sources if native reported empty.
  KeiyoushiExtension toExtension({KeiyoushiExtension? knownExtension}) {
    if (knownExtension != null) {
      return KeiyoushiExtension(
        name: knownExtension.name,
        packageName: packageName,
        versionName: versionName.isNotEmpty ? versionName : knownExtension.versionName,
        versionCode: versionCode.isNotEmpty ? versionCode : knownExtension.versionCode,
        extensionLib: extensionLib.isNotEmpty ? extensionLib : knownExtension.extensionLib,
        apkUrl: knownExtension.apkUrl,
        iconUrl: knownExtension.iconUrl,
        contentWarning: knownExtension.contentWarning,
        sources: sources, // Fail closed: strictly truthful native loaded sources, never invented from catalog!
      );
    }

    return KeiyoushiExtension(
      name: packageName,
      packageName: packageName,
      versionName: versionName,
      versionCode: versionCode,
      extensionLib: extensionLib,
      apkUrl: '', // Truthful empty APK URL (not fabricated)
      iconUrl: '',
      contentWarning: ContentWarning.safe,
      sources: sources,
    );
  }
}
