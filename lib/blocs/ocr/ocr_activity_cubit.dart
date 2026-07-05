import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readbox/blocs/base_bloc/base_state.dart';
import 'package:readbox/blocs/ocr/ocr_activity_state.dart';
import 'package:readbox/blocs/utils.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/domain/repositories/ocr_repository.dart';
import 'package:readbox/services/ocr_socket_service.dart';

/// Cubit màn theo dõi OCR / export đang chờ kết quả (socket + refresh).
class OcrActivityCubit extends Cubit<BaseState> {
  OcrActivityCubit(this._repository, this._socketService) : super(InitState());

  final OcrRepository _repository;
  final OcrSocketService _socketService;

  final Map<String, OcrJobModel> _jobsById = {};
  final Set<String> _trackedExportIds = {};
  StreamSubscription<OcrJobUpdate>? _socketSub;
  Timer? _pollTimer;

  OcrActivityData? get data =>
      state is LoadedState<OcrActivityData>
          ? (state as LoadedState<OcrActivityData>).data
          : null;

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) emit(LoadingState());
    try {
      await _socketService.connect();
      final page = await _repository.getJobs(page: 1, size: 50);
      _jobsById
        ..clear()
        ..addEntries(page.jobs.map((j) => MapEntry(j.id, j)));
      _joinActiveRooms();
      _emitGrouped();
    } catch (e) {
      emit(ErrorState(BlocUtils.getMessageError(e), isLocalizeMessage: false));
    }
  }

  Future<void> refresh() => load(showLoading: false);

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (data?.pendingCount != null && data!.pendingCount > 0) {
        refresh();
      }
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> requeueOcr(String id) async {
    try {
      final job = await _repository.requeueJob(id);
      _jobsById[job.id] = job;
      _socketService.joinJob(job.rawId);
      _emitGrouped();
    } catch (e) {
      emit(ErrorState(BlocUtils.getMessageError(e), isLocalizeMessage: false));
      _emitGrouped();
    }
  }

  void bindSocket() {
    _socketSub?.cancel();
    _socketSub = _socketService.updates.listen(_onSocketUpdate);
  }

  void _onSocketUpdate(OcrJobUpdate update) {
    final existing = _jobsById.values
        .cast<OcrJobModel?>()
        .firstWhere((j) => j?.rawId == update.jobId, orElse: () => null);
    if (existing == null) return;

    final job = existing.applyUpdate(
      status: update.status,
      processedPages: update.processedPages,
      totalPages: update.totalPages,
      error: update.error,
      exportStatus: update.exportStatus,
      pdfUrl: update.pdfUrl,
      exportError: update.exportError,
    );
    _jobsById[job.id] = job;
    if (job.isExportPending) {
      _trackedExportIds.add(job.id);
    }
    _emitGrouped();
  }

  void _emitGrouped() {
    final jobs = _jobsById.values.toList()
      ..sort((a, b) {
        final at = a.updatedAt ?? a.createdAt;
        final bt = b.updatedAt ?? b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });

    for (final job in jobs) {
      if (job.isExportPending) {
        _trackedExportIds.add(job.id);
      }
    }

    final ocrPending = jobs.where((j) => j.isOcrPending).toList();
    final exportPending = jobs.where((j) => j.isExportPending).toList();
    final exportFailed = jobs
        .where(
          (j) => _trackedExportIds.contains(j.id) && j.isExportFailed,
        )
        .toList();
    final exportReady = jobs
        .where(
          (j) =>
              _trackedExportIds.contains(j.id) &&
              j.isExportReady &&
              !j.isExportPending,
        )
        .toList();

    emit(
      LoadedState(
        OcrActivityData(
          ocrPending: ocrPending,
          exportPending: exportPending,
          exportReady: exportReady,
          exportFailed: exportFailed,
        ),
        message: '',
        isLocalizeMessage: false,
      ),
    );
  }

  void _joinActiveRooms() {
    for (final job in _jobsById.values) {
      if (job.isActivityPending) {
        _socketService.joinJob(job.rawId);
      }
    }
  }

  @override
  Future<void> close() {
    stopPolling();
    _socketSub?.cancel();
    return super.close();
  }
}
