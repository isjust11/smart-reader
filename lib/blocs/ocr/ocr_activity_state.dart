import 'package:equatable/equatable.dart';
import 'package:readbox/domain/data/models/models.dart';

/// Dữ liệu màn hình theo dõi job OCR / export đang chờ kết quả.
class OcrActivityData extends Equatable {
  final List<OcrJobModel> ocrPending;
  final List<OcrJobModel> exportPending;
  final List<OcrJobModel> exportReady;
  final List<OcrJobModel> exportFailed;

  const OcrActivityData({
    this.ocrPending = const [],
    this.exportPending = const [],
    this.exportReady = const [],
    this.exportFailed = const [],
  });

  int get pendingCount => ocrPending.length + exportPending.length;

  bool get isEmpty =>
      ocrPending.isEmpty &&
      exportPending.isEmpty &&
      exportReady.isEmpty &&
      exportFailed.isEmpty;

  OcrActivityData copyWith({
    List<OcrJobModel>? ocrPending,
    List<OcrJobModel>? exportPending,
    List<OcrJobModel>? exportReady,
    List<OcrJobModel>? exportFailed,
  }) {
    return OcrActivityData(
      ocrPending: ocrPending ?? this.ocrPending,
      exportPending: exportPending ?? this.exportPending,
      exportReady: exportReady ?? this.exportReady,
      exportFailed: exportFailed ?? this.exportFailed,
    );
  }

  @override
  List<Object?> get props => [
        ocrPending,
        exportPending,
        exportReady,
        exportFailed,
      ];
}
