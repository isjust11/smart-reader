import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Rect, Size;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Gộp danh sách ảnh thành PDF nhiều trang để upload OCR.
///
/// Mỗi trang PDF khớp kích thước pixel ảnh (không letterbox) để bbox OCR
/// khớp với ảnh hiển thị. Decode qua Flutter để áp dụng EXIF orientation.
class OcrImagesPdfBuilder {
  OcrImagesPdfBuilder._();

  static Future<String> buildPdf(List<File> images) async {
    if (images.isEmpty) {
      throw ArgumentError('Cần ít nhất một ảnh để tạo PDF.');
    }

    final document = PdfDocument();
    try {
      for (final file in images) {
        final bytes = await _normalizedImageBytes(file);
        final bitmap = PdfBitmap(bytes);
        final w = bitmap.width.toDouble();
        final h = bitmap.height.toDouble();

        final section = document.sections!.add();
        section.pageSettings.size = Size(w, h);
        section.pageSettings.margins.all = 0;
        final page = section.pages.add();
        page.graphics.drawImage(bitmap, Rect.fromLTWH(0, 0, w, h));
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/ocr_scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final out = File(path);
      await out.writeAsBytes(await document.save());
      return path;
    } finally {
      document.dispose();
    }
  }

  static Future<Uint8List> _normalizedImageBytes(File file) async {
    final raw = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(raw);
    final frame = await codec.getNextFrame();
    try {
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Không decode được ảnh: ${file.path}');
      }
      return byteData.buffer.asUint8List();
    } finally {
      frame.image.dispose();
    }
  }
}
