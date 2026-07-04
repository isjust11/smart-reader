import 'package:flutter/material.dart';
import 'package:readbox/blocs/ocr/ocr_editor_state.dart';
import 'package:readbox/gen/i18n/generated_locales/l10n.dart';

/// Thanh thao tác cố định phía dưới vùng editor — gom nút thêm dòng, xác nhận
/// khung vẽ, và các thao tác trên dòng đang chọn.
class OcrEditorOperationBar extends StatelessWidget {
  final bool addMode;
  final bool hasPendingRect;
  final bool canAddLine;
  final OcrEditorSelection? selection;
  final VoidCallback? onToggleAddMode;
  final VoidCallback? onRedraw;
  final VoidCallback? onInsert;
  final VoidCallback? onMoveLineUp;
  final VoidCallback? onMoveLineDown;
  final VoidCallback? onDeleteLine;
  final bool canMoveLineUp;
  final bool canMoveLineDown;

  const OcrEditorOperationBar({
    super.key,
    required this.addMode,
    required this.hasPendingRect,
    this.canAddLine = true,
    this.selection,
    this.onToggleAddMode,
    this.onRedraw,
    this.onInsert,
    this.onMoveLineUp,
    this.onMoveLineDown,
    this.onDeleteLine,
    this.canMoveLineUp = true,
    this.canMoveLineDown = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final isLine = selection?.kind == OcrEditorSelectionKind.line;
    final canMoveSelection = selection != null &&
        (selection!.kind == OcrEditorSelectionKind.line ||
            selection!.kind == OcrEditorSelectionKind.image ||
            selection!.kind == OcrEditorSelectionKind.table);

    return Material(
      color: cs.surfaceContainerLow,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: cs.outline.withValues(alpha: 0.12)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canAddLine) ...[
                      _OpBtn(
                        icon: Icons.add_box_outlined,
                        label: l.ocr_add_line,
                        tooltip: l.ocr_add_line,
                        selected: addMode,
                        onPressed: onToggleAddMode,
                      ),
                      if (addMode && hasPendingRect) ...[
                        const SizedBox(width: 4),
                        _OpBtn(
                          icon: Icons.refresh,
                          label: l.ocr_redraw,
                          tooltip: l.ocr_redraw,
                          onPressed: onRedraw,
                        ),
                        const SizedBox(width: 4),
                        _OpBtn(
                          icon: Icons.add_task,
                          label: l.ocr_insert,
                          tooltip: l.ocr_insert,
                          filled: true,
                          onPressed: onInsert,
                        ),
                      ],
                    ],
                    if (canMoveSelection) ...[
                      if (canAddLine) _vDivider(cs),
                      _OpIcon(
                        icon: Icons.arrow_upward,
                        tooltip: l.ocr_move_up,
                        onPressed: canMoveLineUp ? onMoveLineUp : null,
                      ),
                      _OpIcon(
                        icon: Icons.arrow_downward,
                        tooltip: l.ocr_move_down,
                        onPressed: canMoveLineDown ? onMoveLineDown : null,
                      ),
                    ],
                    if (isLine) ...[
                      if (canMoveSelection || canAddLine) _vDivider(cs),
                      _OpIcon(
                        icon: Icons.delete_outline,
                        tooltip: l.ocr_delete_line,
                        color: cs.error,
                        onPressed: onDeleteLine,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vDivider(ColorScheme cs) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: cs.outline.withValues(alpha: 0.15),
    );
  }
}

class _OpBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool selected;
  final bool filled;
  final VoidCallback? onPressed;

  const _OpBtn({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.selected = false,
    this.filled = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = filled
        ? cs.onPrimary
        : selected
            ? cs.onPrimaryContainer
            : cs.primary;
    final bg = filled
        ? cs.primary
        : selected
            ? cs.primaryContainer
            : cs.surface;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback? onPressed;

  const _OpIcon({
    required this.icon,
    required this.tooltip,
    this.color,
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
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color ?? cs.onSurfaceVariant),
      ),
    );
  }
}
