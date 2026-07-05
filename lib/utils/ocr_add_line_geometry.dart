import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart' show EdgeInsets;
import 'package:readbox/domain/data/models/models.dart';

/// Tính toán khung dòng mới thủ công — chiều cao khớp dòng hiện có trên trang.
class OcrAddLineGeometry {
  OcrAddLineGeometry._();

  static const double _minLineWidth = 24;
  static const double _minDragWidth = 16;

  static Rect bboxRect(List<Offset> bbox) {
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

  static double pageWidth(OcrPageModel page) =>
      page.width > 0 ? page.width.toDouble() : 1000.0;

  static double pageHeight(OcrPageModel page) =>
      page.height > 0 ? page.height.toDouble() : 1400.0;

  /// Bbox phủ ≥ [ratio] diện tích trang — thường là ảnh chụp bị nhận nhầm figure.
  static bool isFullPageBbox(
    List<Offset> bbox,
    OcrPageModel page, {
    double ratio = 0.85,
  }) {
    if (bbox.isEmpty) return false;
    final pageArea = pageWidth(page) * pageHeight(page);
    if (pageArea <= 0) return false;
    final r = bboxRect(bbox);
    return r.width * r.height >= pageArea * ratio;
  }

  /// Chiều cao dòng điển hình — median các bbox text trên trang.
  static double typicalLineHeight(OcrPageModel page) {
    final heights = page.lines
        .map((l) => bboxRect(l.bbox).height)
        .where((h) => h > 4)
        .toList()
      ..sort();
    if (heights.isNotEmpty) {
      return heights[heights.length ~/ 2];
    }
    return pageHeight(page) * 0.035;
  }

  /// Chiều rộng dòng điển hình — median các bbox text trên trang.
  static double typicalLineWidth(OcrPageModel page) {
    final widths = page.lines
        .map((l) => bboxRect(l.bbox).width)
        .where((w) => w > _minLineWidth)
        .toList()
      ..sort();
    if (widths.isNotEmpty) {
      return widths[widths.length ~/ 2];
    }
    return pageWidth(page) * 0.6;
  }

  /// Snap mép trên khung mới vào lưới dòng hiện có (nếu gần).
  static double snapLineTop(double rawTop, OcrPageModel page, double lineHeight) {
    if (page.lines.isEmpty) return rawTop;

    final candidates = <double>[];
    for (final line in page.lines) {
      final r = bboxRect(line.bbox);
      candidates.add(r.top);
      candidates.add(r.bottom);
    }

    var best = rawTop;
    var bestDist = double.infinity;
    for (final y in candidates) {
      final d = (y - rawTop).abs();
      if (d < bestDist) {
        bestDist = d;
        best = y;
      }
    }
    if (bestDist <= lineHeight * 0.55) return best;
    return rawTop;
  }

  /// Tạo khung từ thao tác chạm / kéo ngang — chiều cao cố định theo tài liệu.
  static Rect buildFromDrag({
    required Offset start,
    required Offset end,
    required OcrPageModel page,
  }) {
    final lineH = typicalLineHeight(page);
    final pageW = pageWidth(page);
    final pageH = pageHeight(page);

    var left = math.min(start.dx, end.dx);
    var right = math.max(start.dx, end.dx);

    if (right - left < _minDragWidth) {
      final defaultW = typicalLineWidth(page);
      left = (start.dx - defaultW / 2).clamp(0.0, pageW - defaultW);
      right = left + defaultW;
    }

    final top = snapLineTop(start.dy, page, lineH);
    return clampToPage(
      Rect.fromLTWH(left, top, right - left, lineH),
      pageW,
      pageH,
    );
  }

  static Rect move(Rect rect, Offset delta, OcrPageModel page) {
    return clampToPage(
      rect.shift(delta),
      pageWidth(page),
      pageHeight(page),
    );
  }

  static List<Offset> rectToBbox(Rect rect) {
    return [
      Offset(rect.left, rect.top),
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.bottom),
      Offset(rect.left, rect.bottom),
    ];
  }

  static bool canMoveVertically(Rect rect, int delta, OcrPageModel page) {
    final step = typicalLineHeight(page);
    final moved = move(rect, Offset(0, delta * step), page);
    return moved.top != rect.top;
  }

  /// Kéo mép trái/phải để chỉnh chiều rộng — giữ nguyên chiều cao dòng.
  static Rect resizeWidth(
    Rect rect,
    OcrPendingRectEdge edge,
    Offset delta,
    OcrPageModel page,
  ) {
    final pageW = pageWidth(page);
    final pageH = pageHeight(page);
    var left = rect.left;
    var right = rect.right;

    switch (edge) {
      case OcrPendingRectEdge.left:
        left += delta.dx;
      case OcrPendingRectEdge.right:
        right += delta.dx;
    }

    if (right - left < _minLineWidth) {
      if (edge == OcrPendingRectEdge.left) {
        left = right - _minLineWidth;
      } else {
        right = left + _minLineWidth;
      }
    }

    return clampToPage(
      Rect.fromLTRB(left, rect.top, right, rect.bottom),
      pageW,
      pageH,
    );
  }

  static const double minTouchTarget = 48;
  static const double edgeTouchWidth = 28;

  /// Padding mở rộng vùng chạm ra ngoài khung (mép + chiều cao tối thiểu).
  static EdgeInsets pendingHitPadding(Rect rect) {
    final vertical = math.max(0.0, (minTouchTarget - rect.height) / 2);
    return EdgeInsets.fromLTRB(
      edgeTouchWidth,
      vertical,
      edgeTouchWidth,
      vertical,
    );
  }

  /// Bề rộng vùng chạm mép trái/phải (bao gồm phần tràn ra ngoài khung).
  static double edgeHitStripWidth(EdgeInsets hitPad) =>
      hitPad.left + edgeTouchWidth;

  /// Kích thước tay cầm vẽ trên UI (nhỏ hơn vùng chạm).
  static double edgeVisualWidth(Rect rect) =>
      (rect.height * 0.5).clamp(14.0, 22.0);

  static Rect clampToPage(Rect rect, double pageW, double pageH) {
    var left = rect.left.clamp(0.0, pageW - _minLineWidth);
    var top = rect.top.clamp(0.0, pageH - rect.height);
    var width = rect.width.clamp(_minLineWidth, pageW - left);
    var height = rect.height.clamp(4.0, pageH - top);
    return Rect.fromLTWH(left, top, width, height);
  }

  static bool isValidPlacement(Rect rect) => rect.width >= _minLineWidth;
}

/// Mép khung pending có thể kéo để chỉnh chiều rộng.
enum OcrPendingRectEdge { left, right }
