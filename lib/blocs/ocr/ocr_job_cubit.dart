import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readbox/blocs/base_bloc/base_state.dart';
import 'package:readbox/blocs/utils.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/domain/repositories/ocr_repository.dart';
import 'package:readbox/services/ocr_socket_service.dart';

/// Cubit quản lý danh sách job OCR + cập nhật realtime qua Socket.IO.
///
/// State chính: [LoadedState<List<OcrJobModel>>]. Phân trang bằng [loadMore];
/// lọc theo trạng thái bằng [status].
class OcrJobCubit extends Cubit<BaseState> {
  final OcrRepository _repository;
  final OcrSocketService _socketService;

  OcrJobCubit(this._repository, this._socketService) : super(InitState()) {
    _subscription = _socketService.updates.listen(_onSocketUpdate);
  }

  static const int _pageSize = 20;

  final List<OcrJobModel> _jobs = [];
  StreamSubscription<OcrJobUpdate>? _subscription;
  int _page = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;
  String? _status;
  String _searchQuery = '';

  List<OcrJobModel> get jobs => List.unmodifiable(_jobs);
  String? get status => _status;
  bool get canLoadMore => _page < _totalPages;

  /// Tải trang đầu (hoặc refresh). Kết nối socket + join room các job chưa xong.
  Future<void> loadJobs({String? status, bool showLoading = true}) async {
    _status = status;
    _page = 1;
    if (showLoading) emit(LoadingState());
    try {
      await _socketService.connect();
      final result = await _repository.getJobs(
        page: _page,
        size: _pageSize,
        status: _status,
      );
      _jobs
        ..clear()
        ..addAll(result.jobs);
      _totalPages = result.totalPages;
      _joinActiveRooms();
      _emitList();
    } catch (e) {
      emit(ErrorState(BlocUtils.getMessageError(e), isLocalizeMessage: false));
    }
  }

  /// Tải thêm trang tiếp theo (infinite scroll).
  Future<void> loadMore() async {
    if (_isLoadingMore || !canLoadMore) return;
    _isLoadingMore = true;
    try {
      final result = await _repository.getJobs(
        page: _page + 1,
        size: _pageSize,
        status: _status,
      );
      _page += 1;
      _totalPages = result.totalPages;
      _jobs.addAll(result.jobs);
      _joinActiveRooms();
      _emitList();
    } catch (_) {
      // Giữ nguyên danh sách hiện tại khi load-more lỗi.
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Đẩy lại một job vào hàng đợi (retry job failed).
  Future<void> requeue(String id) async {
    try {
      final job = await _repository.requeueJob(id);
      _upsertJob(job);
      _socketService.joinJob(job.rawId);
      _emitList();
    } catch (e) {
      emit(ErrorState(BlocUtils.getMessageError(e), isLocalizeMessage: false));
      _emitList();
    }
  }

  /// Chèn job mới (vừa tạo từ màn Upload) lên đầu danh sách.
  void addJob(OcrJobModel job) {
    _jobs.removeWhere((e) => e.id == job.id);
    _jobs.insert(0, job);
    _socketService.joinJob(job.rawId);
    _emitList();
  }

  /// Xoá một job khỏi server và danh sách local.
  Future<void> deleteJob(String id) async {
    try {
      await _repository.deleteJob(id);
      _jobs.removeWhere((e) => e.id == id);
      _emitList();
    } catch (e) {
      emit(ErrorState(BlocUtils.getMessageError(e), isLocalizeMessage: false));
      _emitList();
    }
  }

  /// Lọc danh sách theo tên file (local filter, không gọi API).
  void filterByQuery(String query) {
    _searchQuery = query.trim();
    _emitList();
  }

  void _onSocketUpdate(OcrJobUpdate update) {
    final index = _jobs.indexWhere((e) => e.rawId == update.jobId);
    if (index < 0) return;
    _jobs[index] = _jobs[index].applyUpdate(
      status: update.status,
      processedPages: update.processedPages,
      totalPages: update.totalPages,
      error: update.error,
    );
    _emitList();
  }

  void _upsertJob(OcrJobModel job) {
    final index = _jobs.indexWhere((e) => e.id == job.id);
    if (index >= 0) {
      _jobs[index] = job;
    } else {
      _jobs.insert(0, job);
    }
  }

  void _joinActiveRooms() {
    for (final job in _jobs) {
      if (!job.isFinished) {
        _socketService.joinJob(job.rawId);
      }
    }
  }

  void _emitList() {
    List<OcrJobModel> list = List<OcrJobModel>.from(_jobs);
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((j) => (j.originalName ?? '').toLowerCase().contains(q))
          .toList();
    }
    emit(
      LoadedState<List<OcrJobModel>>(
        list,
        message: '',
        isLocalizeMessage: false,
      ),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
