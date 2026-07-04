import 'package:flutter/material.dart';
import 'package:readbox/gen/i18n/generated_locales/l10n.dart';

/// Cụm nút thu nhỏ / về gốc / phóng to cho preview trang OCR.
class OcrPreviewZoomControls extends StatelessWidget {
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final VoidCallback onZoomIn;

  const OcrPreviewZoomControls({
    super.key,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.onZoomIn,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: l.ocr_zoom_out,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.remove, size: 14),
          onPressed: onZoomOut,
        ),
        IconButton(
          tooltip: l.ocr_zoom_reset,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.crop_free, size: 14),
          onPressed: onResetZoom,
        ),
        IconButton(
          tooltip: l.ocr_zoom_in,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.add, size: 14),
          onPressed: onZoomIn,
        ),
      ],
    );
  }
}
