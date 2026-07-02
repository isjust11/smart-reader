import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readbox/blocs/base_bloc/base_state.dart';
import 'package:readbox/blocs/ocr/ocr_editor_cubit.dart';
import 'package:readbox/blocs/ocr/ocr_editor_state.dart';
import 'package:readbox/domain/repositories/ocr_repository.dart';
import 'package:readbox/injection_container.dart';
import 'package:readbox/res/res.dart';
import 'package:readbox/ui/widget/widget.dart';

/// Màn chỉnh sửa kết quả OCR: rail thumbnail hẹp bám trái (cuộn theo trang),
/// bên phải là khu vực thao tác gồm preview (bbox click được) + panel chỉnh
/// sửa text/hình/bảng.
class OcrEditorScreen extends StatelessWidget {
  final String jobId;
  final String? title;

  const OcrEditorScreen({super.key, required this.jobId, this.title});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OcrEditorCubit(getIt<OcrRepository>(), jobId)..load(),
      child: _OcrEditorBody(title: title),
    );
  }
}

class _OcrEditorBody extends StatelessWidget {
  final String? title;

  const _OcrEditorBody({this.title});

  @override
  Widget build(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

    return BaseScreen<OcrEditorCubit>(
      colorBg: colorScheme.surface,
      title: title ?? 'Chỉnh sửa OCR',
      showGlobalFloatingActions: false,
      rightWidgets: [
        BlocBuilder<OcrEditorCubit, BaseState>(
          builder: (context, state) {
            final data = state is LoadedState<OcrEditorLoaded>
                ? state.data
                : null;
            if (data == null) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data.isDirty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Chip(
                      label: const Text('Chưa lưu'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: colorScheme.tertiaryContainer,
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'requeue') {
                      _onRequeue(context);
                    } else {
                      _onExport(context, v);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'txt', child: Text('Xuất .txt')),
                    PopupMenuItem(
                      value: 'pdf',
                      child: Text('Xuất searchable PDF'),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'requeue',
                      child: Text('Xử lý lại (cập nhật ảnh trang, bbox)'),
                    ),
                  ],
                  icon: data.isExporting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                ),
              ],
            );
          },
        ),
      ],
      body: BlocBuilder<OcrEditorCubit, BaseState>(
        builder: (context, state) {
          if (state is LoadingState) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ErrorState) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  state.message ?? 'Lỗi tải dữ liệu',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (state is! LoadedState<OcrEditorLoaded>) {
            return const SizedBox.shrink();
          }
          final data = state.data;
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final thumbnailRail = OcrPageThumbnailRail(
                job: data.job,
                pages: data.pages,
                currentIndex: data.currentPageIndex,
                onSelect: (index) =>
                    context.read<OcrEditorCubit>().goToPage(index),
              );
              final preview = OcrPagePreview(
                job: data.job,
                page: data.currentPage,
                selection: data.selection,
                onLineTap: context.read<OcrEditorCubit>().selectLine,
                onImageTap: context.read<OcrEditorCubit>().selectImage,
                onTableTap: context.read<OcrEditorCubit>().selectTable,
                canPrev: data.currentPageIndex > 0,
                canNext: data.currentPageIndex < data.pages.length - 1,
                onPrevPage: () => context
                    .read<OcrEditorCubit>()
                    .goToPage(data.currentPageIndex - 1),
                onNextPage: () => context
                    .read<OcrEditorCubit>()
                    .goToPage(data.currentPageIndex + 1),
                onAddLine: (rect) =>
                    context.read<OcrEditorCubit>().addLine(rect),
              );
              final editor = OcrEditorPanel(
                page: data.currentPage,
                selection: data.selection,
                onLineTextChanged: (text) {
                  final sel = data.selection;
                  if (sel?.kind == OcrEditorSelectionKind.line) {
                    context
                        .read<OcrEditorCubit>()
                        .updateLineText(sel!.index, text);
                  }
                },
                onTableHtmlChanged: (html) {
                  final sel = data.selection;
                  if (sel?.kind == OcrEditorSelectionKind.table) {
                    context
                        .read<OcrEditorCubit>()
                        .updateTableHtml(sel!.index, html);
                  }
                },
                onImageReplaced: (path) {
                  final sel = data.selection;
                  if (sel?.kind == OcrEditorSelectionKind.image) {
                    context
                        .read<OcrEditorCubit>()
                        .replaceImageAsset(sel!.index, path);
                  }
                },
                onDeleteLine: () =>
                    context.read<OcrEditorCubit>().deleteSelectedLine(),
                onAddLine: () => context.read<OcrEditorCubit>().addLine(),
              );

              // Khu vực thao tác: preview lớn (bbox click được) + panel chỉnh
              // sửa. Trên màn hẹp xếp dọc, màn rộng xếp ngang.
              final workArea = wide
                  ? Row(
                      children: [
                        Expanded(flex: 11, child: preview),
                        Expanded(flex: 9, child: editor),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(flex: 11, child: preview),
                        Expanded(flex: 9, child: editor),
                      ],
                    );

              // Rail thumbnail luôn cố định, hẹp, cuộn dọc, bám bên trái.
              return Row(
                children: [
                  thumbnailRail,
                  Expanded(child: workArea),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onRequeue(BuildContext context) async {
    final cubit = context.read<OcrEditorCubit>();
    try {
      await cubit.requeue();
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message:
            'Đã gửi yêu cầu xử lý lại. Quay lại danh sách để theo dõi tiến trình.',
        snackBarType: SnackBarType.success,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: e.toString(),
          snackBarType: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _onExport(BuildContext context, String format) async {
    final cubit = context.read<OcrEditorCubit>();
    try {
      final result = await cubit.exportDocument(format);
      if (!context.mounted) return;
      if (format == 'txt' && result?['url'] != null) {
        AppSnackBar.show(
          context,
          message: 'Đã xuất file .txt',
          snackBarType: SnackBarType.success,
        );
      } else if (format == 'pdf') {
        AppSnackBar.show(
          context,
          message: 'Đang xử lý PDF searchable. Kiểm tra lại sau vài giây.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: e.toString(),
          snackBarType: SnackBarType.error,
        );
      }
    }
  }
}
