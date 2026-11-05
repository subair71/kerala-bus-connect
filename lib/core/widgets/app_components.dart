import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Lightweight, shared visual primitives. Native controls own interaction state.
class AppIconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool emphasized;
  const AppIconTile(this.icon, {
    super.key,
    this.size = 44,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: emphasized ? AppColors.primary : AppColors.secondaryContainer,
      borderRadius: BorderRadius.circular(size * .32),
      border: Border.all(
        color: emphasized ? AppColors.primary : AppColors.primary.withValues(alpha: .10)),
    ),
    child: Icon(icon, size: size * .52,
      color: emphasized ? Colors.white : AppColors.primary),
  );
}

class AppStatusBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color foreground, background;
  final double fontSize;
  const AppStatusBadge({
    super.key,
    required this.label,
    this.icon,
    this.foreground = AppColors.primary,
    this.background = AppColors.secondaryContainer,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: foreground.withValues(alpha: .12)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
        ],
        Flexible(child: Text(label, style: TextStyle(
          fontSize: fontSize, height: 1.25,
          fontWeight: FontWeight.w600, color: foreground))),
      ],
    ),
  );
}
