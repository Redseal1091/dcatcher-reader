import 'package:flutter/material.dart';
import '../theme/shadcn_colors.dart';

enum FilterTriState {
  ignore,   // По умолчанию (не фильтровать)
  include,  // Только этот статус
  exclude,  // ИСКЛЮЧИТЬ из выдачи (не показывать в каталоге)
}

class TriStateChip extends StatelessWidget {
  final String label;
  final FilterTriState state;
  final VoidCallback onTap;
  final IconData? defaultIcon;

  const TriStateChip({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    this.defaultIcon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;
    IconData icon;

    switch (state) {
      case FilterTriState.ignore:
        bg = ShadcnColors.card;
        border = ShadcnColors.border;
        text = ShadcnColors.mutedForeground;
        icon = defaultIcon ?? Icons.remove;
        break;
      case FilterTriState.include:
        bg = ShadcnColors.completedBg;
        border = ShadcnColors.completed;
        text = ShadcnColors.completed;
        icon = Icons.check;
        break;
      case FilterTriState.exclude:
        bg = ShadcnColors.excludeBg;
        border = ShadcnColors.exclude;
        text = ShadcnColors.exclude;
        icon = Icons.block; // 🚫
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: text),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: text,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  decoration: state == FilterTriState.exclude
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              if (state == FilterTriState.exclude) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: ShadcnColors.exclude,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'СКРЫТО',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
