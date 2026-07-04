import 'package:flutter/material.dart' show Offset, Rect;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readbox/blocs/base_bloc/base_state.dart';
import 'package:readbox/blocs/ocr/ocr_editor_state.dart';
import 'package:readbox/blocs/utils.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/domain/repositories/ocr_repository.dart';
import 'package:readbox/utils/ocr_add_line_geometry.dart';

/// Cubit quản lý chỉnh sửa kết quả OCR: load trang, chọn bbox, sửa text/ảnh.
class OcrEditorCubit extends Cubit<BaseState> {
  final OcrRepository _repository;
  final String jobId;
  final List<OcrEditorLoaded> _undoStack = [];
  final List<OcrEditorLoaded> _redoStack = [];

  OcrEditorCubit(this._repository, this.jobId) : super(InitState());

  OcrEditorLoaded? get _loaded =>
      state is LoadedState<OcrEditorLoaded>
          ? (state as LoadedState<OcrEditorLoaded>).data
          : null;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

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
      final initializedPages = pages.map(_initPageStyles).toList();
      _undoStack.clear();
      _redoStack.clear();
      emit(
        LoadedState(
          OcrEditorLoaded(job: job, pages: initializedPages),
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

  void updateLineStyle(int index, OcrTextStyleModel style) {
    final data = _loaded;
    if (data == null) return;
    final page = data.currentPage;
    if (index < 0 || index >= page.lines.length) return;
    final lines = List<OcrLineModel>.from(page.lines);
    lines[index] = lines[index].copyWith(style: style);
    _updatePage(
      data,
      page.copyWith(lines: lines, text: lines.map((e) => e.text).join('\n')),
      isDirty: true,
    );
  }

  /// Cập nhật bbox của dòng đang chọn (kéo / chỉnh rộng trên preview).
  void updateLineBbox(int index, Rect rect) {
    final data = _loaded;
    if (data == null) return;
    final page = data.currentPage;
    if (index < 0 || index >= page.lines.length) return;

    final lines = List<OcrLineModel>.from(page.lines);
    lines[index] = lines[index].copyWith(
      bbox: OcrAddLineGeometry.rectToBbox(rect),
    );
    _updatePage(
      data,
      page.copyWith(lines: lines, text: lines.map((e) => e.text).join('\n')),
      isDirty: true,
    );
  }

  void applyLinePreset(int index, OcrTextPreset preset) {
    final data = _loaded;
    if (data == null) return;
    final page = data.currentPage;
    if (index < 0 || index >= page.lines.length) return;
    final lines = List<OcrLineModel>.from(page.lines);
    final base = lines[index].style ?? const OcrTextStyleModel();
    lines[index] = lines[index].copyWith(
      style: _styleForPreset(base.copyWith(preset: preset)),
    );
    _updatePage(
      data,
      page.copyWith(lines: lines, text: lines.map((e) => e.text).join('\n')),
      isDirty: true,
    );
  }

  /// Áp một preset cho toàn bộ các dòng trang hiện tại.
  void applyPresetToCurrentPage(OcrTextPreset preset) {
    final data = _loaded;
    if (data == null) return;
    final page = data.currentPage;
    final lines = page.lines
        .map((line) => line.copyWith(style: _styleForPreset((line.style ?? const OcrTextStyleModel()).copyWith(preset: preset))))
        .toList();
    _updatePage(
      data,
      page.copyWith(lines: lines, text: lines.map((e) => e.text).join('\n')),
      isDirty: true,
    );
  }

  /// Chuẩn hóa preset theo rule heading/body/caption cho trang hiện tại.
  void normalizeCurrentPageStyles() {
    final data = _loaded;
    if (data == null) return;
    final page = data.currentPage;
    final lines = page.lines.map(_withAutoPresetIfMissing).toList();
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

    final lines = List<OcrLineModel>.from(page.lines);
    final newLine = OcrLineModel(
      text: '',
      confidence: 1,
      bbox: bbox,
      style: const OcrTextStyleModel(preset: OcrTextPreset.body),
    );
    final newIndex = _insertLineByReadingOrder(lines, newLine);
    _updatePage(
      data,
      page.copyWith(lines: lines, text: lines.map((e) => e.text).join('\n')),
      isDirty: true,
    );
    selectLine(newIndex);
  }

  /// Chọn dòng trống kế tiếp (text rỗng) để nhập nhanh các vùng OCR bị thiếu.
  void selectNextMissingLine() {
    final data = _loaded;
    if (data == null) return;
    final lines = data.currentPage.lines;
    if (lines.isEmpty) return;

    final start = (data.selection?.kind == OcrEditorSelectionKind.line)
        ? data.selection!.index + 1
        : 0;
    final next = _findMissingLineIndex(lines, start, forward: true);
    if (next != -1) selectLine(next);
  }

  /// Chọn dòng trống trước đó (text rỗng).
  void selectPrevMissingLine() {
    final data = _loaded;
    if (data == null) return;
    final lines = data.currentPage.lines;
    if (lines.isEmpty) return;

    final start = (data.selection?.kind == OcrEditorSelectionKind.line)
        ? data.selection!.index - 1
        : lines.length - 1;
    final prev = _findMissingLineIndex(lines, start, forward: false);
    if (prev != -1) selectLine(prev);
  }

  Rect _defaultNewLineRect(OcrPageModel page) {
    final w = OcrAddLineGeometry.pageWidth(page);
    final h = OcrAddLineGeometry.pageHeight(page);
    final lineH = OcrAddLineGeometry.typicalLineHeight(page);
    final boxW = OcrAddLineGeometry.typicalLineWidth(page);
    final left = (w - boxW) / 2;
    final top = (h - lineH) / 2;
    return Rect.fromLTWH(left, top, boxW, lineH);
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

  void moveSelectedLineUp() => _moveSelectedBBox(-1);
  void moveSelectedLineDown() => _moveSelectedBBox(1);

  bool canMoveSelectedLineUp() => _canMoveSelectedBBox(-1);
  bool canMoveSelectedLineDown() => _canMoveSelectedBBox(1);

  void _moveSelectedBBox(int delta) {
    final data = _loaded;
    final sel = data?.selection;
    if (data == null || sel == null) return;

    final page = data.currentPage;
    final step = OcrAddLineGeometry.typicalLineHeight(page);
    final offset = Offset(0, delta * step);

    switch (sel.kind) {
      case OcrEditorSelectionKind.line:
        if (sel.index < 0 || sel.index >= page.lines.length) return;
        final lines = List<OcrLineModel>.from(page.lines);
        final line = lines[sel.index];
        final rect = OcrAddLineGeometry.bboxRect(line.bbox);
        if (rect.isEmpty) return;
        final moved = OcrAddLineGeometry.move(rect, offset, page);
        if (moved == rect) return;
        lines[sel.index] = line.copyWith(
          bbox: OcrAddLineGeometry.rectToBbox(moved),
        );
        _updatePage(
          data,
          page.copyWith(
            lines: lines,
            text: lines.map((e) => e.text).join('\n'),
          ),
          isDirty: true,
        );
      case OcrEditorSelectionKind.image:
        if (sel.index < 0 || sel.index >= page.images.length) return;
        final images = List<OcrAssetModel>.from(page.images);
        final asset = images[sel.index];
        final rect = OcrAddLineGeometry.bboxRect(asset.bbox);
        if (rect.isEmpty) return;
        final moved = OcrAddLineGeometry.move(rect, offset, page);
        if (moved == rect) return;
        images[sel.index] = asset.copyWith(
          bbox: OcrAddLineGeometry.rectToBbox(moved),
        );
        _updatePage(data, page.copyWith(images: images), isDirty: true);
      case OcrEditorSelectionKind.table:
        if (sel.index < 0 || sel.index >= page.tables.length) return;
        final tables = List<OcrAssetModel>.from(page.tables);
        final asset = tables[sel.index];
        final rect = OcrAddLineGeometry.bboxRect(asset.bbox);
        if (rect.isEmpty) return;
        final moved = OcrAddLineGeometry.move(rect, offset, page);
        if (moved == rect) return;
        tables[sel.index] = asset.copyWith(
          bbox: OcrAddLineGeometry.rectToBbox(moved),
        );
        _updatePage(data, page.copyWith(tables: tables), isDirty: true);
    }
  }

  bool _canMoveSelectedBBox(int delta) {
    final data = _loaded;
    final sel = data?.selection;
    if (data == null || sel == null) return false;

    final page = data.currentPage;
    final rect = switch (sel.kind) {
      OcrEditorSelectionKind.line =>
        sel.index >= 0 && sel.index < page.lines.length
            ? OcrAddLineGeometry.bboxRect(page.lines[sel.index].bbox)
            : Rect.zero,
      OcrEditorSelectionKind.image =>
        sel.index >= 0 && sel.index < page.images.length
            ? OcrAddLineGeometry.bboxRect(page.images[sel.index].bbox)
            : Rect.zero,
      OcrEditorSelectionKind.table =>
        sel.index >= 0 && sel.index < page.tables.length
            ? OcrAddLineGeometry.bboxRect(page.tables[sel.index].bbox)
            : Rect.zero,
    };
    if (rect.isEmpty) return false;
    return OcrAddLineGeometry.canMoveVertically(rect, delta, page);
  }

  void deleteSelectedImage() {
    final data = _loaded;
    if (data == null || data.selection?.kind != OcrEditorSelectionKind.image) {
      return;
    }
    final page = data.currentPage;
    final index = data.selection!.index;
    if (index < 0 || index >= page.images.length) return;
    final images = List<OcrAssetModel>.from(page.images)..removeAt(index);
    _updatePage(
      data,
      page.copyWith(images: images),
      isDirty: true,
      clearSelection: true,
    );
  }

  void deleteSelectedTable() {
    final data = _loaded;
    if (data == null || data.selection?.kind != OcrEditorSelectionKind.table) {
      return;
    }
    final page = data.currentPage;
    final index = data.selection!.index;
    if (index < 0 || index >= page.tables.length) return;
    final tables = List<OcrAssetModel>.from(page.tables)..removeAt(index);
    _updatePage(
      data,
      page.copyWith(tables: tables),
      isDirty: true,
      clearSelection: true,
    );
  }

  void undo() {
    final current = _loaded;
    if (current == null || _undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    _redoStack.add(current);
    _emit(previous);
  }

  void redo() {
    final current = _loaded;
    if (current == null || _redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(current);
    _emit(next);
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

  Future<void> saveEdits() async {
    final data = _loaded;
    if (data == null || !data.isDirty) return;
    _emit(data.copyWith(isSaving: true));
    try {
      await _repository.saveResult(jobId, data.pages);
      _emit(data.copyWith(isSaving: false, isDirty: false));
      _undoStack.clear();
      _redoStack.clear();
    } catch (e) {
      _emit(data.copyWith(isSaving: false));
      rethrow;
    }
  }

  void _updatePage(
    OcrEditorLoaded data,
    OcrPageModel page, {
    bool isDirty = false,
    bool clearSelection = false,
  }) {
    _pushUndoSnapshot(data);
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

  void _pushUndoSnapshot(OcrEditorLoaded data) {
    _undoStack.add(data);
    if (_undoStack.length > 100) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
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

  int _insertLineByReadingOrder(List<OcrLineModel> lines, OcrLineModel newLine) {
    final anchor = _lineAnchor(newLine);
    var insertAt = lines.length;
    for (var i = 0; i < lines.length; i++) {
      final cur = _lineAnchor(lines[i]);
      if (anchor.dy < cur.dy || (anchor.dy == cur.dy && anchor.dx < cur.dx)) {
        insertAt = i;
        break;
      }
    }
    lines.insert(insertAt, newLine);
    return insertAt;
  }

  int _findMissingLineIndex(
    List<OcrLineModel> lines,
    int start, {
    required bool forward,
  }) {
    bool isMissing(OcrLineModel line) => line.text.trim().isEmpty;

    if (forward) {
      for (var i = start; i < lines.length; i++) {
        if (isMissing(lines[i])) return i;
      }
      for (var i = 0; i < start && i < lines.length; i++) {
        if (isMissing(lines[i])) return i;
      }
      return -1;
    }

    for (var i = start; i >= 0 && i < lines.length; i--) {
      if (isMissing(lines[i])) return i;
    }
    for (var i = lines.length - 1; i > start; i--) {
      if (isMissing(lines[i])) return i;
    }
    return -1;
  }

  Offset _lineAnchor(OcrLineModel line) {
    if (line.bbox.isEmpty) return Offset.zero;
    final sorted = [...line.bbox]..sort((a, b) {
      final byY = a.dy.compareTo(b.dy);
      if (byY != 0) return byY;
      return a.dx.compareTo(b.dx);
    });
    return sorted.first;
  }

  OcrTextStyleModel _styleForPreset(OcrTextStyleModel style) {
    switch (style.preset) {
      case OcrTextPreset.h1:
        return style.copyWith(
          fontFamily: 'Times New Roman',
          fontSize: 18,
          bold: true,
          italic: false,
          underline: false,
          align: 'left',
          lineHeight: 1.3,
        );
      case OcrTextPreset.h2:
        return style.copyWith(
          fontFamily: 'Times New Roman',
          fontSize: 16,
          bold: true,
          italic: false,
          underline: false,
          align: 'left',
          lineHeight: 1.3,
        );
      case OcrTextPreset.h3:
        return style.copyWith(
          fontFamily: 'Times New Roman',
          fontSize: 14,
          bold: true,
          italic: false,
          underline: false,
          align: 'left',
          lineHeight: 1.3,
        );
      case OcrTextPreset.caption:
        return style.copyWith(
          fontFamily: 'Times New Roman',
          fontSize: 11,
          bold: false,
          italic: true,
          underline: false,
          align: 'left',
          lineHeight: 1.25,
          colorHex: '#555555',
        );
      case OcrTextPreset.body:
        return style.copyWith(
          fontFamily: 'Times New Roman',
          fontSize: 12,
          bold: false,
          italic: false,
          underline: false,
          align: 'justify',
          lineHeight: 1.35,
          colorHex: '#111111',
        );
    }
  }

  OcrPageModel _initPageStyles(OcrPageModel page) {
    final lines = page.lines.map(_withAutoPresetIfMissing).toList();
    return page.copyWith(lines: lines, text: lines.map((e) => e.text).join('\n'));
  }

  OcrLineModel _withAutoPresetIfMissing(OcrLineModel line) {
    final current = line.style;
    if (current != null) {
      return line.copyWith(style: _styleForPreset(current));
    }
    final preset = _inferPresetFromText(line.text);
    return line.copyWith(
      style: _styleForPreset(const OcrTextStyleModel().copyWith(preset: preset)),
    );
  }

  OcrTextPreset _inferPresetFromText(String text) {
    final t = text.trim();
    if (t.isEmpty) return OcrTextPreset.body;
    if (t.length <= 60 && RegExp(r'^[A-Z0-9\s\-\.:,()]+$').hasMatch(t)) {
      return OcrTextPreset.h2;
    }
    if (t.length <= 90 && RegExp(r'^\d+(\.\d+)*[\)\.]?\s+').hasMatch(t)) {
      return OcrTextPreset.h3;
    }
    if (t.length <= 80 && t.endsWith(':')) {
      return OcrTextPreset.h3;
    }
    if (t.length <= 120 && RegExp(r'^(Hình|Figure|Bảng|Table)\s+\d+', caseSensitive: false).hasMatch(t)) {
      return OcrTextPreset.caption;
    }
    return OcrTextPreset.body;
  }
}
