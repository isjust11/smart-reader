import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readbox/blocs/base_bloc/base_state.dart';
import 'package:readbox/blocs/ocr/ocr_upload_selection.dart';
import 'package:readbox/blocs/utils.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/domain/repositories/ocr_repository.dart';
import 'package:readbox/utils/ocr_images_pdf_builder.dart';

/// Cubit xử lý luồng upload tài liệu để tạo job OCR.
class OcrUploadCubit extends Cubit<BaseState> {
  final OcrRepository _repository;

  OcrUploadCubit(this._repository) : super(InitState());

  OcrUploadSelection _selection = const OcrUploadSelection();
  String _lang = 'auto';
  bool _extractImages = true;
  double _uploadProgress = 0.0;
  CancelToken? _cancelToken;

  OcrUploadSelection get selection => _selection;
  File? get selectedFile => _selection.documentFile;
  List<File> get imagePages => List.unmodifiable(_selection.imagePages);
  bool get hasSelection => _selection.hasSelection;
  String get lang => _lang;
  bool get extractImages => _extractImages;
  double get uploadProgress => _uploadProgress;

  void _emitSelection() {
    emit(LoadedState<OcrUploadSelection>(
      _selection,
      message: '',
      isLocalizeMessage: false,
    ));
  }

  /// Chọn một file PDF hoặc ảnh đơn (thay thế toàn bộ lựa chọn hiện tại).
  void selectDocument(File file) {
    if (file.path.isEmpty) {
      clearSelection();
      return;
    }
    _selection = OcrUploadSelection(documentFile: file);
    _uploadProgress = 0.0;
    _emitSelection();
  }

  @Deprecated('Dùng selectDocument')
  void selectFile(File file) => selectDocument(file);

  /// Thêm một hoặc nhiều ảnh trang (chụp camera / thư viện).
  void addImagePages(List<File> files) {
    final valid = files.where((f) => f.path.isNotEmpty).toList();
    if (valid.isEmpty) return;

    _selection = OcrUploadSelection(
      imagePages: [..._selection.imagePages, ...valid],
    );
    _uploadProgress = 0.0;
    _emitSelection();
  }

  void removeImagePage(int index) {
    if (index < 0 || index >= _selection.imagePages.length) return;
    final pages = List<File>.from(_selection.imagePages)..removeAt(index);
    _selection = pages.isEmpty
        ? const OcrUploadSelection()
        : OcrUploadSelection(imagePages: pages);
    _emitSelection();
  }

  void reorderImagePages(int oldIndex, int newIndex) {
    final pages = List<File>.from(_selection.imagePages);
    if (oldIndex < 0 ||
        oldIndex >= pages.length ||
        newIndex < 0 ||
        newIndex > pages.length) {
      return;
    }
    if (newIndex > oldIndex) newIndex -= 1;
    final item = pages.removeAt(oldIndex);
    pages.insert(newIndex, item);
    _selection = OcrUploadSelection(imagePages: pages);
    _emitSelection();
  }

  void clearSelection() {
    _selection = const OcrUploadSelection();
    _uploadProgress = 0.0;
    emit(InitState());
  }

  void setLang(String lang) {
    _lang = lang;
    if (_selection.hasSelection) _emitSelection();
  }

  void setExtractImages(bool value) {
    _extractImages = value;
    if (_selection.hasSelection) _emitSelection();
  }

  void reset() => clearSelection();

  void cancelUpload() {
    _cancelToken?.cancel('cancelled');
  }

  Future<OcrJobModel?> createJob() async {
    if (!_selection.hasSelection) {
      emit(ErrorState('Vui lòng chọn tệp trước', isLocalizeMessage: false));
      return null;
    }

    try {
      _uploadProgress = 0.0;
      _cancelToken = CancelToken();
      emit(LoadingState());

      final uploadFile = await _prepareUploadFile();

      final job = await _repository.createJob(
        file: uploadFile,
        lang: _lang,
        extractImages: _extractImages,
        cancelToken: _cancelToken,
        onSendProgress: (sent, total) {
          if (total > 0) {
            _uploadProgress = sent / total;
            emit(LoadingState());
          }
        },
      );

      _uploadProgress = 1.0;
      emit(LoadedState<OcrJobModel>(job, message: '', isLocalizeMessage: false));
      return job;
    } catch (e) {
      _uploadProgress = 0.0;
      emit(ErrorState(BlocUtils.getMessageError(e), isLocalizeMessage: false));
      return null;
    }
  }

  Future<File> _prepareUploadFile() async {
    if (_selection.hasDocument) {
      return _selection.documentFile!;
    }

    final pages = _selection.imagePages;
    if (pages.length == 1) {
      return pages.first;
    }

    final pdfPath = await OcrImagesPdfBuilder.buildPdf(pages);
    return File(pdfPath);
  }
}
