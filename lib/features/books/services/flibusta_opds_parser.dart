import 'package:xml/xml.dart';
import '../models/book_item.dart';
import '../models/book_catalog_page.dart';

/// Atom feed XML namespace URI.
const String _atomNamespace = 'http://www.w3.org/2005/Atom';

/// Dublin Core terms namespace URI.
const String _dcNamespace = 'http://purl.org/dc/terms/';

/// Safely parses a Flibusta OPDS Atom feed into a [BookCatalogPage] containing
/// items and optional next page link.
BookCatalogPage parseFlibustaOpdsPage(
  String content, {
  required Uri documentUri,
}) {
  // Validate that documentUri is a trusted HTTPS base without userinfo and default port (443)
  if (!documentUri.isScheme('https') ||
      documentUri.host.isEmpty ||
      documentUri.userInfo.isNotEmpty ||
      (documentUri.hasPort && documentUri.port != 443)) {
    throw const FormatException('Invalid catalog response');
  }

  // Reject DOCTYPE / external entities immediately (fail closed)
  if (_hasDoctypeDeclaration(content)) {
    throw const FormatException('Invalid catalog response');
  }

  final XmlDocument document;
  try {
    document = XmlDocument.parse(content);
  } on XmlException {
    throw const FormatException('Invalid catalog response');
  } catch (_) {
    throw const FormatException('Invalid catalog response');
  }

  final root = document.rootElement;

  // Root must be an Atom <feed> element
  if (root.localName != 'feed' || root.namespaceUri != _atomNamespace) {
    throw const FormatException('Invalid catalog response');
  }

  // Base URI resolution: root xml:base or inherited documentUri
  final rootBaseUri = _resolveXmlBase(root, documentUri);

  // Extract next page URI strictly from ROOT Atom <link rel="next" ...> only
  final Uri? nextPageUri = _extractNextPageUri(root, rootBaseUri, documentUri);

  final List<BookItem> books = [];

  // Direct Atom entry children only
  final entryElements = root.children
      .whereType<XmlElement>()
      .where((el) => el.localName == 'entry' && el.namespaceUri == _atomNamespace);

  for (final entry in entryElements) {
    final entryBaseUri = _resolveXmlBase(entry, rootBaseUri);

    // Extract book ID from validated same-origin HTTPS source/details/acquisition links
    final bookId = _extractBookId(entry, entryBaseUri, documentUri);
    if (bookId == null) {
      // Filter out navigation or entries without validated book links
      continue;
    }

    // Title handling
    final title = _extractTitle(entry);
    if (title == null || title.trim().isEmpty) {
      // Filter out entries without a title
      continue;
    }

    // Author handling: multiple authors joined with comma
    final author = _extractAuthors(entry);

    // Cover handling
    final coverUrl = _extractCoverUrl(entry, entryBaseUri, documentUri);

    // Category / genre
    final genre = _extractGenre(entry);

    // Content / summary handling: strip HTML tags cleanly, fallback to default
    final description = _extractDescription(entry);

    // Year handling: only from dc:issued (if exists and valid int), otherwise 0
    final year = _extractYear(entry);

    // Available formats from acquisition links
    final formats = _extractAvailableFormats(entry, entryBaseUri, documentUri, bookId);

    // Rating: 0 sentinel because feed has no rating
    const rating = 0.0;

    books.add(BookItem(
      id: bookId,
      title: title.trim(),
      author: author,
      genre: genre,
      coverUrl: coverUrl,
      description: description,
      year: year,
      rating: rating,
      chapters: const [],
      isFree: true,
      availableFormats: formats,
    ));
  }

  return BookCatalogPage(
    items: books,
    nextPageUri: nextPageUri,
    documentUri: documentUri,
  );
}

/// Safely parses a Flibusta OPDS Atom feed into a list of [BookItem]s.
///
/// Backwards-compatible wrapper around [parseFlibustaOpdsPage].
List<BookItem> parseFlibustaOpds(
  String content, {
  required Uri documentUri,
}) {
  return parseFlibustaOpdsPage(content, documentUri: documentUri).items;
}

