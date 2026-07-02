import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:readbox/blocs/base_bloc/base_state.dart';
import 'package:readbox/blocs/ocr/ocr.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/injection_container.dart';
import 'package:readbox/res/app_size.dart';
import 'package:readbox/ui/screen/ocr/ocr_upload_screen.dart';
import 'package:readbox/ui/screen/ocr/ocr_editor_screen.dart';
import 'package:readbox/ui/widget/widget.dart';

/// Bộ lọc trạng thái hiển thị trên đầu danh sách.
class _StatusFilter {
  final String label;
  final String? value;
  const _StatusFilter(this.label, this.value);
}

/// Màn hình danh sách job OCR: trạng thái + tiến độ realtime, refresh, load-more.
class OcrJobListScreen extends StatelessWidget {
  /// Job vừa tạo từ màn Upload (nếu có) để chèn ngay lên đầu danh sách.
  final OcrJobModel? newlyCreatedJob;

  const OcrJobListScreen({super.key, this.newlyCreatedJob});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OcrJobCubit>(),
      child: _OcrJobListBody(newlyCreatedJob: newlyCreatedJob),
    );
  }
}

class _OcrJobListBody extends StatefulWidget {
  final OcrJobModel? newlyCreatedJob;

  const _OcrJobListBody({this.newlyCreatedJob});

  @override
  State<_OcrJobListBody> createState() => _OcrJobListBodyState();
}

class _OcrJobListBodyState extends State<_OcrJobListBody> {
  final RefreshController _refreshController = RefreshController();

  static const _filters = [
    _StatusFilter('Tất cả', null),
    _StatusFilter('Đang chờ', 'queued'),
    _StatusFilter('Đang xử lý', 'processing'),
    _StatusFilter('Hoàn tất', 'done'),
    _StatusFilter('Thất bại', 'failed'),
  ];

  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cubit = context.read<OcrJobCubit>();
      await cubit.loadJobs();
      final created = widget.newlyCreatedJob;
      if (created != null && mounted) {
        cubit.addJob(created);
      }
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await context.read<OcrJobCubit>().loadJobs(
          status: _selectedStatus,
          showLoading: false,
        );
    _refreshController.refreshCompleted();
  }

  Future<void> _onLoadMore() async {
    await context.read<OcrJobCubit>().loadMore();
    _refreshController.loadComplete();
  }

  void _onFilterChanged(String? status) {
    setState(() => _selectedStatus = status);
    context.read<OcrJobCubit>().loadJobs(status: status);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BaseScreen<OcrJobCubit>(
      colorBg: colorScheme.surface,
      title: 'Công việc OCR',
      showGlobalFloatingActions: false,
      floatingButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OcrUploadScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo mới'),
      ),
      body: Column(
        children: [
          _buildFilterBar(colorScheme),
          Expanded(
            child: BlocBuilder<OcrJobCubit, BaseState>(
              builder: (context, state) {
                if (state is LoadingState) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ErrorState) {
                  return _buildError(context, state, colorScheme);
                }
                final jobs = state is LoadedState<List<OcrJobModel>>
                    ? state.data
                    : const <OcrJobModel>[];
                if (jobs.isEmpty) {
                  return _buildEmpty(colorScheme);
                }
                return CustomSmartRefresher(
                  refreshController: _refreshController,
                  enablePullDown: true,
                  enablePullUp: context.read<OcrJobCubit>().canLoadMore,
                  onRefresh: _onRefresh,
                  onLoadMore: _onLoadMore,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  listData: jobs,
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return OcrJobCard(
                      job: job,
                      onTap: job.status == OcrJobStatus.done
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OcrEditorScreen(
                                    jobId: job.id,
                                    title: job.displayName,
                                  ),
                                ),
                              );
                            }
                          : null,
                      onRetry: job.status == OcrJobStatus.failed
                          ? () =>
                              context.read<OcrJobCubit>().requeue(job.id)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ColorScheme colorScheme) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected = _selectedStatus == filter.value;
          return ChoiceChip(
            label: Text(filter.label),
            selected: selected,
            onSelected: (_) => _onFilterChanged(filter.value),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 72,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có công việc OCR nào',
            style: TextStyle(
              fontSize: AppSize.fontSizeXLarge,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nhấn "Tạo mới" để tải tài liệu và bắt đầu.',
            style: TextStyle(
              fontSize: AppSize.fontSizeMedium,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    ErrorState state,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: colorScheme.error),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              state.message ?? state.data?.toString() ?? 'Đã xảy ra lỗi',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context
                .read<OcrJobCubit>()
                .loadJobs(status: _selectedStatus),
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
