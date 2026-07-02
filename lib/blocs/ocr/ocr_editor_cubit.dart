import 'package:flutter/material.dart' show Offset, Rect;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readbox/blocs/base_bloc/base_state.dart';
import 'package:readbox/blocs/ocr/ocr_editor_state.dart';
import 'package:readbox/blocs/utils.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/domain/repositories/ocr_repository.dart';

/// Cubit quản lý chỉnh sửa kết quả OCR: load trang, chọn bbox, sửa text/ảnh.
class OcrEditorCubit extends Cubit<BaseState> {
  final OcrRepository _repository;
  final String jobId;

  OcrEditorCubit(this._repository, this.jobId) : super(InitState());

  OcrEditorLoaded? get _loaded =>
      state is LoadedState<OcrEditorLoaded>
          ? (state as LoadedState<OcrEditorLoaded>).data
          : null;

  Future<void> load() async {
    emit(LoadingState());
    try {
      final job = await _repository.getJob(jobId);
      if (job.status != OcrJobStatus.done) {
        emit(
          ErrorState(
            'Job chưa hoàn tất, chưa thể chỉnh sửa.',
            isLocalizeMessage: false,
          ),
        );
        return;
      }
      final pages = await _repository.getResult(jobId);
      if (pages.isEmpty) {
        emit(
          ErrorState(
            'Chưa có kết quả OCR cho job này.',
            isLocalizeMessage: false,
          ),
        );
        return;
      }
      pages.sort((a, b) => a.page.compareTo(b.page));
      emit(
        LoadedState(
          OcrEditorLoaded(job: job, pages: pages),
          message: '',
          isLocalizeMessage: false,
        ),
      );
    } catch (e) {
      emit(ErrorState(BlocUtils.getMessageError(e), isLocalizeMessage: false));
    }
  }

  void goToPage(int index) {
    final data = _loaded;
    if (data == null || index < 0 || index >= data.pages.length) return;
    _emit(data.copyWith(currentPageIndex: index, clearSelection: true));
  }

  void selectLine(int index) {
    final data = _loaded;
    if (data == null) return;
    final page = data.currentPage;
    if (index < 0 || index >= page.lines.length) return;
    _emit(
      data.copyWith(
        selection: OcrEditorSelection(
          kind: OcrEditorSelectionKind.line,
          index: index,
        ),
      ),
    );
  }

  void selectImage(int index) {
    final data = _loaded;
    if (data == null) return;
    final page = data.currentPage;
    if (index < 0 || index >= page.images.length) return;
    _emit(
      data.copyWith(
        selection: OcrEditorSelection(
          kind: OcrEditorSelectionKind.image,
          index: index,
        ),
      ),
    );
  }

  void selectTable(int index) {
    final data = _loaded;
    if (data == null) return;
    final page = data.currentPage;
    if (index < 0 || index >= page.tables.length) return;
    _emit(
      data.copyWith(
        selection: OcrEditorSelection(
          kind: OcrEditorSelectionKind.table,
          index: index,
        ),
      ),
    );
  }

  void updateLineText(int index, String text) {
    final data = _loaded;
    if (data == null) return;
    final page = data.currentPage;
    if (index < 0 || index >= page.lines.length) return;
    final lines = List<OcrLineModel>.from(page.lines);
    lines[index] = lines[index].copyWith(text: text);
    _updatePage(
      data,
      page.copyWith(lines: lines, text: lines.map((e) => e.text).join('\n')),
      isDirty: true,
    );
  }

  void updateTableHtml(int index, String html) {
    final data = _loaded;
    if (data == null) return;
    final page = data.currentPage;
    if (index < 0 || index >= page.tables.length) return;
    final tables = List<OcrAssetModel>.from(page.tables);
    tables[index] = tables[index].copyWith(tableHtml: html);
    _updatePage(data, page.copyWith(tables: tables), isDirty: true);
  }

