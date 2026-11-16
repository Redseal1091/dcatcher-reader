import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../../catalog/models/manga.dart';
import '../../sources/manga_source.dart';
import '../../download/download_manager.dart';

enum ReaderMode {
  auto,
  webtoon,
  paged,
}

class ReaderModeResolver {
  static const String _prefPrefix = 'reader_mode_pref_';

  static String _storageKey(String mangaId, String sourceId) {
    return '$_prefPrefix${sourceId}_$mangaId';
  }

  /// Retrieves user explicit preference for this manga and source.
  /// Defaults to [ReaderMode.auto] if not set.
  static Future<ReaderMode> getSavedPreference({
    required String mangaId,
    required String sourceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(mangaId, sourceId);
    final val = prefs.getString(key);
    switch (val) {
      case 'webtoon':
        return ReaderMode.webtoon;
      case 'paged':
        return ReaderMode.paged;
      case 'auto':
      default:
        return ReaderMode.auto;
    }
  }

  /// Saves user explicit preference for this manga and source.
  static Future<void> savePreference({
    required String mangaId,
    required String sourceId,
    required ReaderMode mode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(mangaId, sourceId);
    if (mode == ReaderMode.auto) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, mode.name);
    }
  }

  /// Resolves reader mode based on image dimensions.
  /// Aspect ratio height / width:
  /// Webtoon/longstrip is typically significantly taller (e.g. 900x12000 -> ratio > 2.2).
  /// Normal pages are 900x1300 (ratio ~1.44).
  static ReaderMode fromImageDimensions(int width, int height) {
    if (width <= 0 || height <= 0 || width.isNaN || height.isNaN) {
      return ReaderMode.paged;
    }
    final ratio = height / width;
    if (ratio.isNaN || ratio.isInfinite) {
      return ReaderMode.paged;
    }
    if (ratio >= 2.2) {
      return ReaderMode.webtoon;
    }
    return ReaderMode.paged;
  }

  /// Parses image dimensions from binary header (JPEG, PNG, WebP, GIF) without full bitmap decode.
  /// Returns (width, height) or null if unable to parse.
  static (int, int)? probeDimensionsFromHeader(Uint8List bytes) {
    if (bytes.length < 16) return null;

    try {
      // 1. PNG Header: 89 50 4E 47 0D 0A 1A 0A
      if (bytes.length >= 24 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        final bdata = ByteData.sublistView(bytes);
        final w = bdata.getUint32(16);
        final h = bdata.getUint32(20);
        if (w > 0 && h > 0) return (w, h);
      }

      // 2. GIF Header: GIF87a or GIF89a
      if (bytes.length >= 10 &&
          bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46) {
        final bdata = ByteData.sublistView(bytes);
        final w = bdata.getUint16(6, Endian.little);
        final h = bdata.getUint16(8, Endian.little);
        if (w > 0 && h > 0) return (w, h);
      }

      // 3. WebP Header: RIFF .... WEBP VP8 / VP8L / VP8X
      if (bytes.length >= 30 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        // VP8X (Extended WebP)
        if (bytes[12] == 0x56 &&
            bytes[13] == 0x50 &&
            bytes[14] == 0x38 &&
            bytes[15] == 0x58 &&
            bytes.length >= 30) {
          final w = 1 + (bytes[24] | (bytes[25] << 8) | (bytes[26] << 16));
          final h = 1 + (bytes[27] | (bytes[28] << 8) | (bytes[29] << 16));
          return (w, h);
        }
        // VP8L (Lossless WebP)
        if (bytes[12] == 0x56 &&
            bytes[13] == 0x50 &&
            bytes[14] == 0x38 &&
            bytes[15] == 0x4C &&
            bytes.length >= 25) {
          if (bytes[20] == 0x2F) {
            final b1 = bytes[21];
            final b2 = bytes[22];
            final b3 = bytes[23];
            final b4 = bytes[24];
            final w = 1 + (((b2 & 0x3F) << 8) | b1);
            final h = 1 + ((((b4 & 0xF) << 10) | (b3 << 2) | ((b2 & 0xC0) >> 6)));
            return (w, h);
          }
        }
        // VP8 (Lossy WebP)
        if (bytes[12] == 0x56 &&
            bytes[13] == 0x50 &&
            bytes[14] == 0x38 &&
            bytes[15] == 0x20 &&
            bytes.length >= 30) {
          // Keyframe code: 9D 01 2A
          if (bytes[23] == 0x9D && bytes[24] == 0x01 && bytes[25] == 0x2A) {
            final w = (bytes[26] | ((bytes[27] & 0x3F) << 8));
            final h = (bytes[28] | ((bytes[29] & 0x3F) << 8));
            return (w, h);
          }
        }
      }

      // 4. JPEG Header: FF D8 ...
      if (bytes.length >= 4 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
        int offset = 2;
        while (offset < bytes.length - 8) {
          if (bytes[offset] != 0xFF) {
            offset++;
            continue;
          }
          final marker = bytes[offset + 1];
          // SOF markers: SOF0 (0xC0), SOF1 (0xC1), SOF2 (0xC2), SOF3 (0xC3),
          // SOF5 (0xC5), SOF6 (0xC6), SOF7 (0xC7), SOF9 (0xC9), SOF10 (0xCA), SOF11 (0xCB)
          if ((marker >= 0xC0 && marker <= 0xC3) ||
              (marker >= 0xC5 && marker <= 0xC7) ||
              (marker >= 0xC9 && marker <= 0xCB)) {
            if (offset + 8 < bytes.length) {
              final bdata = ByteData.sublistView(bytes);
              final h = bdata.getUint16(offset + 5);
              final w = bdata.getUint16(offset + 7);
              if (w > 0 && h > 0) return (w, h);
            }
            break;
          }
          if (marker == 0xD9 || marker == 0xDA) break; // End of image or Start of scan
          final bdata = ByteData.sublistView(bytes);
          final length = bdata.getUint16(offset + 2);
          if (length < 2) break;
          offset += 2 + length;
        }
      }
    } catch (_) {
      // Header parse failure, fallback
    }

    return null;
  }

