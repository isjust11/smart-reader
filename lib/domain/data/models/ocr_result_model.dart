import 'dart:ui';

/// Một dòng text OCR kèm bounding box (polygon 4 điểm) và độ tin cậy.
class OcrLineModel {
  final String text;
  final double confidence;
  final List<Offset> bbox;

  const OcrLineModel({
    required this.text,
    this.confidence = 0,
    this.bbox = const [],
  });

  factory OcrLineModel.fromJson(Map<String, dynamic> json) {
    return OcrLineModel(
      text: json['text']?.toString() ?? '',
      confidence: _toDouble(json['confidence']),
      bbox: _parseBbox(json['bbox']),
    );
  }
}

/// Ảnh / figure / table đã tách khỏi trang tài liệu.
class OcrAssetModel {
  /// 'image' | 'figure' | 'table'.
  final String type;
  final List<Offset> bbox;
  final String? imageUrl;
  final String? imageKey;
  final String? tableHtml;

  /// 'embedded' | 'layout'.
  final String? source;

  const OcrAssetModel({
    required this.type,
    this.bbox = const [],
    this.imageUrl,
    this.imageKey,
    this.tableHtml,
    this.source,
  });

  factory OcrAssetModel.fromJson(Map<String, dynamic> json) {
    return OcrAssetModel(
      type: json['type']?.toString() ?? 'image',
      bbox: _parseBbox(json['bbox']),
      imageUrl: json['imageUrl'] as String?,
      imageKey: json['imageKey'] as String?,
      tableHtml: json['tableHtml'] as String?,
      source: json['source'] as String?,
    );
  }
}

/// Kết quả OCR của một trang (khớp entity `ocr_result` + assets phía backend).
class OcrPageModel {
  final int page;
  final int width;
  final int height;
  final String? text;
  final List<OcrLineModel> lines;
  final List<OcrAssetModel> images;
  final List<OcrAssetModel> tables;

  const OcrPageModel({
    required this.page,
    this.width = 0,
    this.height = 0,
    this.text,
    this.lines = const [],
    this.images = const [],
    this.tables = const [],
  });

  factory OcrPageModel.fromJson(Map<String, dynamic> json) {
    final blocks = json['blocks'] ?? json['lines'];
    return OcrPageModel(
      page: _toInt(json['pageNumber'] ?? json['page']),
      width: _toInt(json['width']),
      height: _toInt(json['height']),
      text: json['text'] as String?,
      lines: _parseList(blocks, OcrLineModel.fromJson),
      images: _parseList(json['images'], OcrAssetModel.fromJson),
      tables: _parseList(json['tables'], OcrAssetModel.fromJson),
    );
  }
}

List<T> _parseList<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

List<Offset> _parseBbox(dynamic raw) {
  if (raw is! List) return const [];
  final points = <Offset>[];
  for (final point in raw) {
    if (point is List && point.length >= 2) {
      points.add(Offset(_toDouble(point[0]), _toDouble(point[1])));
    }
  }
  return points;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
