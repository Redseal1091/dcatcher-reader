import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/sources/source_manager.dart';

enum AppThemeShade {
  zinc,      // Классический Shadcn Dark Zinc (#09090B)
  oled,      // Чистый OLED чёрный (#000000)
  paprika,   // Паприка: глубокая ночь с алым акцентом (#0F080A + #E11D48)
  navy,      // Глубокий полуночный индиго (#080C15 + #38BDF8)
  forest,    // Тёмный изумруд (#06100A + #10B981)
}

class ThemeColors {
  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  final Color primary;
  final Color primaryForeground;
  final Color accent;
  final Color mutedForeground;

  const ThemeColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.primary,
    required this.primaryForeground,
    required this.accent,
    this.mutedForeground = const Color(0xFFA1A1AA),
  });
}

class AppSettingsProvider extends ChangeNotifier {
  AppThemeShade _themeShade = AppThemeShade.paprika; // По умолчанию Паприка с отсылкой к DC Mini!
  bool _allowAdultContent = false; // 18+ переключатель

  // Выбранные источники для каталогов (свободный международный доступ без блокировок РФ)
  String _manhwaSource = 'Asura Scans';
  String _manhuaSource = 'MangaBuff';
  String _mangaSource = 'MangaDex';
  String _ranobeSource = 'DCatcher Novels';
  String _booksSource = 'Флибуста (Flibusta)';

  AppThemeShade get themeShade => _themeShade;
  bool get allowAdultContent => _allowAdultContent;

  String get manhwaSource => _manhwaSource;
  String get manhuaSource => _manhuaSource;
  String get mangaSource => _mangaSource;
  String get ranobeSource => _ranobeSource;
  String get booksSource => _booksSource;

  AppSettingsProvider() {
    _loadSettings();
  }

  ThemeColors get colors {
    switch (_themeShade) {
      case AppThemeShade.oled:
        return const ThemeColors(
          background: Color(0xFF000000),
          surface: Color(0xFF0D0D0D),
          card: Color(0xFF141414),
          border: Color(0xFF262626),
          primary: Color(0xFFFFFFFF),
          primaryForeground: Color(0xFF000000),
          accent: Color(0xFF38BDF8),
          mutedForeground: Color(0xFFA1A1AA),
        );
      case AppThemeShade.paprika:
        return const ThemeColors(
          background: Color(0xFF0F080A),
          surface: Color(0xFF180E12),
          card: Color(0xFF221319),
          border: Color(0xFF3B1A25),
          primary: Color(0xFFE11D48), // Яркий алый цвет Паприки
          primaryForeground: Color(0xFFFFFFFF),
          accent: Color(0xFFFB7185),
          mutedForeground: Color(0xFFB89BA3),
        );
      case AppThemeShade.navy:
        return const ThemeColors(
          background: Color(0xFF080C15),
          surface: Color(0xFF0F172A),
          card: Color(0xFF1E293B),
          border: Color(0xFF334155),
          primary: Color(0xFF38BDF8),
          primaryForeground: Color(0xFF080C15),
          accent: Color(0xFF0284C7),
          mutedForeground: Color(0xFF94A3B8),
        );
      case AppThemeShade.forest:
        return const ThemeColors(
          background: Color(0xFF06100A),
          surface: Color(0xFF0C1D13),
          card: Color(0xFF142C1D),
          border: Color(0xFF214A31),
          primary: Color(0xFF10B981),
          primaryForeground: Color(0xFF06100A),
          accent: Color(0xFF34D399),
          mutedForeground: Color(0xFF86A795),
        );
      case AppThemeShade.zinc:
        return const ThemeColors(
          background: Color(0xFF09090B),
          surface: Color(0xFF121215),
          card: Color(0xFF18181B),
          border: Color(0xFF27272A),
          primary: Color(0xFFFAFAFA),
          primaryForeground: Color(0xFF09090B),
          accent: Color(0xFF3B82F6),
          mutedForeground: Color(0xFFA1A1AA),
        );
    }
  }

  ThemeData get themeData {
    final c = colors;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme.dark(
        primary: c.primary,
        onPrimary: c.primaryForeground,
        surface: c.surface,
        onSurface: const Color(0xFFFAFAFA),
        outline: c.border,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shadeIdx = prefs.getInt('theme_shade');
      if (shadeIdx != null && shadeIdx >= 0 && shadeIdx < AppThemeShade.values.length) {
        _themeShade = AppThemeShade.values[shadeIdx];
      }
      _allowAdultContent = prefs.getBool('allow_adult_content') ?? false;
      _manhwaSource = prefs.getString('source_manhwa') ?? _manhwaSource;
      _manhuaSource = prefs.getString('source_manhua') ?? _manhuaSource;
      _mangaSource = prefs.getString('source_manga') ?? _mangaSource;
      _ranobeSource = prefs.getString('source_ranobe') ?? _ranobeSource;
      _booksSource = prefs.getString('source_books') ?? _booksSource;
      SourceManager.setCurrentSource(_manhwaSource);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setThemeShade(AppThemeShade shade) async {
    _themeShade = shade;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_shade', shade.index);
  }

  Future<void> setAllowAdultContent(bool allow) async {
    _allowAdultContent = allow;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('allow_adult_content', allow);
  }

  Future<void> setSource(String catalog, String source) async {
    final prefs = await SharedPreferences.getInstance();
    if (catalog == 'manhwa') {
      _manhwaSource = source;
      await prefs.setString('source_manhwa', source);
      SourceManager.setCurrentSource(source);
    } else if (catalog == 'manhua') {
      _manhuaSource = source;
      await prefs.setString('source_manhua', source);
      SourceManager.setCurrentSource(source);
    } else if (catalog == 'manga') {
      _mangaSource = source;
      await prefs.setString('source_manga', source);
      SourceManager.setCurrentSource(source);
    } else if (catalog == 'ranobe') {
      _ranobeSource = source;
      await prefs.setString('source_ranobe', source);
    } else if (catalog == 'books') {
      _booksSource = source;
      await prefs.setString('source_books', source);
    }
    notifyListeners();
  }
}