  /// Resolves the actual effective reader mode (webtoon or paged) for [manga].
  ///
  /// Logic:
  /// 1. If explicit user preference for this manga is [ReaderMode.webtoon] or [ReaderMode.paged], return it.
  /// 2. If reliable metadata clearly identifies manhwa/manhua or webtoon genres/titles (via [isWebtoonMetadata]), return [ReaderMode.webtoon].
  ///    If metadata clearly indicates standard manga type with explicit manga genres, return [ReaderMode.paged].
  /// 3. If publication type is unknown / `PublicationType.all` and genres/titles are ambiguous:
  ///    Probe 1 to 3 actual chapter images via [source.fetchImage] or local downloaded files.
  ///    Examines aspect ratios via header decoding.
  /// 4. Safe fallback to [ReaderMode.paged].
  static Future<ReaderMode> resolveEffectiveMode({
    required Manga manga,
    required MangaSource? source,
    String? sampleChapterId,
    bool isMetadataWebtoon = false,
  }) async {
    // 1. Explicit user override
    final savedPref = await getSavedPreference(
      mangaId: manga.id,
      sourceId: manga.sourceId,
    );
    if (savedPref == ReaderMode.webtoon) return ReaderMode.webtoon;
    if (savedPref == ReaderMode.paged) return ReaderMode.paged;

    // 2. Reliable metadata
    if (isMetadataWebtoon) {
      return ReaderMode.webtoon;
    }
    if (manga.type == PublicationType.manga && manga.genres.isNotEmpty) {
      return ReaderMode.paged;
    }

    // 3. Probing 1-3 images for unknown metadata
    if (sampleChapterId != null && sampleChapterId.isNotEmpty) {
      try {
        final probedMode = await _probeImages(
          manga: manga,
          source: source,
          chapterId: sampleChapterId,
        );
        if (probedMode != null) {
          return probedMode;
        }
      } catch (_) {
        // Fall through to safe fallback
      }
    }

    // 4. Safe fallback
    return ReaderMode.paged;
  }

  static Future<ReaderMode?> _probeImages({
    required Manga manga,
    required MangaSource? source,
    required String chapterId,
  }) async {
    List<String> pageUrls = [];

    // Check offline downloaded pages first
    final dm = DownloadManager();
    final downloadedPages = await dm.getOfflinePages(chapterId);
    if (downloadedPages != null && downloadedPages.isNotEmpty) {
      pageUrls = downloadedPages;
    } else if (source != null) {
      pageUrls = await source.getChapterPages(chapterId);
    }

    if (pageUrls.isEmpty) return null;

    final probeCount = pageUrls.length < 3 ? pageUrls.length : 3;
    bool hasProbedSample = false;

    for (int i = 0; i < probeCount; i++) {
      final pageUrl = pageUrls[i];
      Uint8List? bytes;

      try {
        final uri = Uri.tryParse(pageUrl);
        final scheme = uri?.scheme.toLowerCase();
        final isRemote = scheme == 'http' || scheme == 'https';

        if (isRemote) {
          if (source != null) {
            bytes = await source.fetchImage(pageUrl).timeout(
              const Duration(seconds: 7),
            );
          }
        } else {
          // File path or file:// URI
          String filePath = pageUrl;
          if (scheme == 'file' && uri != null) {
            filePath = uri.toFilePath();
          }
          final file = File(filePath);
          if (await file.exists()) {
            final stream = file.openRead(0, 32768); // Read max 32KB
            final chunks = await stream.toList();
            final builder = BytesBuilder();
            for (final chunk in chunks) {
              builder.add(chunk);
            }
            bytes = builder.toBytes();
          }
        }
      } catch (_) {
        // Local/remote error caught per image so it does not fail whole probe
        bytes = null;
      }

      if (bytes != null && bytes.isNotEmpty) {
        final dims = probeDimensionsFromHeader(bytes);
        if (dims != null) {
          hasProbedSample = true;
          final mode = fromImageDimensions(dims.$1, dims.$2);
          if (mode == ReaderMode.webtoon) {
            // Return webtoon if ANY sample is tall
            return ReaderMode.webtoon;
          }
        }
      }
    }

    if (hasProbedSample) {
      // Normal first cover must not early-return paged; paged only after samples probed
      return ReaderMode.paged;
    }

    return null;
  }
}
