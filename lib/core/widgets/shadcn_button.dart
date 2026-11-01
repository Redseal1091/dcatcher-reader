import 'package:flutter/material.dart';
import '../theme/shadcn_colors.dart';

enum ButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  destructive,
}

class ShadcnButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double? width;

  const ShadcnButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color textCol;

    switch (variant) {
      case ButtonVariant.primary:
        bg = ShadcnColors.primary;
        border = ShadcnColors.primary;
        textCol = ShadcnColors.primaryForeground;
        break;
      case ButtonVariant.secondary:
        bg = ShadcnColors.card;
        border = ShadcnColors.border;
        textCol = ShadcnColors.foreground;
        break;
      case ButtonVariant.outline:
        bg = Colors.transparent;
        border = ShadcnColors.border;
        textCol = ShadcnColors.foreground;
        break;
      case ButtonVariant.ghost:
        bg = Colors.transparent;
        border = Colors.transparent;
        textCol = ShadcnColors.foreground;
        break;
      case ButtonVariant.destructive:
        bg = ShadcnColors.exclude;
        border = ShadcnColors.exclude;
        textCol = Colors.white;
        break;
    }

    return SizedBox(
      width: width,
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border, width: 1),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: textCol,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 16, color: textCol),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          text,
                          style: TextStyle(
                            color: textCol,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
