import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readbox/blocs/base_bloc/base_state.dart';
import 'package:readbox/blocs/utils.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/domain/repositories/ocr_repository.dart';

/// Cubit xử lý luồng upload tài liệu để tạo job OCR.
///
/// State:
/// - [InitState]  : chưa chọn file.
/// - [LoadedState<File>]     : đã chọn file (chưa upload).
/// - [LoadingState]          : đang upload (theo dõi [uploadProgress]).
/// - [LoadedState<OcrJobModel>] : tạo job thành công.
/// - [ErrorState]            : lỗi.
class OcrUploadCubit extends Cubit<BaseState> {
  final OcrRepository _repository;

  OcrUploadCubit(this._repository) : super(InitState());

  File? _selectedFile;
  String _lang = 'auto';
  bool _extractImages = true;
  double _uploadProgress = 0.0;
  CancelToken? _cancelToken;

  File? get selectedFile => _selectedFile;
  String get lang => _lang;
  bool get extractImages => _extractImages;
  double get uploadProgress => _uploadProgress;

  void selectFile(File file) {
    _selectedFile = file;
    _uploadProgress = 0.0;
    emit(LoadedState<File>(file, message: '', isLocalizeMessage: false));
  }

  void setLang(String lang) {
    _lang = lang;
    final file = _selectedFile;
    if (file != null) {
      emit(LoadedState<File>(file, message: '', isLocalizeMessage: false));
    }
  }

  void setExtractImages(bool value) {
    _extractImages = value;
    final file = _selectedFile;
    if (file != null) {
      emit(LoadedState<File>(file, message: '', isLocalizeMessage: false));
    }
  }

  void reset() {
    _selectedFile = null;
    _uploadProgress = 0.0;
    _cancelToken = null;
    emit(InitState());
  }

  void cancelUpload() {
    _cancelToken?.cancel('cancelled');
  }

  /// Tạo job OCR từ file đã chọn. Trả về job khi thành công (hoặc null nếu lỗi).
  Future<OcrJobModel?> createJob() async {
    final file = _selectedFile;
    if (file == null) {
      emit(ErrorState('Vui lòng chọn tệp trước', isLocalizeMessage: false));
      return null;
    }

    try {
      _uploadProgress = 0.0;
      _cancelToken = CancelToken();
      emit(LoadingState());

      final job = await _repository.createJob(
        file: file,
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
}
