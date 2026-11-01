import 'package:flutter/material.dart';
import '../theme/shadcn_colors.dart';

enum BadgeVariant {
  defaultVariant,
  secondary,
  outline,
  reading,
  completed,
  planned,
  destructive,
  rating,
}

class ShadcnBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final IconData? icon;

  const ShadcnBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.defaultVariant,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;

    switch (variant) {
      case BadgeVariant.defaultVariant:
        bg = ShadcnColors.primary;
        border = ShadcnColors.primary;
        text = ShadcnColors.primaryForeground;
        break;
      case BadgeVariant.secondary:
        bg = ShadcnColors.card;
        border = ShadcnColors.border;
        text = ShadcnColors.foreground;
        break;
      case BadgeVariant.outline:
        bg = Colors.transparent;
        border = ShadcnColors.border;
        text = ShadcnColors.foreground;
        break;
      case BadgeVariant.reading:
        bg = ShadcnColors.readingBg;
        border = ShadcnColors.reading.withValues(alpha: 0.5);
        text = ShadcnColors.reading;
        break;
      case BadgeVariant.completed:
        bg = ShadcnColors.completedBg;
        border = ShadcnColors.completed.withValues(alpha: 0.5);
        text = ShadcnColors.completed;
        break;
      case BadgeVariant.planned:
        bg = ShadcnColors.plannedBg;
        border = ShadcnColors.planned.withValues(alpha: 0.5);
        text = ShadcnColors.planned;
        break;
      case BadgeVariant.destructive:
        bg = ShadcnColors.excludeBg;
        border = ShadcnColors.exclude.withValues(alpha: 0.5);
        text = ShadcnColors.exclude;
        break;
      case BadgeVariant.rating:
        bg = const Color(0x33F43F5E);
        border = const Color(0xFFF43F5E);
        text = const Color(0xFFFB7185);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: text),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
