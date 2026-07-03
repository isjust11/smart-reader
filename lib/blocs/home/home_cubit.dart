import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readbox/blocs/base_bloc/base_state.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/domain/repositories/ocr_repository.dart';

class HomeLoaded {
  final List<OcrJobModel> recentJobs;
  const HomeLoaded({required this.recentJobs});
}

class HomeCubit extends Cubit<BaseState> {
  final OcrRepository _ocrRepository;

  HomeCubit(this._ocrRepository) : super(InitState());

  Future<void> load() async {
    try {
      emit(LoadingState());
      final result = await _ocrRepository.getJobs(page: 1, size: 5);
      emit(LoadedState(HomeLoaded(recentJobs: result.jobs)));
    } catch (_) {
      // Home hiển thị empty khi lỗi, không block UX
      emit(LoadedState(HomeLoaded(recentJobs: const [])));
    }
  }

  Future<void> refresh() => load();
}
