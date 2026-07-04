import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readbox/blocs/base_bloc/base_state.dart';
import 'package:readbox/blocs/ocr/ocr_editor_cubit.dart';
import 'package:readbox/blocs/ocr/ocr_editor_state.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/domain/repositories/ocr_repository.dart';
import 'package:readbox/gen/i18n/generated_locales/l10n.dart';
import 'package:readbox/injection_container.dart';
import 'package:readbox/res/res.dart';
import 'package:readbox/ui/widget/widget.dart';

/// Màn chỉnh sửa kết quả OCR: phía trên thumbnail + preview; phía dưới panel
/// chỉnh sửa kèm cột action dọc bên phải (undo/redo/lưu/menu).
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

class _OcrEditorBody extends StatefulWidget {
  final String? title;

  const _OcrEditorBody({this.title});

  @override
  State<_OcrEditorBody> createState() => _OcrEditorBodyState();
}

class _OcrEditorBodyState extends State<_OcrEditorBody> {
  bool _addMode = false;
  Rect? _pendingInsertRect;

  void _toggleAddMode() {
    // final entering = !_addMode;
    setState(() {
      _addMode = !_addMode;
      _pendingInsertRect = null;
    });
    // if (entering) {
    //   AppSnackBar.show(
    //     context,
    //     message: AppLocalizations.of(context).ocr_add_line_draw_hint,
    //     snackBarType: SnackBarType.info,
    //   );
    // }
  }

  void _onPendingRectChanged(Rect? rect) {
    setState(() => _pendingInsertRect = rect);
    // if (rect != null) {
    //   AppSnackBar.show(
    //     context,
    //     message: AppLocalizations.of(context).ocr_add_line_selected_hint,
    //     snackBarType: SnackBarType.info,
    //   );
    // }
  }

  void _onRedrawPendingRect() {
    setState(() => _pendingInsertRect = null);
    // if (_addMode) {
    //   AppSnackBar.show(
    //     context,
    //     message: AppLocalizations.of(context).ocr_add_line_draw_hint,
    //     snackBarType: SnackBarType.info,
    //   );
    // }
  }

  void _confirmInsert() {
    final rect = _pendingInsertRect;
    if (rect == null) return;
    context.read<OcrEditorCubit>().addLine(rect);
    setState(() {
      _pendingInsertRect = null;
      _addMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

    return BaseScreen<OcrEditorCubit>(
      colorBg: colorScheme.surface,
      title: widget.title ?? AppLocalizations.current.ocr_editor,
      showGlobalFloatingActions: false,
      useSafeAreaBottom: true,
      autoHandleState: true,
      body: BlocBuilder<OcrEditorCubit, BaseState>(
        builder: (context, state) {
          if (state is! LoadedState<OcrEditorLoaded>) {
            return const SizedBox.shrink();
          }
          final data = state.data;
          return LayoutBuilder(
            builder: (context, constraints) {
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
                addMode: _addMode,
                pendingRect: _pendingInsertRect,
                onPendingRectChanged: _onPendingRectChanged,
                onLineTap: context.read<OcrEditorCubit>().selectLine,
                onImageTap: context.read<OcrEditorCubit>().selectImage,
                onTableTap: context.read<OcrEditorCubit>().selectTable,
                onLineBboxChanged: (index, rect) => context
                    .read<OcrEditorCubit>()
                    .updateLineBbox(index, rect),
                canPrev: data.currentPageIndex > 0,
                canNext: data.currentPageIndex < data.pages.length - 1,
                onPrevPage: () => context
                    .read<OcrEditorCubit>()
                    .goToPage(data.currentPageIndex - 1),
                onNextPage: () => context
                    .read<OcrEditorCubit>()
                    .goToPage(data.currentPageIndex + 1),
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
                onDeleteImage: () =>
                    context.read<OcrEditorCubit>().deleteSelectedImage(),
                onDeleteTable: () =>
                    context.read<OcrEditorCubit>().deleteSelectedTable(),
              );

              final cubit = context.read<OcrEditorCubit>();
              final operationBar = OcrEditorOperationBar(
                addMode: _addMode,
                hasPendingRect: _pendingInsertRect != null,
                selection: data.selection,
                onToggleAddMode: _toggleAddMode,
                onRedraw: _onRedrawPendingRect,
                onInsert: _confirmInsert,
                onMoveLineUp: cubit.moveSelectedLineUp,
                onMoveLineDown: cubit.moveSelectedLineDown,
                canMoveLineUp: cubit.canMoveSelectedLineUp(),
                canMoveLineDown: cubit.canMoveSelectedLineDown(),
                onDeleteLine: cubit.deleteSelectedLine,
              );

              // Trên: thumbnail (trái) + preview PDF (phải).
              // Dưới: panel chỉnh sửa — chia dọc theo tỷ lệ 2:1, có splitter.
              final previewArea = ProportionalSplitView(
                direction: Axis.horizontal,
                flexes: const [1, 4],
                minSizes: const [72, 200],
                children: [thumbnailRail, preview],
              );

              final actionRail = OcrEditorActionRail(
                canUndo: context.read<OcrEditorCubit>().canUndo,
                canRedo: context.read<OcrEditorCubit>().canRedo,
                isDirty: data.isDirty,
                isSaving: data.isSaving,
                isExporting: data.isExporting,
                onUndo: () => context.read<OcrEditorCubit>().undo(),
                onRedo: () => context.read<OcrEditorCubit>().redo(),
                onSave: () => _onSave(context),
                onMenuAction: (v) => _handleMenuAction(context, v, data),
              );

              // Dưới: editor + thanh thao tác + cột action bám phải.
              final editorArea = Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: editor),
                        operationBar,
                      ],
                    ),
                  ),
                  actionRail,
                ],
              );

              return ProportionalSplitView(
                direction: Axis.vertical,
                flexes: const [2, 1],
                minSizes: const [240, 180],
                children: [previewArea, editorArea],
              );
            },
          );
        },
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    String action,
    OcrEditorLoaded data,
  ) {
    final l = AppLocalizations.current;
    switch (action) {
      case 'requeue':
        _onRequeue(context);
      case 'normalize_page':
        context.read<OcrEditorCubit>().normalizeCurrentPageStyles();
        AppSnackBar.show(
          context,
          message: l.ocr_normalize_page_success,
          snackBarType: SnackBarType.success,
        );
      case 'body_page':
        context
            .read<OcrEditorCubit>()
            .applyPresetToCurrentPage(OcrTextPreset.body);
        AppSnackBar.show(
          context,
          message: l.ocr_apply_body_page_success,
          snackBarType: SnackBarType.success,
        );
      case 'preview_edited':
        _showEditedPreview(context, data);
      default:
        _onExport(context, action);
    }
  }

  Future<void> _onRequeue(BuildContext context) async {
    final cubit = context.read<OcrEditorCubit>();
    try {
      await cubit.requeue();
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        message: AppLocalizations.current.ocr_requeue_success,
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
          message: AppLocalizations.current.ocr_export_txt_success,
          snackBarType: SnackBarType.success,
        );
      } else if (format == 'pdf') {
        AppSnackBar.show(
          context,
          message: AppLocalizations.current.ocr_export_pdf_processing,
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
        message: AppLocalizations.current.ocr_save_success,
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
          title: Text(AppLocalizations.of(ctx).ocr_preview_after_edit),
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
                      AppLocalizations.of(ctx).ocr_page_label(page.page),
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
              child: Text(AppLocalizations.of(ctx).close),
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
