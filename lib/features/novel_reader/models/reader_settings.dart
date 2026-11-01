import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NovelReaderTheme {
  oledDark,     // Настоящий черный #000000 для OLED
  zincDark,     // Палитра shadcn #09090b
  warmSepia,    // Теплая бумага #221d17 (текст #d6c6b2)
  softGreen,    // Защита зрения #121e17 (текст #b5d5be)
}

class ReaderSettings extends ChangeNotifier {
  double _fontSize = 17.0;
  double _lineHeight = 1.6;
  NovelReaderTheme _theme = NovelReaderTheme.zincDark;
  final String _fontFamily = 'Roboto';

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  NovelReaderTheme get theme => _theme;
  String get fontFamily => _fontFamily;

  ReaderSettings() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble('reader_font_size') ?? 17.0;
    _lineHeight = prefs.getDouble('reader_line_height') ?? 1.6;
    final themeIdx = prefs.getInt('reader_theme_idx') ?? 1;
    _theme = NovelReaderTheme.values[themeIdx % NovelReaderTheme.values.length];
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_font_size', _fontSize);
    await prefs.setDouble('reader_line_height', _lineHeight);
    await prefs.setInt('reader_theme_idx', _theme.index);
  }

  void setFontSize(double size) {
    _fontSize = size.clamp(12.0, 32.0);
    _save();
    notifyListeners();
  }

  void setLineHeight(double height) {
    _lineHeight = height.clamp(1.2, 2.4);
    _save();
    notifyListeners();
  }

  void setTheme(NovelReaderTheme newTheme) {
    _theme = newTheme;
    _save();
    notifyListeners();
  }

  Color get backgroundColor {
    switch (_theme) {
      case NovelReaderTheme.oledDark:
        return Colors.black;
      case NovelReaderTheme.zincDark:
        return const Color(0xFF09090B);
      case NovelReaderTheme.warmSepia:
        return const Color(0xFF1E1A16);
      case NovelReaderTheme.softGreen:
        return const Color(0xFF0F1A14);
    }
  }

  Color get textColor {
    switch (_theme) {
      case NovelReaderTheme.oledDark:
        return const Color(0xFFE4E4E7);
      case NovelReaderTheme.zincDark:
        return const Color(0xFFFAFAFA);
      case NovelReaderTheme.warmSepia:
        return const Color(0xFFE8D7C3);
      case NovelReaderTheme.softGreen:
        return const Color(0xFFCEE8D6);
    }
  }
}
