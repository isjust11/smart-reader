import 'package:flutter/material.dart';
import 'package:readbox/gen/i18n/generated_locales/l10n.dart';

/// Banner hướng dẫn hiển thị phía trên preview khi đang ở chế độ "thêm dòng
/// thủ công" — đổi nội dung tuỳ đã vẽ xong khung hay chưa.
class OcrAddLineHintBanner extends StatelessWidget {
  final bool hasPendingRect;

  const OcrAddLineHintBanner({super.key, required this.hasPendingRect});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        hasPendingRect ? l.ocr_add_line_selected_hint : l.ocr_add_line_draw_hint,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Nút bật/tắt chế độ "thêm dòng thủ công" (vẽ khung cho vùng OCR bỏ sót).
class OcrAddLineToggleButton extends StatelessWidget {
  final bool active;
  final VoidCallback? onPressed;

  const OcrAddLineToggleButton({
    super.key,
    required this.active,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: active ? colorScheme.primary : colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_box_outlined,
                size: 18,
                color: active ? colorScheme.onPrimary : colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l.ocr_add_line,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? colorScheme.onPrimary : colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thanh hành động "Vẽ lại" / "Insert" hiển thị sau khi đã kéo xong một khung
/// mới, cho phép xác nhận hoặc huỷ để vẽ lại.
class OcrAddLineInsertActions extends StatelessWidget {
  final VoidCallback onRedraw;
  final VoidCallback onConfirm;

  const OcrAddLineInsertActions({
    super.key,
    required this.onRedraw,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onRedraw,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l.ocr_redraw),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.add_task, size: 16),
              label: Text(l.ocr_insert),
            ),
          ),
        ],
      ),
    );
  }
}
