import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:readbox/blocs/ocr/ocr_editor_state.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/gen/i18n/generated_locales/l10n.dart';
import 'package:readbox/ui/widget/app_widgets/ocr_bbox_overlay.dart';
import 'package:readbox/utils/ocr_add_line_geometry.dart';

/// Nội dung chính của preview: ảnh trang (worker render sẵn / PDF render tại
/// máy / ảnh gốc) + overlay bbox có thể click, cùng lớp gesture vẽ khung mới
/// khi ở chế độ "thêm dòng thủ công".
///
/// Ảnh + overlay được dựng trong ĐÚNG hệ toạ độ pixel gốc của OCR
/// (page.width x page.height, scale 1:1 — bbox không cần quy đổi) rồi để
/// [FittedBox] ở widget cha co toàn khối xuống vừa khung nhìn bằng MỘT phép
/// biến đổi đồng nhất, tránh lệch dồn giữa ảnh và bbox.
class OcrPageCanvas extends StatelessWidget {
  final OcrJobModel job;
  final OcrPageModel page;
  final OcrEditorSelection? selection;
  final bool isPdf;
  final Uint8List? pdfBytes;
  final bool showDocumentBackground;
  final ValueChanged<int> onLineTap;
  final ValueChanged<int> onImageTap;
  final ValueChanged<int> onTableTap;

  /// Chế độ vẽ khung mới đang bật.
  final bool addMode;

  /// Khung đang vẽ hoặc chờ xác nhận.
  final Rect? drawRect;

  /// Khung chờ Insert — cho phép kéo di chuyển.
  final bool pendingDraggable;

  final GestureDragStartCallback? onDrawStart;
  final GestureDragUpdateCallback? onDrawUpdate;
  final GestureDragEndCallback? onDrawEnd;
  final ValueChanged<Offset>? onPendingMove;
  final void Function(OcrPendingRectEdge edge, Offset delta)? onPendingResize;

  /// Khung dòng đang chọn — cho phép kéo / chỉnh rộng (giống thêm dòng).
  final Rect? selectedLineRect;
  final ValueChanged<Offset>? onSelectedLineMove;
  final void Function(OcrPendingRectEdge edge, Offset delta)? onSelectedLineResize;
  final VoidCallback? onSelectedLineEditEnd;

  const OcrPageCanvas({
    super.key,
    required this.job,
    required this.page,
    required this.isPdf,
    this.selection,
    this.pdfBytes,
    this.showDocumentBackground = true,
    required this.onLineTap,
    required this.onImageTap,
    required this.onTableTap,
    this.addMode = false,
    this.drawRect,
    this.pendingDraggable = false,
    this.onDrawStart,
    this.onDrawUpdate,
    this.onDrawEnd,
    this.onPendingMove,
    this.onPendingResize,
    this.selectedLineRect,
    this.onSelectedLineMove,
    this.onSelectedLineResize,
    this.onSelectedLineEditEnd,
  });

