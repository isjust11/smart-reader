import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:readbox/blocs/ocr/ocr_editor_state.dart';
import 'package:readbox/domain/data/models/ocr_result_model.dart';

/// Vẽ overlay bbox text / ảnh / bảng lên preview trang.
class OcrBboxOverlay extends StatelessWidget {
  final OcrPageModel page;
  final Size displaySize;
  final OcrEditorSelection? selection;
  final ValueChanged<int>? onLineTap;
  final ValueChanged<int>? onImageTap;
  final ValueChanged<int>? onTableTap;

  const OcrBboxOverlay({
    super.key,
    required this.page,
    required this.displaySize,
    this.selection,
    this.onLineTap,
    this.onImageTap,
    this.onTableTap,
  });

  @override
  Widget build(BuildContext context) {
    final ocrW = page.width > 0 ? page.width.toDouble() : displaySize.width;
    final ocrH = page.height > 0 ? page.height.toDouble() : displaySize.height;
    final scaleX = displaySize.width / ocrW;
    final scaleY = displaySize.height / ocrH;
    // Overlay được vẽ trong không gian pixel gốc của trang rồi thu nhỏ bởi
    // FittedBox — nét viền phải dày tương ứng để sau khi scale vẫn nhìn thấy.
    final baseStroke = (ocrW / 500).clamp(1.0, 6.0);

    return Stack(
      children: [
        for (var i = 0; i < page.lines.length; i++)
          _buildHitBox(
            rect: _scaleRect(_bboxRect(page.lines[i].bbox), scaleX, scaleY),
            // Dòng chưa có text (OCR bỏ sót / vừa thêm tay, chưa nhập) — vẽ
            // nét đứt màu hổ phách để nổi bật "cần nhập nội dung".
            color: page.lines[i].text.trim().isEmpty
                ? Colors.amber.shade800
                : Colors.blue,
            dashed: page.lines[i].text.trim().isEmpty,
            selected:
                selection?.kind == OcrEditorSelectionKind.line &&
                selection?.index == i,
            baseStroke: baseStroke,
            onTap: () => onLineTap?.call(i),
          ),
        for (var i = 0; i < page.images.length; i++)
          _buildHitBox(
            rect: _scaleRect(_bboxRect(page.images[i].bbox), scaleX, scaleY),
            color: page.images[i].type == 'figure'
                ? Colors.orange
                : Colors.green,
            selected:
                selection?.kind == OcrEditorSelectionKind.image &&
                selection?.index == i,
            baseStroke: baseStroke,
            onTap: () => onImageTap?.call(i),
          ),
        for (var i = 0; i < page.tables.length; i++)
          _buildHitBox(
            rect: _scaleRect(_bboxRect(page.tables[i].bbox), scaleX, scaleY),
            color: Colors.purple,
            selected:
                selection?.kind == OcrEditorSelectionKind.table &&
                selection?.index == i,
            baseStroke: baseStroke,
            onTap: () => onTableTap?.call(i),
          ),
      ],
    );
  }

  Widget _buildHitBox({
    required Rect rect,
    required Color color,
    required bool selected,
    required double baseStroke,
    required VoidCallback onTap,
    bool dashed = false,
  }) {
    if (rect.width < 2 || rect.height < 2) return const SizedBox.shrink();
    // Nét viền vẽ HẲN BÊN TRONG rect (inset stroke) để hộp không tràn ra
    // ngoài rìa chữ — bám đúng toạ độ bbox gốc.
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: _BboxPainter(
            color: color,
            selected: selected,
            baseStroke: baseStroke,
            dashed: dashed,
          ),
        ),
      ),
    );
  }

  static Rect _bboxRect(List<Offset> bbox) {
    if (bbox.isEmpty) return Rect.zero;
    final xs = bbox.map((e) => e.dx);
    final ys = bbox.map((e) => e.dy);
    return Rect.fromLTRB(
      xs.reduce(math.min),
      ys.reduce(math.min),
      xs.reduce(math.max),
      ys.reduce(math.max),
    );
  }

  static Rect _scaleRect(Rect rect, double scaleX, double scaleY) {
    return Rect.fromLTRB(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.right * scaleX,
      rect.bottom * scaleY,
    );
  }
}

/// Vẽ khung bbox với nét nằm hoàn toàn bên trong vùng (inset stroke) thay vì
/// nét giữa mặc định của [Border.all], để hộp không "tràn" ra ngoài rìa chữ
/// khi phóng to — bám sát toạ độ gốc hơn.
class _BboxPainter extends CustomPainter {
  final Color color;
  final bool selected;
  final double baseStroke;
  final bool dashed;

  const _BboxPainter({
    required this.color,
    required this.selected,
    this.baseStroke = 1.0,
    this.dashed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = selected ? baseStroke * 1.6 : baseStroke;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: selected ? 0.16 : 0.06)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, fillPaint);

    final borderPaint = Paint()
      ..color = selected ? color : color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    if (dashed) {
      _drawDashedRect(canvas, rect, borderPaint, dashLength: strokeWidth * 4);
    } else {
      canvas.drawRect(rect, borderPaint);
    }
  }

  void _drawDashedRect(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    required double dashLength,
  }) {
    final gap = dashLength * 0.7;
    void dashLine(Offset a, Offset b) {
      final total = (b - a).distance;
      if (total <= 0) return;
      final direction = (b - a) / total;
      var travelled = 0.0;
      while (travelled < total) {
        final segEnd = math.min(travelled + dashLength, total);
        canvas.drawLine(
          a + direction * travelled,
          a + direction * segEnd,
          paint,
        );
        travelled += dashLength + gap;
      }
    }

    dashLine(rect.topLeft, rect.topRight);
    dashLine(rect.topRight, rect.bottomRight);
    dashLine(rect.bottomRight, rect.bottomLeft);
    dashLine(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(covariant _BboxPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.selected != selected ||
        oldDelegate.baseStroke != baseStroke ||
        oldDelegate.dashed != dashed;
  }
}
