import 'package:flutter/material.dart';
import '../theme/shadcn_colors.dart';

class FrostedGlass extends StatelessWidget {
  final Widget child;
  final double blur;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Border? border;
  final double? width;
  final double? height;

  const FrostedGlass({
    super.key,
    required this.child,
    this.blur = 16.0,
    this.borderRadius,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.border,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xF2141418), // Плотный Zinc Dark фон без артефактов буфера GPU
        borderRadius: radius,
        border: border ?? Border.all(
          color: ShadcnColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
