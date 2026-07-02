import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

/// Render preview trang tài liệu gốc (PDF hoặc ảnh) phục vụ overlay bbox.
class OcrPageRenderService {
  OcrPageRenderService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final Map<String, String> _localFileCache = {};

  bool isPdf(String? mimeType, String? fileUrl) {
    if (mimeType?.contains('pdf') == true) return true;
    return fileUrl?.toLowerCase().contains('.pdf') == true;
  }

  /// Tải file gốc về cache cục bộ (nếu chưa có).
  Future<String?> ensureLocalFile(String? fileUrl) async {
    if (fileUrl == null || fileUrl.isEmpty) return null;
    if (_localFileCache.containsKey(fileUrl)) {
      final path = _localFileCache[fileUrl]!;
      if (await File(path).exists()) return path;
    }
    try {
      final dir = await getTemporaryDirectory();
      final name = Uri.parse(fileUrl).pathSegments.last;
      final safeName = name.isEmpty ? 'ocr_source.bin' : name;
      final path = '${dir.path}/ocr_src_$safeName';
      await _dio.download(fileUrl, path);
      _localFileCache[fileUrl] = path;
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Render trang PDF thành ảnh JPEG bytes. Với file ảnh trả null (dùng URL trực tiếp).
  ///
  /// Khi truyền đủ [targetWidth] và [targetHeight] (kích thước pixel mà worker
  /// OCR đã dùng để tính bbox), ảnh được render đúng chính xác kích thước đó
  /// (scale không đồng nhất theo x/y nếu cần) để bbox khớp tuyệt đối với ảnh
  /// hiển thị — tránh lệch do sai số làm tròn tỉ lệ khung hình giữa hai lần
  /// render (worker dùng PyMuPDF, app dùng pdfx/pdfium).
  Future<Uint8List?> renderPdfPage({
    required String localPath,
    required int pageNumber,
    int? targetWidth,
    int? targetHeight,
  }) async {
    try {
      final document = await PdfDocument.openFile(localPath);
      try {
        if (pageNumber < 1 || pageNumber > document.pagesCount) return null;
        final page = await document.getPage(pageNumber);
        try {
          final pw = page.width;
          final ph = page.height;
          if (pw <= 0 || ph <= 0) return null;

          double width;
          double height;
          if (targetWidth != null && targetHeight != null) {
            width = targetWidth.clamp(1, 4000).toDouble();
            height = targetHeight.clamp(1, 6000).toDouble();
          } else {
            width = (targetWidth ?? pw.round()).clamp(320, 2400).toDouble();
            final scale = width / pw;
            height = (ph * scale).clamp(1, 3200).toDouble();
          }

          final image = await page.render(
            width: width,
            height: height,
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
          );
          return image?.bytes;
        } finally {
          page.close();
        }
      } finally {
        await document.close();
      }
    } catch (_) {
      return null;
    }
  }
}