  @override
  Widget build(BuildContext context) {
    final networkImageUrl = page.pageImageUrl;
    final url = job.fileUrl;
    Widget? imageWidget;

    if (showDocumentBackground) {
      if (networkImageUrl != null && networkImageUrl.isNotEmpty) {
        imageWidget = CachedNetworkImage(
          imageUrl: networkImageUrl,
          fit: BoxFit.fill,
          placeholder: (_, __) =>
              const Center(child: CircularProgressIndicator()),
          errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
        );
      } else if (url == null) {
        return Text(AppLocalizations.current.ocr_no_source_file);
      } else if (isPdf) {
        if (pdfBytes == null) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(AppLocalizations.current.ocr_pdf_render_failed),
          );
        }
        // fill: ảnh đã được render đúng page.width x page.height (khớp không
        // gian pixel mà worker OCR dùng để tính bbox) nên không cần letterbox.
        imageWidget = Image.memory(pdfBytes!, fit: BoxFit.fill);
      } else {
        imageWidget = CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.fill,
          placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(),
          ),
          errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
        );
      }
    }

    final pageW = page.width > 0 ? page.width.toDouble() : 1000.0;
    final pageH = page.height > 0 ? page.height.toDouble() : 1400.0;

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: pageW,
        height: pageH,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showDocumentBackground)
              imageWidget!
            else ...[
              const ColoredBox(color: Colors.white),
              _OcrTextContentLayer(page: page),
            ],
            OcrBboxOverlay(
              page: page,
              displaySize: Size(pageW, pageH),
              selection: selection,
              onLineTap: onLineTap,
              onImageTap: onImageTap,
              onTableTap: onTableTap,
            ),
            if (addMode) ...[
              if (!pendingDraggable)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: onDrawStart,
                    onPanUpdate: onDrawUpdate,
                    onPanEnd: onDrawEnd,
                    child: drawRect != null
                        ? CustomPaint(
                            painter: _DrawRectPainter(rect: drawRect),
                          )
                        : null,
                  ),
                ),
              if (pendingDraggable && drawRect != null)
                _buildEditableRectOverlay(
                  rect: drawRect!,
                  onMove: onPendingMove,
                  onResize: onPendingResize,
                ),
            ] else if (selectedLineRect != null && !selectedLineRect!.isEmpty)
              _buildEditableRectOverlay(
                rect: selectedLineRect!,
                onMove: onSelectedLineMove,
                onResize: onSelectedLineResize,
                onEditEnd: onSelectedLineEditEnd,
                accent: Colors.blue,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableRectOverlay({
    required Rect rect,
    ValueChanged<Offset>? onMove,
    void Function(OcrPendingRectEdge edge, Offset delta)? onResize,
    VoidCallback? onEditEnd,
    Color accent = Colors.amber,
  }) {
    final hitPad = OcrAddLineGeometry.pendingHitPadding(rect);
    return Positioned(
      left: rect.left - hitPad.left,
      top: rect.top - hitPad.top,
      width: rect.width + hitPad.horizontal,
      height: rect.height + hitPad.vertical,
      child: _EditableRectEditor(
        rect: rect,
        hitPad: hitPad,
        accent: accent,
        onMove: onMove,
        onResize: onResize,
        onEditEnd: onEditEnd,
      ),
    );
  }
}

/// Render text OCR lên canvas trắng để kiểm tra bố cục sau khi ẩn nền scan.
class _OcrTextContentLayer extends StatelessWidget {
  final OcrPageModel page;

  const _OcrTextContentLayer({required this.page});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OcrTextContentPainter(page: page),
      size: Size.infinite,
    );
  }
}

class _OcrTextContentPainter extends CustomPainter {
  final OcrPageModel page;

  const _OcrTextContentPainter({required this.page});

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in page.lines) {
      final text = line.text.trim();
      final rect = OcrAddLineGeometry.bboxRect(line.bbox);
      if (text.isEmpty || rect.isEmpty) continue;

      final style = line.style ?? const OcrTextStyleModel();
      final painter = TextPainter(
        text: TextSpan(text: text, style: _textStyle(style, rect)),
        textAlign: _textAlign(style.align),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: rect.width);

      final top = rect.top + math.max(0, (rect.height - painter.height) / 2);
      painter.paint(canvas, Offset(rect.left, top));
    }
  }

  TextStyle _textStyle(OcrTextStyleModel style, Rect rect) {
    return TextStyle(
      fontFamily: style.fontFamily,
      // Ưu tiên khớp bbox của tài liệu thay vì cỡ chữ UI 11-18pt.
      fontSize: (rect.height * 0.72).clamp(6.0, rect.height),
      color: _parseColor(style.colorHex) ?? Colors.black,
      fontWeight: style.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
      decoration: style.underline ? TextDecoration.underline : null,
      height: style.lineHeight,
    );
  }

  TextAlign _textAlign(String? align) {
    switch (align) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final value = hex.replaceFirst('#', '');
    final normalized = value.length == 6 ? 'FF$value' : value;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  @override
  bool shouldRepaint(covariant _OcrTextContentPainter oldDelegate) =>
      oldDelegate.page != page;
}

