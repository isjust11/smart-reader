import 'package:equatable/equatable.dart';
import 'package:readbox/domain/data/models/models.dart';

/// Loại vùng đang chọn trên trang OCR.
enum OcrEditorSelectionKind { line, image, table }

/// Vùng bbox đang được chọn để chỉnh sửa.
class OcrEditorSelection extends Equatable {
  final OcrEditorSelectionKind kind;
  final int index;

  const OcrEditorSelection({required this.kind, required this.index});

  @override
  List<Object?> get props => [kind, index];
}

/// State đã load dữ liệu cho màn chỉnh sửa OCR.
class OcrEditorLoaded extends Equatable {
  final OcrJobModel job;
  final List<OcrPageModel> pages;
  final int currentPageIndex;
  final OcrEditorSelection? selection;
  final bool isDirty;
  final bool isExporting;
  final bool isSaving;

  const OcrEditorLoaded({
    required this.job,
    required this.pages,
    this.currentPageIndex = 0,
    this.selection,
    this.isDirty = false,
    this.isExporting = false,
    this.isSaving = false,
  });

  OcrPageModel get currentPage => pages[currentPageIndex];

  OcrEditorLoaded copyWith({
    OcrJobModel? job,
    List<OcrPageModel>? pages,
    int? currentPageIndex,
    OcrEditorSelection? selection,
    bool clearSelection = false,
    bool? isDirty,
    bool? isExporting,
    bool? isSaving,
  }) {
    return OcrEditorLoaded(
      job: job ?? this.job,
      pages: pages ?? this.pages,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      selection: clearSelection ? null : (selection ?? this.selection),
      isDirty: isDirty ?? this.isDirty,
      isExporting: isExporting ?? this.isExporting,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  List<Object?> get props => [
        job.id,
        pages,
        currentPageIndex,
        selection,
        isDirty,
        isExporting,
        isSaving,
      ];
}