  void replaceImageAsset(int index, String localPath) {
    final data = _loaded;
    if (data == null) return;
    final page = data.currentPage;
    if (index < 0 || index >= page.images.length) return;
    final images = List<OcrAssetModel>.from(page.images);
    images[index] = images[index].copyWith(localImagePath: localPath);
    _updatePage(data, page.copyWith(images: images), isDirty: true);
  }

  /// Thêm một dòng text thủ công — dùng khi OCR bỏ sót/không nhận dạng được
  /// một vùng nào đó trên trang. [rect] là vùng theo hệ toạ độ pixel gốc của
  /// OCR (page.width x page.height); nếu bỏ trống thì đặt một khung mặc định
  /// ở giữa trang. Dòng mới có text rỗng và được chọn sẵn để nhập ngay.
  void addLine([Rect? rect]) {
    final data = _loaded;
    if (data == null) return;
    final page = data.currentPage;

    final targetRect = rect ?? _defaultNewLineRect(page);
    final bbox = [
      Offset(targetRect.left, targetRect.top),
      Offset(targetRect.right, targetRect.top),
      Offset(targetRect.right, targetRect.bottom),
      Offset(targetRect.left, targetRect.bottom),
    ];

    final lines = List<OcrLineModel>.from(page.lines)
      ..add(OcrLineModel(text: '', confidence: 1, bbox: bbox));
    final newIndex = lines.length - 1;
    _updatePage(
      data,
      page.copyWith(lines: lines, text: lines.map((e) => e.text).join('\n')),
      isDirty: true,
    );
    selectLine(newIndex);
  }

  Rect _defaultNewLineRect(OcrPageModel page) {
    final w = page.width > 0 ? page.width.toDouble() : 1000.0;
    final h = page.height > 0 ? page.height.toDouble() : 1400.0;
    final boxW = w * 0.6;
    final boxH = h * 0.035;
    final left = (w - boxW) / 2;
    final top = (h - boxH) / 2;
    return Rect.fromLTWH(left, top, boxW, boxH);
  }

  void deleteSelectedLine() {
    final data = _loaded;
    if (data == null || data.selection?.kind != OcrEditorSelectionKind.line) {
      return;
    }
    final index = data.selection!.index;
    final page = data.currentPage;
    if (index < 0 || index >= page.lines.length) return;
    final lines = List<OcrLineModel>.from(page.lines)..removeAt(index);
    _updatePage(
      data,
      page.copyWith(lines: lines, text: lines.map((e) => e.text).join('\n')),
      isDirty: true,
      clearSelection: true,
    );
  }

  /// Đẩy job vào hàng đợi xử lý lại — dùng khi cần worker tạo lại kết quả
  /// (ví dụ: job cũ chưa có ảnh trang `pageImageUrl` để hiển thị bbox chính
  /// xác, hoặc muốn OCR lại sau khi cấu hình worker thay đổi).
  Future<void> requeue() async {
    await _repository.requeueJob(jobId);
  }

  Future<Map<String, dynamic>?> exportDocument(String format) async {
    final data = _loaded;
    if (data == null) return null;
    _emit(data.copyWith(isExporting: true));
    try {
      final result = await _repository.exportJob(jobId, format);
      _emit(data.copyWith(isExporting: false));
      return result;
    } catch (e) {
      _emit(data.copyWith(isExporting: false));
      rethrow;
    }
  }

  void _updatePage(
    OcrEditorLoaded data,
    OcrPageModel page, {
    bool isDirty = false,
    bool clearSelection = false,
  }) {
    final pages = List<OcrPageModel>.from(data.pages);
    pages[data.currentPageIndex] = page;
    _emit(
      data.copyWith(
        pages: pages,
        isDirty: isDirty || data.isDirty,
        clearSelection: clearSelection,
      ),
    );
  }

  void _emit(OcrEditorLoaded data) {
    emit(
      LoadedState(
        data,
        message: '',
        isLocalizeMessage: false,
      ),
    );
  }
}