Uri? _extractNextPageUri(XmlElement root, Uri rootBaseUri, Uri documentUri) {
  // Direct ROOT Atom <link> children only (ignore external / entry links)
  final linkElements = root.children
      .whereType<XmlElement>()
      .where((el) => el.localName == 'link' && el.namespaceUri == _atomNamespace);

  for (final link in linkElements) {
    final rel = link.getAttribute('rel')?.trim() ?? '';
    if (rel != 'next') continue;

    final href = link.getAttribute('href');
    if (href == null || href.trim().isEmpty) continue;

    final linkBaseUri = _resolveXmlBase(link, rootBaseUri);
    final Uri resolvedUri;
    try {
      resolvedUri = linkBaseUri.resolve(href.trim());
    } catch (_) {
      continue;
    }

    // Must be strict same origin HTTPS as documentUri (port, userinfo empty, no fragment)
    if (!_isStrictSameOrigin(resolvedUri, documentUri)) {
      continue;
    }
    if (resolvedUri.hasFragment) {
      continue;
    }

    // Validate path is /opds or starts with /opds/
    if (resolvedUri.path != '/opds' && !resolvedUri.path.startsWith('/opds/')) {
      continue;
    }

    return resolvedUri;
  }

  return null;
}

bool _hasDoctypeDeclaration(String content) {
  final match = RegExp(r'<!DOCTYPE[\s>]', caseSensitive: false).hasMatch(content);
  return match;
}

Uri _resolveXmlBase(XmlElement element, Uri currentBase) {
  final baseAttr = element.getAttribute('xml:base');
  if (baseAttr == null || baseAttr.trim().isEmpty) {
    return currentBase;
  }
  try {
    return currentBase.resolve(baseAttr.trim());
  } catch (_) {
    return currentBase;
  }
}

bool _isStrictSameOrigin(Uri uri, Uri documentUri) {
  if (!uri.isScheme('https')) return false;
  if (uri.userInfo.isNotEmpty) return false;
  if (uri.host != documentUri.host) return false;
  final uriPort = uri.hasPort ? uri.port : 443;
  final docPort = documentUri.hasPort ? documentUri.port : 443;
  return uriPort == docPort;
}

String? _extractBookId(XmlElement entry, Uri entryBaseUri, Uri documentUri) {
  // Determine book ID ONLY from validated same-origin HTTPS /b/<numericID> links
  // with recognized acquisition rel prefix, alternate, or legacy empty/absent rel.
  final linkElements = entry.children
      .whereType<XmlElement>()
      .where((el) => el.localName == 'link' && el.namespaceUri == _atomNamespace);

  for (final link in linkElements) {
    final href = link.getAttribute('href');
    if (href == null || href.trim().isEmpty) continue;

    final rel = link.getAttribute('rel')?.trim() ?? '';

    final isRecognizedRel = rel.isEmpty ||
        rel == 'alternate' ||
        rel.startsWith('http://opds-spec.org/acquisition') ||
        rel.startsWith('https://opds-spec.org/acquisition');

    if (!isRecognizedRel) continue;

    final linkBaseUri = _resolveXmlBase(link, entryBaseUri);
    final Uri resolvedUri;
    try {
      resolvedUri = linkBaseUri.resolve(href.trim());
    } catch (_) {
      continue;
    }

    // Must be strict same origin HTTPS as documentUri (port, userinfo empty)
    if (!_isStrictSameOrigin(resolvedUri, documentUri)) {
      continue;
    }

    final id = _parseNumericBookIdFromPath(resolvedUri.path);
    if (id != null) {
      return id;
    }
  }

  return null;
}

