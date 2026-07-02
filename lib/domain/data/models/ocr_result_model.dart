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

  OcrLineModel copyWith({
    String? text,
    double? confidence,
    List<Offset>? bbox,
  }) {
    return OcrLineModel(
      text: text ?? this.text,
      confidence: confidence ?? this.confidence,
      bbox: bbox ?? this.bbox,
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

  /// Ảnh thay thế cục bộ (chưa upload server) — chỉ dùng trong editor.
  final String? localImagePath;

  const OcrAssetModel({
    required this.type,
    this.bbox = const [],
    this.imageUrl,
    this.imageKey,
    this.tableHtml,
    this.source,
    this.localImagePath,
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

  OcrAssetModel copyWith({
    String? type,
    List<Offset>? bbox,
    String? imageUrl,
    String? imageKey,
    String? tableHtml,
    String? source,
    String? localImagePath,
  }) {
    return OcrAssetModel(
      type: type ?? this.type,
      bbox: bbox ?? this.bbox,
      imageUrl: imageUrl ?? this.imageUrl,
      imageKey: imageKey ?? this.imageKey,
      tableHtml: tableHtml ?? this.tableHtml,
      source: source ?? this.source,
      localImagePath: localImagePath ?? this.localImagePath,
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

  /// Ảnh raster đầy đủ của trang, đúng pixel space (width x height) mà
  /// worker đã dùng để tính bbox. Ưu tiên hiển thị ảnh này thay vì tự render
  /// lại PDF trên client để bbox luôn khớp chính xác vị trí.
  final String? pageImageUrl;

  const OcrPageModel({
    required this.page,
    this.width = 0,
    this.height = 0,
    this.text,
    this.lines = const [],
    this.images = const [],
    this.tables = const [],
    this.pageImageUrl,
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
      pageImageUrl: json['pageImageUrl'] as String?,
    );
  }

  OcrPageModel copyWith({
    int? page,
    int? width,
    int? height,
    String? text,
    List<OcrLineModel>? lines,
    List<OcrAssetModel>? images,
    List<OcrAssetModel>? tables,
    String? pageImageUrl,
  }) {
    return OcrPageModel(
      page: page ?? this.page,
      width: width ?? this.width,
      height: height ?? this.height,
      text: text ?? this.text,
      lines: lines ?? this.lines,
      images: images ?? this.images,
      tables: tables ?? this.tables,
      pageImageUrl: pageImageUrl ?? this.pageImageUrl,
    );
  }

  String get mergedText =>
      text?.trim().isNotEmpty == true
          ? text!
          : lines.map((e) => e.text).join('\n');
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
    } else if (point is Map) {
      points.add(
        Offset(
          _toDouble(point['x'] ?? point['0']),
          _toDouble(point['y'] ?? point['1']),
        ),
      );
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
