import 'package:flutter/material.dart';

class ShadcnColors {
  // Zinc dark palette
  static const Color background = Color(0xFF09090B);
  static const Color surface = Color(0xFF121215);
  static const Color card = Color(0xFF18181B);
  static const Color border = Color(0xFF27272A);
  static const Color borderSubtle = Color(0x33FFFFFF);

  // Text
  static const Color foreground = Color(0xFFFAFAFA);
  static const Color mutedForeground = Color(0xFFA1A1AA);

  // Glassmorphism (Frosted glass overlay)
  static const Color glassBackground = Color(0xCC121215); // ~80%
  static const Color glassBorder = Color(0x26FFFFFF);     // 15% white border

  // Accent & Action
  static const Color primary = Color(0xFFFAFAFA);
  static const Color primaryForeground = Color(0xFF09090B);
  static const Color accent = Color(0xFF3B82F6); // Clean blue accent
  
  // Status Colors (Shadcn badge palette)
  static const Color reading = Color(0xFFF59E0B);     // Amber
  static const Color completed = Color(0xFF10B981);   // Emerald
  static const Color planned = Color(0xFF8B5CF6);     // Purple
  static const Color dropped = Color(0xFF71717A);     // Zinc-500
  static const Color exclude = Color(0xFFEF4444);     // Destructive / Red

  // Status background tones for badges
  static const Color readingBg = Color(0x26F59E0B);
  static const Color completedBg = Color(0x2610B981);
  static const Color plannedBg = Color(0x268B5CF6);
  static const Color excludeBg = Color(0x26EF4444);
}
