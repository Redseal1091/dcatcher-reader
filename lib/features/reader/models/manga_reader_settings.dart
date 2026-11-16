import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MangaReadingMode {
  pagedRtl,      // Традиционная манга (справа-налево)
  pagedLtr,      // Европейский/западный комикс (слева-направо)
  webtoon,       // Вебтун (непрерывная вертикальная лента)
  pagedVertical, // Вертикальный постраничный свайп
}

enum MangaReaderTheme {
  oledBlack,     // Истинный черный (#000000) для OLED-экранов
  zincDark,      // Тёмный Zinc (#09090B)
  warmSepia,     // Тёплая сепия (#1E1A16)
  light,         // Светлый (#FFFFFF)
}

enum MangaImageFit {
  contain,       // Вписать целиком без обрезки
  fitWidth,      // По ширине экрана (от края до края)
  fitHeight,     // По высоте экрана
  cover,         // Заполнить весь экран
}

extension MangaReadingModeExt on MangaReadingMode {
  String get label {
    switch (this) {
      case MangaReadingMode.pagedRtl:
        return 'Манга (RTL)';
      case MangaReadingMode.pagedLtr:
        return 'Страницы (LTR)';
      case MangaReadingMode.webtoon:
        return 'Вебтун';
      case MangaReadingMode.pagedVertical:
        return 'Вертикально';
    }
  }

  IconData get icon {
    switch (this) {
      case MangaReadingMode.pagedRtl:
        return Icons.menu_book_rounded;
      case MangaReadingMode.pagedLtr:
        return Icons.auto_stories_rounded;
      case MangaReadingMode.webtoon:
        return Icons.view_day_rounded;
      case MangaReadingMode.pagedVertical:
        return Icons.swap_vert_rounded;
    }
  }
}

extension MangaReaderThemeExt on MangaReaderTheme {
  Color get backgroundColor {
    switch (this) {
      case MangaReaderTheme.oledBlack:
        return Colors.black;
      case MangaReaderTheme.zincDark:
        return const Color(0xFF09090B);
      case MangaReaderTheme.warmSepia:
        return const Color(0xFF1E1A16);
      case MangaReaderTheme.light:
        return Colors.white;
    }
  }

  Color get textColor {
    switch (this) {
      case MangaReaderTheme.oledBlack:
      case MangaReaderTheme.zincDark:
      case MangaReaderTheme.warmSepia:
        return Colors.white;
      case MangaReaderTheme.light:
        return const Color(0xFF09090B);
    }
  }

  String get label {
    switch (this) {
      case MangaReaderTheme.oledBlack:
        return 'OLED';
      case MangaReaderTheme.zincDark:
        return 'Zinc';
      case MangaReaderTheme.warmSepia:
        return 'Сепия';
      case MangaReaderTheme.light:
        return 'Светлый';
    }
  }
}

extension MangaImageFitExt on MangaImageFit {
  BoxFit get boxFit {
    switch (this) {
      case MangaImageFit.contain:
        return BoxFit.contain;
      case MangaImageFit.fitWidth:
        return BoxFit.fitWidth;
      case MangaImageFit.fitHeight:
        return BoxFit.fitHeight;
      case MangaImageFit.cover:
        return BoxFit.cover;
    }
  }

  String get label {
    switch (this) {
      case MangaImageFit.contain:
        return 'Целиком';
      case MangaImageFit.fitWidth:
        return 'По ширине';
      case MangaImageFit.fitHeight:
        return 'По высоте';
      case MangaImageFit.cover:
        return 'Заполнить';
    }
  }
}

class MangaReaderSettings extends ChangeNotifier {
  static const String _prefReadingMode = 'manga_reader_reading_mode';
  static const String _prefTheme = 'manga_reader_theme';
  static const String _prefImageFit = 'manga_reader_image_fit';
  static const String _prefPageSpacing = 'manga_reader_page_spacing';
  static const String _prefKeepScreenOn = 'manga_reader_keep_screen_on';
  static const String _prefShowPageNumber = 'manga_reader_show_page_number';