List<String> _extractAvailableFormats(
  XmlElement entry,
  Uri entryBaseUri,
  Uri documentUri,
  String bookId,
) {
  final linkElements = entry.children
      .whereType<XmlElement>()
      .where((el) => el.localName == 'link' && el.namespaceUri == _atomNamespace);

  final formats = <String>[];
  final seen = <String>{};

  for (final link in linkElements) {
    final rel = link.getAttribute('rel')?.trim() ?? '';
    // Format ONLY direct Atom acquisition rel EXACT or acquisition/ prefix
    final isAcquisition = rel == 'http://opds-spec.org/acquisition' ||
        rel == 'https://opds-spec.org/acquisition' ||
        rel.startsWith('http://opds-spec.org/acquisition/') ||
        rel.startsWith('https://opds-spec.org/acquisition/');

    if (!isAcquisition) {
      continue;
    }

    final href = link.getAttribute('href');
    if (href == null || href.trim().isEmpty) continue;

    final linkBaseUri = _resolveXmlBase(link, entryBaseUri);
    final Uri resolvedUri;
    try {
      resolvedUri = linkBaseUri.resolve(href.trim());
    } catch (_) {
      continue;
    }

    // Validate resolved URI strict HTTPS same origin 443 no userInfo no fragment
    if (!_isStrictSameOrigin(resolvedUri, documentUri)) continue;
    if (resolvedUri.hasFragment) continue;

    // Must be /b/{sameNumericBookId}/...
    final path = resolvedUri.path;
    final prefix = '/b/$bookId/';
    final isExactOrChild = path == '/b/$bookId' || path.startsWith(prefix);
    if (!isExactOrChild) {
      continue;
    }

    final rawType = link.getAttribute('type')?.trim();
    if (rawType == null || rawType.isEmpty) continue;

    // Dedup normalized MIME types: optional strip charset, lowercase
    final normalized = _normalizeMimeType(rawType);
    if (normalized.isNotEmpty && seen.add(normalized)) {
      formats.add(normalized);
    }
  }

  return formats;
}

String _normalizeMimeType(String raw) {
  final withoutCharset = raw.split(';').first.trim().toLowerCase();
  return withoutCharset;
}

String? _parseNumericBookIdFromPath(String path) {
  // Path pattern: /b/<numericID> or /b/<numericID>/download etc.
  final match = RegExp(r'^/b/(\d+)(?:/.*)?$').firstMatch(path);
  if (match != null) {
    return match.group(1);
  }
  return null;
}

String? _extractTitle(XmlElement entry) {
  final titleElement = entry.children
      .whereType<XmlElement>()
      .where((el) => el.localName == 'title' && el.namespaceUri == _atomNamespace)
      .firstOrNull;

  if (titleElement == null) return null;

  // innerText automatically decodes entities and CDATA via DOM
  return titleElement.innerText;
}

String _extractAuthors(XmlElement entry) {
  final authorElements = entry.children
      .whereType<XmlElement>()
      .where((el) => el.localName == 'author' && el.namespaceUri == _atomNamespace);

  final names = <String>[];
  for (final authorEl in authorElements) {
    final nameEl = authorEl.children
        .whereType<XmlElement>()
        .where((el) => el.localName == 'name' && el.namespaceUri == _atomNamespace)
        .firstOrNull;

    final nameText = nameEl != null ? nameEl.innerText.trim() : authorEl.innerText.trim();
    if (nameText.isNotEmpty) {
      names.add(nameText);
    }
  }

  return names.isNotEmpty ? names.join(', ') : 'Неизвестный автор';
}

String _extractCoverUrl(XmlElement entry, Uri entryBaseUri, Uri documentUri) {
  final linkElements = entry.children
      .whereType<XmlElement>()
      .where((el) => el.localName == 'link' && el.namespaceUri == _atomNamespace);

  for (final link in linkElements) {
    final rel = link.getAttribute('rel')?.trim() ?? '';
    final isCoverRel = rel == 'http://opds-spec.org/image' ||
        rel == 'http://opds-spec.org/image/thumbnail' ||
        rel == 'http://opds-spec.org/thumbnail' ||
        rel == 'https://opds-spec.org/image' ||
        rel == 'https://opds-spec.org/image/thumbnail' ||
        rel == 'https://opds-spec.org/thumbnail';

    if (isCoverRel) {
      final href = link.getAttribute('href');
      if (href == null || href.trim().isEmpty) continue;

      final linkBaseUri = _resolveXmlBase(link, entryBaseUri);
      try {
        final resolved = linkBaseUri.resolve(href.trim());
        if (_isStrictSameOrigin(resolved, documentUri)) {
          return resolved.toString();
        }
      } catch (_) {}
    }
  }

  // Absent cover => empty string NOT stock photo
  return '';
}

