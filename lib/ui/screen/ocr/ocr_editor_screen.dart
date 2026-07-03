import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readbox/blocs/base_bloc/base_state.dart';
import 'package:readbox/blocs/ocr/ocr_editor_cubit.dart';
import 'package:readbox/blocs/ocr/ocr_editor_state.dart';
import 'package:readbox/domain/data/models/models.dart';
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
                IconButton(
                  tooltip: 'Hoàn tác',
                  onPressed: context.read<OcrEditorCubit>().canUndo
                      ? () => context.read<OcrEditorCubit>().undo()
                      : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: 'Làm lại',
                  onPressed: context.read<OcrEditorCubit>().canRedo
                      ? () => context.read<OcrEditorCubit>().redo()
                      : null,
                  icon: const Icon(Icons.redo),
                ),
                IconButton(
                  tooltip: 'Lưu chỉnh sửa',
                  onPressed: (data.isDirty && !data.isSaving)
                      ? () => _onSave(context)
                      : null,
                  icon: data.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                ),
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
                    } else if (v == 'normalize_page') {
                      context.read<OcrEditorCubit>().normalizeCurrentPageStyles();
                      AppSnackBar.show(
                        context,
                        message: 'Đã chuẩn hóa preset cho trang hiện tại.',
                        snackBarType: SnackBarType.success,
                      );
                    } else if (v == 'body_page') {
                      context
                          .read<OcrEditorCubit>()
                          .applyPresetToCurrentPage(OcrTextPreset.body);
                      AppSnackBar.show(
                        context,
                        message: 'Đã áp Body cho toàn bộ dòng của trang hiện tại.',
                        snackBarType: SnackBarType.success,
                      );
                    } else if (v == 'preview_edited') {
                      _showEditedPreview(context, data);
                    } else {
                      _onExport(context, v);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'preview_edited',
                      child: Text('Preview dữ liệu đã sửa'),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'normalize_page',
                      child: Text('Chuẩn hóa preset trang hiện tại'),
                    ),
                    PopupMenuItem(
                      value: 'body_page',
                      child: Text('Áp Body cho toàn trang'),
                    ),
                    PopupMenuDivider(),
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
                onLineStyleChanged: (style) {
                  final sel = data.selection;
                  if (sel?.kind == OcrEditorSelectionKind.line) {
                    context
                        .read<OcrEditorCubit>()
                        .updateLineStyle(sel!.index, style);
                  }
                },
                onLinePresetChanged: (preset) {
                  final sel = data.selection;
                  if (sel?.kind == OcrEditorSelectionKind.line) {
                    context
                        .read<OcrEditorCubit>()
                        .applyLinePreset(sel!.index, preset);
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
                onNextMissingLine: () =>
                    context.read<OcrEditorCubit>().selectNextMissingLine(),
                onPrevMissingLine: () =>
                    context.read<OcrEditorCubit>().selectPrevMissingLine(),
                onMoveLineUp: () =>
                    context.read<OcrEditorCubit>().moveSelectedLineUp(),
                onMoveLineDown: () =>
                    context.read<OcrEditorCubit>().moveSelectedLineDown(),
                onDeleteImage: () =>
                    context.read<OcrEditorCubit>().deleteSelectedImage(),
                onDeleteTable: () =>
                    context.read<OcrEditorCubit>().deleteSelectedTable(),
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
      final state = cubit.state;
      if (state is LoadedState<OcrEditorLoaded> && state.data.isDirty) {
        await cubit.saveEdits();
      }
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

  Future<void> _onSave(BuildContext context) async {
    final cubit = context.read<OcrEditorCubit>();
    try {
      await cubit.saveEdits();
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: 'Đã lưu chỉnh sửa OCR.',
        snackBarType: SnackBarType.success,
      );
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

  void _showEditedPreview(BuildContext context, OcrEditorLoaded data) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Preview sau chỉnh sửa'),
          content: SizedBox(
            width: 560,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: data.pages.length,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (_, i) {
                final page = data.pages[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trang ${page.page}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...page.lines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          line.text,
                          style: _lineTextStyle(line.style),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  TextStyle _lineTextStyle(OcrTextStyleModel? style) {
    final s = style ?? const OcrTextStyleModel();
    return TextStyle(
      fontFamily: s.fontFamily,
      fontSize: s.fontSize,
      fontWeight: s.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
      decoration: s.underline ? TextDecoration.underline : TextDecoration.none,
      height: s.lineHeight,
      color: _parseHexColor(s.colorHex),
    );
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final raw = hex.replaceAll('#', '');
    if (raw.length != 6) return null;
    final value = int.tryParse('FF$raw', radix: 16);
    if (value == null) return null;
    return Color(value);
  }
}