  static MangaReaderSettings? _instance;
  static MangaReaderSettings get instance => _instance ??= MangaReaderSettings();

  MangaReadingMode _readingMode = MangaReadingMode.pagedRtl;
  MangaReaderTheme _theme = MangaReaderTheme.oledBlack;
  MangaImageFit _imageFit = MangaImageFit.contain;
  double _pageSpacing = 0.0;
  bool _keepScreenOn = false;
  bool _showPageNumberOverlay = true;
  bool _isLoaded = false;

  MangaReadingMode get readingMode => _readingMode;
  MangaReaderTheme get theme => _theme;
  MangaImageFit get imageFit => _imageFit;
  double get pageSpacing => _pageSpacing;
  bool get keepScreenOn => _keepScreenOn;
  bool get showPageNumberOverlay => _showPageNumberOverlay;
  bool get isLoaded => _isLoaded;

  MangaReaderSettings() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final modeStr = prefs.getString(_prefReadingMode);
      if (modeStr != null) {
        _readingMode = MangaReadingMode.values.firstWhere(
          (e) => e.name == modeStr,
          orElse: () => MangaReadingMode.pagedRtl,
        );
      }

      final themeStr = prefs.getString(_prefTheme);
      if (themeStr != null) {
        _theme = MangaReaderTheme.values.firstWhere(
          (e) => e.name == themeStr,
          orElse: () => MangaReaderTheme.oledBlack,
        );
      }

      final fitStr = prefs.getString(_prefImageFit);
      if (fitStr != null) {
        _imageFit = MangaImageFit.values.firstWhere(
          (e) => e.name == fitStr,
          orElse: () => MangaImageFit.contain,
        );
      }

      _pageSpacing = prefs.getDouble(_prefPageSpacing) ?? 0.0;
      _keepScreenOn = prefs.getBool(_prefKeepScreenOn) ?? false;
      _showPageNumberOverlay = prefs.getBool(_prefShowPageNumber) ?? true;
    } catch (_) {
      // Fallback to defaults
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
  }

  Future<void> _saveDouble(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (_) {}
  }

  Future<void> _saveBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  void setReadingMode(MangaReadingMode mode) {
    if (_readingMode == mode) return;
    _readingMode = mode;
    _saveString(_prefReadingMode, mode.name);
    notifyListeners();
  }

  void setTheme(MangaReaderTheme theme) {
    if (_theme == theme) return;
    _theme = theme;
    _saveString(_prefTheme, theme.name);
    notifyListeners();
  }

  void setImageFit(MangaImageFit fit) {
    if (_imageFit == fit) return;
    _imageFit = fit;
    _saveString(_prefImageFit, fit.name);
    notifyListeners();
  }

  void setPageSpacing(double spacing) {
    if (_pageSpacing == spacing) return;
    _pageSpacing = spacing.clamp(0.0, 32.0);
    _saveDouble(_prefPageSpacing, _pageSpacing);
    notifyListeners();
  }

  void setKeepScreenOn(bool keepOn) {
    if (_keepScreenOn == keepOn) return;
    _keepScreenOn = keepOn;
    _saveBool(_prefKeepScreenOn, keepOn);
    notifyListeners();
  }

  void setShowPageNumberOverlay(bool show) {
    if (_showPageNumberOverlay == show) return;
    _showPageNumberOverlay = show;
    _saveBool(_prefShowPageNumber, show);
    notifyListeners();
  }

  /// Safe lookup helper that works even if Provider is not in the ancestor tree.
  static MangaReaderSettings of(BuildContext context, {bool listen = false}) {
    try {
      return Provider.of<MangaReaderSettings>(context, listen: listen);
    } catch (_) {
      return MangaReaderSettings.instance;
    }
  }
}