const Map<String, String> _knownCategoryTerms = {
  'sf': 'Фантастика',
  'sf_history': 'Альтернативная история',
  'sf_action': 'Боевая фантастика',
  'sf_space': 'Космическая фантастика',
  'sf_cyberpunk': 'Киберпанк',
  'sf_postapocalyptic': 'Постапокалипсис',
  'sf_heroic': 'Героическая фантастика',
  'sf_fantasy': 'Фэнтези',
  'fantasy': 'Фэнтези',
  'fairy_fantasy': 'Сказочная фантастика',
  'detective': 'Детектив',
  'det_action': 'Боевик, детектив',
  'det_irony': 'Иронический детектив',
  'det_history': 'Исторический детектив',
  'det_classic': 'Классический детектив',
  'det_police': 'Полицейский детектив',
  'thriller': 'Триллер',
  'adventure': 'Приключения',
  'adv_western': 'Вестерн',
  'adv_history': 'Исторические приключения',
  'adv_maritime': 'Морские приключения',
  'prose_classic': 'Классическая проза',
  'classic': 'Классика',
  'horror': 'Ужасы и Мистика',
  'gothic': 'Готический роман',
};

String _extractGenre(XmlElement entry) {
  final categoryElements = entry.children
      .whereType<XmlElement>()
      .where((el) => el.localName == 'category' && el.namespaceUri == _atomNamespace);

  // 1. Prefer explicit human-readable label attribute if present
  for (final cat in categoryElements) {
    final label = cat.getAttribute('label')?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
  }

  // 2. Try mapped standard OPDS/FB2 category terms
  for (final cat in categoryElements) {
    final term = cat.getAttribute('term')?.trim();
    if (term != null && term.isNotEmpty) {
      final mapped = _knownCategoryTerms[term.toLowerCase()];
      if (mapped != null) {
        return mapped;
      }
    }
  }

  // 3. Fallback to raw category term if present
  for (final cat in categoryElements) {
    final term = cat.getAttribute('term')?.trim();
    if (term != null && term.isNotEmpty) {
      return term;
    }
  }

  return 'Художественная литература';
}

String _extractDescription(XmlElement entry) {
  final contentEl = entry.children
      .whereType<XmlElement>()
      .where((el) =>
          (el.localName == 'content' || el.localName == 'summary') &&
          el.namespaceUri == _atomNamespace)
      .firstOrNull;

  if (contentEl == null) {
    return 'Книга из каталога Flibusta.site';
  }

  final rawText = contentEl.innerText.trim();
  if (rawText.isEmpty) {
    return 'Книга из каталога Flibusta.site';
  }

  final typeAttr = contentEl.getAttribute('type')?.toLowerCase();
  String cleaned;
  if (typeAttr == 'html' || typeAttr == 'xhtml' || rawText.contains('<')) {
    cleaned = _stripHtml(rawText);
  } else {
    cleaned = rawText;
  }

  return cleaned.isNotEmpty ? cleaned : 'Книга из каталога Flibusta.site';
}

String _stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<(?:br|\/p|\/div)[^>]*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('\r', '')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

int _extractYear(XmlElement entry) {
  final issuedEl = entry.children
      .whereType<XmlElement>()
      .where((el) =>
          (el.localName == 'issued' || el.localName == 'date') &&
          (el.namespaceUri == _dcNamespace || el.namespaceUri == _atomNamespace))
      .firstOrNull;

  if (issuedEl != null) {
    final text = issuedEl.innerText.trim();
    final yearMatch = RegExp(r'\b(\d{4})\b').firstMatch(text);
    if (yearMatch != null) {
      final parsed = int.tryParse(yearMatch.group(1)!);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
  }

  // Sentinel 0 when not specified or invalid (do NOT invent current year)
  return 0;
}
