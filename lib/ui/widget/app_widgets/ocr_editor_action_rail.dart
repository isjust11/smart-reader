import 'package:flutter/material.dart';
import 'package:readbox/gen/i18n/generated_locales/l10n.dart';

/// Cột action dọc bám phải **khu vực editor** (phần dưới) — undo/redo,
/// lưu và menu thao tác; không chia không gian với preview phía trên.
class OcrEditorActionRail extends StatelessWidget {
  final bool canUndo;
  final bool canRedo;
  final bool isDirty;
  final bool isSaving;
  final bool isExporting;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onSave;
  final void Function(String action) onMenuAction;

  const OcrEditorActionRail({
    super.key,
    required this.canUndo,
    required this.canRedo,
    required this.isDirty,
    required this.isSaving,
    required this.isExporting,
    this.onUndo,
    this.onRedo,
    this.onSave,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerLow,
      child: Container(
        width: 52,
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: cs.outline.withValues(alpha: 0.12)),
          ),
        ),
        child: SingleChildScrollView(
          child: IntrinsicHeight(
            child: Column(
              children: [
                const SizedBox(height: 8),
                  _RailBtn(
                    icon: Icons.undo,
                    tooltip: l.pdf_undo,
                    enabled: canUndo,
                    onPressed: onUndo,
                  ),
                  _RailBtn(
                    icon: Icons.redo,
                    tooltip: l.ocr_redo,
                    enabled: canRedo,
                    onPressed: onRedo,
                  ),
                  _RailDivider(color: cs),
                  _SaveBtn(
                    tooltip: l.ocr_save_edits,
                    isDirty: isDirty,
                    isSaving: isSaving,
                    onPressed: isDirty && !isSaving ? onSave : null,
                  ),
                  if (isDirty) ...[
                    const SizedBox(height: 4),
                    Tooltip(
                      message: l.ocr_unsaved,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: cs.tertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  _RailDivider(color: cs),
                  PopupMenuButton<String>(
                    tooltip: l.ocr_more_actions,
                    padding: EdgeInsets.zero,
                    icon: isExporting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          )
                        : Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                    onSelected: onMenuAction,
                    itemBuilder: (ctx) {
                      final loc = AppLocalizations.of(ctx);
                      return [
                        PopupMenuItem(
                          value: 'preview_edited',
                          child: Text(loc.ocr_preview_edited),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'normalize_page',
                          child: Text(loc.ocr_normalize_page_preset),
                        ),
                        PopupMenuItem(
                          value: 'body_page',
                          child: Text(loc.ocr_apply_body_page),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'txt',
                          child: Text(loc.ocr_export_txt),
                        ),
                        PopupMenuItem(
                          value: 'pdf',
                          child: Text(loc.ocr_export_searchable_pdf),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'requeue',
                          child: Text(loc.ocr_requeue),
                        ),
                      ];
                    },
                  ),
                  const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailDivider extends StatelessWidget {
  final ColorScheme color;

  const _RailDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Divider(height: 1, color: color.outline.withValues(alpha: 0.15)),
    );
  }
}

class _RailBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback? onPressed;

  const _RailBtn({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        onPressed: enabled ? onPressed : null,
        icon: Icon(
          icon,
          size: 20,
          color: enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}

class _SaveBtn extends StatelessWidget {
  final String tooltip;
  final bool isDirty;
  final bool isSaving;
  final VoidCallback? onPressed;

  const _SaveBtn({
    required this.tooltip,
    required this.isDirty,
    required this.isSaving,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = isDirty && !isSaving;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? cs.primaryContainer.withValues(alpha: 0.55) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : Icon(
                      Icons.save_outlined,
                      size: 20,
                      color: active
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.28),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
