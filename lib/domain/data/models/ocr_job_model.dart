import 'dart:convert';

/// Trạng thái vòng đời một job OCR (khớp `OcrJobStatus` phía backend).
enum OcrJobStatus {
  queued,
  processing,
  done,
  failed;

  static OcrJobStatus fromString(String? value) {
    switch (value) {
      case 'processing':
        return OcrJobStatus.processing;
      case 'done':
        return OcrJobStatus.done;
      case 'failed':
        return OcrJobStatus.failed;
      case 'queued':
      default:
        return OcrJobStatus.queued;
    }
  }

  String get value => name;
}

/// Model một job OCR trả về từ `GET /ocr/jobs` và `GET /ocr/jobs/:id`.
///
/// Lưu ý: backend mã hóa field `id` bằng Base64 (ví dụ số 1 → "MQ==").
/// Vì socket `ocr.job.updated` gửi `jobId` là số nguyên gốc nên [rawId]
/// decode lại từ [id] để đối chiếu/join room.
class OcrJobModel {
  final String id;
  final String? fileUrl;
  final String? fileKey;
  final String? originalName;
  final String? mimeType;
  final int fileSize;
  final String lang;
  final String mode;
  final bool extractImages;
  final OcrJobStatus status;
  final int? totalPages;
  final int processedPages;
  final String? error;
  final String? txtUrl;
  final String? pdfUrl;
  final String? exportStatus;
  final String? exportError;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OcrJobModel({
    required this.id,
    this.fileUrl,
    this.fileKey,
    this.originalName,
    this.mimeType,
    this.fileSize = 0,
    this.lang = 'auto',
    this.mode = 'layout',
    this.extractImages = true,
    this.status = OcrJobStatus.queued,
    this.totalPages,
    this.processedPages = 0,
    this.error,
    this.txtUrl,
    this.pdfUrl,
    this.exportStatus,
    this.exportError,
    this.createdAt,
    this.updatedAt,
  });

  /// ID số nguyên gốc, decode từ Base64 để join socket room / đối chiếu event.
  int get rawId => _decodeBase64Id(id);

  /// Tiến độ 0.0 → 1.0. Trả 0 khi chưa biết tổng số trang.
  double get progress {
    if (status == OcrJobStatus.done) return 1.0;
    final total = totalPages ?? 0;
    if (total <= 0) return 0.0;
    return (processedPages / total).clamp(0.0, 1.0);
  }

  bool get isFinished =>
      status == OcrJobStatus.done || status == OcrJobStatus.failed;

  bool get isOcrPending =>
      status == OcrJobStatus.queued || status == OcrJobStatus.processing;

  bool get isExportPending => exportStatus == 'processing';

  bool get isExportFailed => exportStatus == 'failed';

  bool get isExportReady =>
      exportStatus == 'done' &&
      ((pdfUrl != null && pdfUrl!.isNotEmpty) ||
          (txtUrl != null && txtUrl!.isNotEmpty));

  bool get isActivityPending => isOcrPending || isExportPending;

  String get displayName =>
      (originalName != null && originalName!.isNotEmpty)
          ? originalName!
          : (fileKey ?? id);

  factory OcrJobModel.fromJson(Map<String, dynamic> json) {
    return OcrJobModel(
      id: json['id']?.toString() ?? '',
      fileUrl: json['fileUrl'] as String?,
      fileKey: json['fileKey'] as String?,
      originalName: json['originalName'] as String?,
      mimeType: json['mimeType'] as String?,
      fileSize: _toInt(json['fileSize']),
      lang: json['lang']?.toString() ?? 'auto',
      mode: json['mode']?.toString() ?? 'layout',
      extractImages: json['extractImages'] == true,
      status: OcrJobStatus.fromString(json['status']?.toString()),
      totalPages: json['totalPages'] == null ? null : _toInt(json['totalPages']),
      processedPages: _toInt(json['processedPages']),
      error: json['error'] as String?,
      txtUrl: json['txtUrl'] as String?,
      pdfUrl: json['pdfUrl'] as String?,
      exportStatus: json['exportStatus'] as String?,
      exportError: json['exportError'] as String?,
      createdAt: _toDate(json['createdAt']),
      updatedAt: _toDate(json['updatedAt']),
    );
  }

  /// Áp dụng payload realtime `ocr.job.updated` lên job hiện tại.
  OcrJobModel applyUpdate({
    required String status,
    int? processedPages,
    int? totalPages,
    String? error,
    String? exportStatus,
    String? pdfUrl,
    String? exportError,
  }) {
    return copyWith(
      status: OcrJobStatus.fromString(status),
      processedPages: processedPages ?? this.processedPages,
      totalPages: totalPages ?? this.totalPages,
      error: error,
      exportStatus: exportStatus ?? this.exportStatus,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      exportError: exportError ?? this.exportError,
    );
  }

  OcrJobModel copyWith({
    String? id,
    OcrJobStatus? status,
    int? totalPages,
    int? processedPages,
    String? error,
    String? txtUrl,
    String? pdfUrl,
    String? exportStatus,
    String? exportError,
  }) {
    return OcrJobModel(
      id: id ?? this.id,
      fileUrl: fileUrl,
      fileKey: fileKey,
      originalName: originalName,
      mimeType: mimeType,
      fileSize: fileSize,
      lang: lang,
      mode: mode,
      extractImages: extractImages,
      status: status ?? this.status,
      totalPages: totalPages ?? this.totalPages,
      processedPages: processedPages ?? this.processedPages,
      error: error ?? this.error,
      txtUrl: txtUrl ?? this.txtUrl,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      exportStatus: exportStatus ?? this.exportStatus,
      exportError: exportError ?? this.exportError,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static int _decodeBase64Id(String value) {
    final direct = int.tryParse(value);
    if (direct != null) return direct;
    try {
      final decoded = utf8.decode(base64.decode(value));
      return int.tryParse(decoded) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