/// Khung có thể kéo giữa / kéo mép trái-phải để chỉnh vị trí và chiều rộng.
class _EditableRectEditor extends StatelessWidget {
  final Rect rect;
  final EdgeInsets hitPad;
  final Color accent;
  final ValueChanged<Offset>? onMove;
  final void Function(OcrPendingRectEdge edge, Offset delta)? onResize;
  final VoidCallback? onEditEnd;

  const _EditableRectEditor({
    required this.rect,
    required this.hitPad,
    this.accent = Colors.amber,
    this.onMove,
    this.onResize,
    this.onEditEnd,
  });

  @override
  Widget build(BuildContext context) {
    final edgeStrip = OcrAddLineGeometry.edgeHitStripWidth(hitPad);
    final localRect = Rect.fromLTWH(
      hitPad.left,
      hitPad.top,
      rect.width,
      rect.height,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: localRect,
          child: CustomPaint(
            painter: _DrawRectPainter(
              rect: Offset.zero & Size(rect.width, rect.height),
              editable: true,
              accent: accent,
            ),
            size: Size(rect.width, rect.height),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: edgeStrip,
          child: _EdgeHandle(
            cursor: SystemMouseCursors.resizeLeftRight,
            onPanUpdate: (d) =>
                onResize?.call(OcrPendingRectEdge.left, d.delta),
            onPanEnd: onEditEnd,
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: edgeStrip,
          child: _EdgeHandle(
            cursor: SystemMouseCursors.resizeLeftRight,
            onPanUpdate: (d) =>
                onResize?.call(OcrPendingRectEdge.right, d.delta),
            onPanEnd: onEditEnd,
          ),
        ),
        Positioned(
          left: edgeStrip,
          right: edgeStrip,
          top: 0,
          bottom: 0,
          child: _MoveHandle(
            onPanUpdate: (d) => onMove?.call(d.delta),
            onPanEnd: onEditEnd,
          ),
        ),
      ],
    );
  }
}

class _EdgeHandle extends StatelessWidget {
  final MouseCursor cursor;
  final GestureDragUpdateCallback onPanUpdate;
  final VoidCallback? onPanEnd;

  const _EdgeHandle({
    required this.cursor,
    required this.onPanUpdate,
    this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: onPanUpdate,
        onPanEnd: (_) => onPanEnd?.call(),
      ),
    );
  }
}

class _MoveHandle extends StatelessWidget {
  final GestureDragUpdateCallback onPanUpdate;
  final VoidCallback? onPanEnd;

  const _MoveHandle({required this.onPanUpdate, this.onPanEnd});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: onPanUpdate,
        onPanEnd: (_) => onPanEnd?.call(),
      ),
    );
  }
}

/// Vẽ khung xem trước khi người dùng đang kéo để tạo dòng text thủ công.
class _DrawRectPainter extends CustomPainter {
  final Rect? rect;
  final bool editable;
  final Color accent;

  const _DrawRectPainter({
    required this.rect,
    this.editable = false,
    this.accent = Colors.amber,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = rect;
    if (r == null) return;
    final fillPaint = Paint()
      ..color = accent.withValues(alpha: editable ? 0.28 : 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawRect(r, fillPaint);
    final borderPaint = Paint()
      ..color = _tone(accent, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size.width / 250);
    canvas.drawRect(r, borderPaint);

    if (editable) {
      final handlePaint = Paint()
        ..color = _tone(accent, 0.5)
        ..style = PaintingStyle.fill;
      final handleW = OcrAddLineGeometry.edgeVisualWidth(r);
      final handleH = (r.height * 0.72).clamp(16.0, r.height);
      final top = r.top + (r.height - handleH) / 2;

      for (final cx in [r.left + 2 + handleW / 2, r.right - 2 - handleW / 2]) {
        final handleRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, top + handleH / 2),
            width: handleW * 0.55,
            height: handleH,
          ),
          const Radius.circular(4),
        );
        canvas.drawRRect(handleRect, handlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawRectPainter oldDelegate) =>
      oldDelegate.rect != rect ||
      oldDelegate.editable != editable ||
      oldDelegate.accent != accent;

  static Color _tone(Color color, double amount) =>
      Color.lerp(color, Colors.black, amount) ?? color;
}
