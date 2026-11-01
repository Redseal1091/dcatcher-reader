import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/shadcn_colors.dart';
import '../../../core/theme/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();

    return Scaffold(
      backgroundColor: ShadcnColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: ShadcnColors.foreground, size: 20),
            SizedBox(width: 8),
            Text('Настройки DCatcher', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // Брендинг Паприка
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2B0B14), Color(0xFF14080D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x66E11D48)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE11D48),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.psychology_alt_rounded, color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DCatcher • DC Mini',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ловец снов и историй (отсылка к шедевру «Паприка» Сатоси Кона)',
                        style: TextStyle(
                          color: Color(0xFFE2B0BE),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Раздел 1: Оттенки фона
          const Text(
            'Оттенки фона оформления',
            style: TextStyle(
              color: ShadcnColors.foreground,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Выберите цветовую палитру интерфейса по вашему вкусу',
            style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildShadeChip(
                context,
                title: 'Паприка Алый',
                subtitle: '#0F080A',
                accentColor: const Color(0xFFE11D48),
                isSelected: settings.themeShade == AppThemeShade.paprika,
                onTap: () => settings.setThemeShade(AppThemeShade.paprika),
              ),
              _buildShadeChip(
                context,
                title: 'Zinc Dark',
                subtitle: '#09090B',
                accentColor: const Color(0xFFFAFAFA),
                isSelected: settings.themeShade == AppThemeShade.zinc,
                onTap: () => settings.setThemeShade(AppThemeShade.zinc),
              ),
              _buildShadeChip(
                context,
                title: 'OLED Black',
                subtitle: '#000000',
                accentColor: Colors.white,
                isSelected: settings.themeShade == AppThemeShade.oled,
                onTap: () => settings.setThemeShade(AppThemeShade.oled),
              ),
              _buildShadeChip(
                context,
                title: 'Midnight Navy',
                subtitle: '#080C15',
                accentColor: const Color(0xFF38BDF8),
                isSelected: settings.themeShade == AppThemeShade.navy,
                onTap: () => settings.setThemeShade(AppThemeShade.navy),
              ),
              _buildShadeChip(
                context,
                title: 'Emerald Forest',
                subtitle: '#06100A',
                accentColor: const Color(0xFF10B981),
                isSelected: settings.themeShade == AppThemeShade.forest,
                onTap: () => settings.setThemeShade(AppThemeShade.forest),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Раздел 2: 18+ Контент
          const Text(
            'Возрастной контент',
            style: TextStyle(
              color: ShadcnColors.foreground,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ShadcnColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ShadcnColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: settings.allowAdultContent ? const Color(0x33EF4444) : ShadcnColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: settings.allowAdultContent ? ShadcnColors.exclude : ShadcnColors.border),
                  ),
                  child: Center(
                    child: Text(
                      '18+',
                      style: TextStyle(
                        color: settings.allowAdultContent ? ShadcnColors.exclude : ShadcnColors.mutedForeground,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Разрешить контент 18+',
                        style: TextStyle(
                          color: ShadcnColors.foreground,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Отображать взрослые тайтлы (эротика, яой, хентай, насилие)',
                        style: TextStyle(
                          color: ShadcnColors.mutedForeground,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.allowAdultContent,
                  activeColor: ShadcnColors.exclude,
                  onChanged: (val) => settings.setAllowAdultContent(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Раздел 3: Источники каталогов
          const Text(
            'Источники по разделам',
            style: TextStyle(
              color: ShadcnColors.foreground,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Выберите активные парсеры и базы данных для каждого типа',
            style: TextStyle(color: ShadcnColors.mutedForeground, fontSize: 12),
          ),
          const SizedBox(height: 12),

          _buildSourceTile(
            catalogName: 'Манхва (Корея)',
            icon: Icons.auto_stories,
            currentSource: settings.manhwaSource,
            options: const ['Asura Scans', 'MangaDex', 'MangaLib', 'Remanga'],
            onSelect: (s) => settings.setSource('manhwa', s),
          ),
          _buildSourceTile(
            catalogName: 'Маньхуа (Китай)',
            icon: Icons.bubble_chart,
            currentSource: settings.manhuaSource,
            options: const ['MangaBuff', 'MangaDex', 'MangaLib', 'Remanga'],
            onSelect: (s) => settings.setSource('manhua', s),
          ),
          _buildSourceTile(
            catalogName: 'Манга (Япония)',
            icon: Icons.menu_book,
            currentSource: settings.mangaSource,
            options: const ['MangaDex', 'MangaLib', 'Asura Scans', 'Remanga'],
            onSelect: (s) => settings.setSource('manga', s),
          ),
          _buildSourceTile(
            catalogName: 'Ранобе (Лайт-новеллы)',
            icon: Icons.library_books,
            currentSource: settings.ranobeSource,
            options: const ['DCatcher Novels', 'RanobeHub', 'RuLate'],
            onSelect: (s) => settings.setSource('ranobe', s),
          ),
          _buildSourceTile(
            catalogName: 'Книги (Художественные)',
            icon: Icons.book,
            currentSource: settings.booksSource,
            options: const ['Флибуста (Flibusta)', 'Открытая библиотека классики', 'Мои файлы (.txt/.fb2)'],
            onSelect: (s) => settings.setSource('books', s),
          ),
        ],
      ),
    );
  }

  Widget _buildShadeChip(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withValues(alpha: 0.16) : ShadcnColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? accentColor : ShadcnColors.border,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(Icons.check, size: 10, color: Colors.black),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : ShadcnColors.foreground,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : ShadcnColors.mutedForeground,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceTile({
    required String catalogName,
    required IconData icon,
    required String currentSource,
    required List<String> options,
    required Function(String) onSelect,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ShadcnColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadcnColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: ShadcnColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  catalogName,
                  style: const TextStyle(color: ShadcnColors.foreground, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Источник: $currentSource',
                  style: const TextStyle(color: ShadcnColors.mutedForeground, fontSize: 11),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.arrow_drop_down, color: ShadcnColors.mutedForeground),
            onSelected: onSelect,
            itemBuilder: (_) => options
                .map((opt) => PopupMenuItem(
                      value: opt,
                      child: Text(
                        opt,
                        style: TextStyle(
                          color: opt == currentSource ? ShadcnColors.accent : ShadcnColors.foreground,
                          fontWeight: opt == currentSource ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
