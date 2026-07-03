import 'package:flutter/material.dart';
import 'package:readbox/res/dimens.dart';

/// Card công cụ dùng trong HomeScreen — horizontal scroll section.
class ToolCardWidget extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final VoidCallback? onTap;
  final bool comingSoon;

  const ToolCardWidget({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    this.onTap,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Opacity(
      opacity: comingSoon ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: comingSoon ? null : onTap,
        child: Container(
          width: 88,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.SIZE_8,
            vertical: AppDimens.SIZE_12,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppDimens.SIZE_12),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(AppDimens.SIZE_12),
                    ),
                    child: Center(
                      child: Icon(icon, color: iconColor, size: AppDimens.SIZE_22),
                    ),
                  ),
                  if (comingSoon)
                    Positioned(
                      top: -4,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Soon',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppDimens.SIZE_8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
