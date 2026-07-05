import 'dart:ui';

enum OcrTextPreset { body, h1, h2, h3, caption }

/// Style cơ bản cho text run / line.
class OcrTextStyleModel {
  final String? fontFamily;
  final double? fontSize;
  final String? colorHex;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? align;
  final double? lineHeight;
  final OcrTextPreset preset;

  const OcrTextStyleModel({
    this.fontFamily,
    this.fontSize,
    this.colorHex,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.align,
    this.lineHeight,
    this.preset = OcrTextPreset.body,
  });

  factory OcrTextStyleModel.fromJson(Map<String, dynamic> json) {
    return OcrTextStyleModel(
      fontFamily: json['fontFamily']?.toString(),
      fontSize: _toNullableDouble(json['fontSize']),
      colorHex: json['colorHex']?.toString(),
      bold: _toBool(json['bold']),
      italic: _toBool(json['italic']),
      underline: _toBool(json['underline']),
      align: json['align']?.toString(),
      lineHeight: _toNullableDouble(json['lineHeight']),
      preset: _parsePreset(json['preset']),
    );
  }

  OcrTextStyleModel copyWith({
    String? fontFamily,
    double? fontSize,
    String? colorHex,
    bool? bold,
    bool? italic,
    bool? underline,
    String? align,
    double? lineHeight,
    OcrTextPreset? preset,
  }) {
    return OcrTextStyleModel(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      colorHex: colorHex ?? this.colorHex,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      align: align ?? this.align,
      lineHeight: lineHeight ?? this.lineHeight,
      preset: preset ?? this.preset,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (fontSize != null) 'fontSize': fontSize,
      if (colorHex != null) 'colorHex': colorHex,
      'bold': bold,
      'italic': italic,
      'underline': underline,
      if (align != null) 'align': align,
      if (lineHeight != null) 'lineHeight': lineHeight,
      'preset': preset.name,
    };
  }
}

/// Một đoạn text có style riêng (phục vụ rich text editor).
class OcrTextRunModel {
  final String text;
  final OcrTextStyleModel? style;

  const OcrTextRunModel({required this.text, this.style});

  factory OcrTextRunModel.fromJson(Map<String, dynamic> json) {
    final rawStyle = json['style'];
    return OcrTextRunModel(
      text: json['text']?.toString() ?? '',
      style: rawStyle is Map<String, dynamic>
          ? OcrTextStyleModel.fromJson(rawStyle)
          : null,
    );
  }

  OcrTextRunModel copyWith({String? text, OcrTextStyleModel? style}) {
    return OcrTextRunModel(text: text ?? this.text, style: style ?? this.style);
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      if (style != null) 'style': style!.toJson(),
    };
  }
}

/// Một dòng text OCR kèm bounding box (polygon 4 điểm) và độ tin cậy.
class OcrLineModel {
  final String text;
  final double confidence;
  final List<Offset> bbox;
  final OcrTextStyleModel? style;
  final List<OcrTextRunModel> runs;

  /// Chỉ dùng client-side: cần vẽ lại trên preview nền trắng.
  final bool renderDirty;

  const OcrLineModel({
    required this.text,
    this.confidence = 0,
    this.bbox = const [],
    this.style,
    this.runs = const [],
    this.renderDirty = false,
  });

  factory OcrLineModel.fromJson(Map<String, dynamic> json) {
    final rawStyle = json['style'];
    return OcrLineModel(
      text: json['text']?.toString() ?? '',
      confidence: _toDouble(json['confidence']),
      bbox: _parseBbox(json['bbox']),
      style: rawStyle is Map<String, dynamic>
          ? OcrTextStyleModel.fromJson(rawStyle)
          : null,
      runs: _parseList(json['runs'], OcrTextRunModel.fromJson),
    );
  }

  OcrLineModel copyWith({
    String? text,
    double? confidence,
    List<Offset>? bbox,
    OcrTextStyleModel? style,
    List<OcrTextRunModel>? runs,
    bool? renderDirty,
    bool clearRenderDirty = false,
  }) {
    return OcrLineModel(
      text: text ?? this.text,
      confidence: confidence ?? this.confidence,
      bbox: bbox ?? this.bbox,
      style: style ?? this.style,
      runs: runs ?? this.runs,
      renderDirty: clearRenderDirty ? false : (renderDirty ?? this.renderDirty),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'confidence': confidence,
      'bbox': bbox.map((p) => [p.dx, p.dy]).toList(),
      if (style != null) 'style': style!.toJson(),
      if (runs.isNotEmpty) 'runs': runs.map((e) => e.toJson()).toList(),
    };
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

  /// Chỉ dùng client-side: cần vẽ lại trên preview nền trắng.
  final bool renderDirty;

  const OcrAssetModel({
    required this.type,
    this.bbox = const [],
    this.imageUrl,
    this.imageKey,
    this.tableHtml,
    this.source,
    this.localImagePath,
    this.renderDirty = false,
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
    bool? renderDirty,
    bool clearRenderDirty = false,
  }) {
    return OcrAssetModel(
      type: type ?? this.type,
      bbox: bbox ?? this.bbox,
      imageUrl: imageUrl ?? this.imageUrl,
      imageKey: imageKey ?? this.imageKey,
      tableHtml: tableHtml ?? this.tableHtml,
      source: source ?? this.source,
      localImagePath: localImagePath ?? this.localImagePath,
      renderDirty: clearRenderDirty ? false : (renderDirty ?? this.renderDirty),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'bbox': bbox.map((p) => [p.dx, p.dy]).toList(),
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imageKey != null) 'imageKey': imageKey,
      if (tableHtml != null) 'tableHtml': tableHtml,
      if (source != null) 'source': source,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'width': width,
      'height': height,
      'lines': lines.map((e) => e.toJson()).toList(),
      'images': images.map((e) => e.toJson()).toList(),
      'tables': tables.map((e) => e.toJson()).toList(),
      if (pageImageUrl != null) 'pageImageUrl': pageImageUrl,
    };
  }

  String get mergedText =>
      text?.trim().isNotEmpty == true
          ? text!
          : lines.map((e) => e.text).join('\n');

  /// Có thành phần cần vẽ lại trên preview nền trắng.
  bool get hasRenderDirty =>
      lines.any((e) => e.renderDirty) ||
      images.any((e) => e.renderDirty) ||
      tables.any((e) => e.renderDirty);

  OcrPageModel withRenderDirtyCleared() {
    return copyWith(
      lines: lines.map((l) => l.copyWith(clearRenderDirty: true)).toList(),
      images: images.map((a) => a.copyWith(clearRenderDirty: true)).toList(),
      tables: tables.map((t) => t.copyWith(clearRenderDirty: true)).toList(),
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

double? _toNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool _toBool(dynamic value) {
  if (value is bool) return value;
  final raw = value?.toString().toLowerCase().trim();
  return raw == '1' || raw == 'true' || raw == 'yes' || raw == 'on';
}

OcrTextPreset _parsePreset(dynamic value) {
  final raw = value?.toString().toLowerCase().trim();
  switch (raw) {
    case 'h1':
      return OcrTextPreset.h1;
    case 'h2':
      return OcrTextPreset.h2;
    case 'h3':
      return OcrTextPreset.h3;
    case 'caption':
      return OcrTextPreset.caption;
    default:
      return OcrTextPreset.body;
  }
}
