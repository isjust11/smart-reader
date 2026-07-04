import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:readbox/blocs/ocr/ocr_editor_state.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/gen/i18n/generated_locales/l10n.dart';
import 'package:readbox/services/ocr_page_render_service.dart';
import 'package:readbox/ui/widget/app_widgets/ocr_page_canvas.dart';
import 'package:readbox/ui/widget/app_widgets/ocr_page_nav_controls.dart';
import 'package:readbox/ui/widget/app_widgets/ocr_preview_zoom_controls.dart';
import 'package:readbox/utils/ocr_add_line_geometry.dart';

/// Preview trang tài liệu + overlay bbox + zoom/pagination.
///
/// Chế độ "thêm dòng" (vẽ khung) do parent điều khiển qua [addMode] /
/// [onPendingRectChanged]; các nút thao tác nằm ở [OcrEditorOperationBar].
class OcrPagePreview extends StatefulWidget {
  final OcrJobModel job;
  final OcrPageModel page;
  final OcrEditorSelection? selection;
  final ValueChanged<int> onLineTap;
  final ValueChanged<int> onImageTap;
  final ValueChanged<int> onTableTap;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;
  final bool canPrev;
  final bool canNext;

  /// Chế độ vẽ khung mới — bật/tắt từ vùng thao tác phía dưới.
  final bool addMode;

  /// Gọi khi người dùng kéo xong một khung hợp lệ (chờ xác nhận Insert).
  final ValueChanged<Rect?>? onPendingRectChanged;

  /// Khung đã vẽ, chờ xác nhận — hiển thị trên canvas cho đến Insert / Vẽ lại.
  final Rect? pendingRect;

  /// Cập nhật bbox dòng sau khi kéo/chỉnh trên preview.
  final void Function(int index, Rect rect)? onLineBboxChanged;

  const OcrPagePreview({
    super.key,
    required this.job,
    required this.page,
    this.selection,
    required this.onLineTap,
    required this.onImageTap,
    required this.onTableTap,
    this.onPrevPage,
    this.onNextPage,
    this.canPrev = false,
    this.canNext = false,
    this.addMode = false,
    this.onPendingRectChanged,
    this.pendingRect,
    this.onLineBboxChanged,
  });

  @override
  State<OcrPagePreview> createState() => _OcrPagePreviewState();
}

class _OcrPagePreviewState extends State<OcrPagePreview> {
  static const double _minScale = 0.5;
  static const double _maxScale = 4;

  final _renderService = OcrPageRenderService();
  final _transformCtrl = TransformationController();
  Uint8List? _pdfBytes;
  bool _loading = false;
  Size _viewportSize = Size.zero;
  bool _showDocumentBackground = true;

  Offset? _drawStart;
  Rect? _drawRect;
  Rect? _editingLineRect;
  int? _editingLineIndex;

  bool get _pendingDraggable =>
      widget.pendingRect != null && _drawRect == null;

  bool get _isEditingLineBbox => _editingLineRect != null;

  Rect? get _selectedLineRect {
    if (widget.addMode) return null;
    final sel = widget.selection;
    if (sel?.kind != OcrEditorSelectionKind.line) return null;
    if (sel!.index < 0 || sel.index >= widget.page.lines.length) return null;
    return OcrAddLineGeometry.bboxRect(widget.page.lines[sel.index].bbox);
  }

  Rect? get _displaySelectedLineRect =>
      _editingLineRect ?? _selectedLineRect;

  String? get _pageImageUrl => widget.page.pageImageUrl;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(covariant OcrPagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.page != widget.page.page ||
        oldWidget.job.fileUrl != widget.job.fileUrl) {
      _resetZoom();
      _loadPreview();
    }
    if (!widget.addMode && oldWidget.addMode) {
      _drawStart = null;
      _drawRect = null;
    }
    if (widget.selection != oldWidget.selection ||
        widget.page.page != oldWidget.page.page) {
      _clearLineEditState();
    } else if (_editingLineIndex != null) {
      final idx = _editingLineIndex!;
      if (idx >= widget.page.lines.length) {
        _clearLineEditState();
      } else {
        final pageRect =
            OcrAddLineGeometry.bboxRect(widget.page.lines[idx].bbox);
        if (_editingLineRect == null && pageRect != _selectedLineRect) {
          _clearLineEditState();
        }
      }
    }
  }

  void _clearLineEditState() {
    _editingLineRect = null;
    _editingLineIndex = null;
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    if (_pageImageUrl != null && _pageImageUrl!.isNotEmpty) {
      setState(() {
        _pdfBytes = null;
        _loading = false;
      });
      return;
    }

    final url = widget.job.fileUrl;
    if (url == null) return;
    if (!_renderService.isPdf(widget.job.mimeType, url)) {
      setState(() => _pdfBytes = null);
      return;
    }
    setState(() => _loading = true);
    final local = await _renderService.ensureLocalFile(url);
    if (!mounted) return;
    if (local == null) {
      setState(() {
        _loading = false;
        _pdfBytes = null;
      });
      return;
    }
    final hasExactSize = widget.page.width > 0 && widget.page.height > 0;
    final bytes = await _renderService.renderPdfPage(
      localPath: local,
      pageNumber: widget.page.page,
      targetWidth: hasExactSize ? widget.page.width : 1200,
      targetHeight: hasExactSize ? widget.page.height : null,
    );
    if (!mounted) return;
    setState(() {
      _pdfBytes = bytes;
      _loading = false;
    });
  }

  void _resetZoom() {
    _transformCtrl.value = Matrix4.identity();
  }

  void _zoomBy(double factor) {
    final currentScale = _transformCtrl.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(_minScale, _maxScale);
    final actualFactor = targetScale / currentScale;
    if (actualFactor == 1) return;
    final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final updated = _transformCtrl.value.clone()
      ..translate(center.dx, center.dy)
      ..scale(actualFactor, actualFactor)
      ..translate(-center.dx, -center.dy);
    _transformCtrl.value = updated;
  }

  void _onDrawStart(DragStartDetails details) {
    widget.onPendingRectChanged?.call(null);
    setState(() {
      _drawStart = details.localPosition;
      _drawRect = null;
    });
  }

  void _onDrawUpdate(DragUpdateDetails details) {
    final start = _drawStart;
    if (start == null) return;
    setState(() {
      _drawRect = OcrAddLineGeometry.buildFromDrag(
        start: start,
        end: details.localPosition,
        page: widget.page,
      );
    });
  }

  void _onDrawEnd(DragEndDetails details) {
    final rect = _drawRect;
    setState(() {
      _drawStart = null;
      _drawRect = null;
    });
    if (rect != null && OcrAddLineGeometry.isValidPlacement(rect)) {
      widget.onPendingRectChanged?.call(rect);
    }
  }

  void _onPendingMove(Offset delta) {
    final current = widget.pendingRect;
    if (current == null) return;
    widget.onPendingRectChanged?.call(
      OcrAddLineGeometry.move(current, delta, widget.page),
    );
  }

  void _onPendingResize(OcrPendingRectEdge edge, Offset delta) {
    final current = widget.pendingRect;
    if (current == null) return;
    widget.onPendingRectChanged?.call(
      OcrAddLineGeometry.resizeWidth(current, edge, delta, widget.page),
    );
  }

  void _onSelectedLineMove(Offset delta) {
    final sel = widget.selection;
    if (sel?.kind != OcrEditorSelectionKind.line) return;

    final base = _editingLineRect ?? _selectedLineRect;
    if (base == null || base.isEmpty) return;

    setState(() {
      _editingLineIndex = sel!.index;
      _editingLineRect = OcrAddLineGeometry.move(base, delta, widget.page);
    });
  }

  void _onSelectedLineResize(OcrPendingRectEdge edge, Offset delta) {
    final sel = widget.selection;
    if (sel?.kind != OcrEditorSelectionKind.line) return;

    final base = _editingLineRect ?? _selectedLineRect;
    if (base == null || base.isEmpty) return;

    setState(() {
      _editingLineIndex = sel!.index;
      _editingLineRect =
          OcrAddLineGeometry.resizeWidth(base, edge, delta, widget.page);
    });
  }

  void _commitSelectedLineEdit() {
    final index = _editingLineIndex;
    final rect = _editingLineRect;
    if (index == null || rect == null) return;

    widget.onLineBboxChanged?.call(index, rect);
    _clearLineEditState();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            _viewportSize = constraints.biggest;
                            return InteractiveViewer(
                              transformationController: _transformCtrl,
                              minScale: _minScale,
                              maxScale: _maxScale,
                              panEnabled: !widget.addMode && !_isEditingLineBbox,
                              child: Center(
                                child: OcrPageCanvas(
                                  job: widget.job,
                                  page: widget.page,
                                  selection: widget.selection,
                                  isPdf: _renderService.isPdf(
                                    widget.job.mimeType,
                                    widget.job.fileUrl,
                                  ),
                                  pdfBytes: _pdfBytes,
                                  showDocumentBackground:
                                      _showDocumentBackground,
                                  onLineTap: widget.onLineTap,
                                  onImageTap: widget.onImageTap,
                                  onTableTap: widget.onTableTap,
                                  addMode: widget.addMode,
                                  drawRect: _drawRect ?? widget.pendingRect,
                                  pendingDraggable: _pendingDraggable,
                                  onDrawStart: _onDrawStart,
                                  onDrawUpdate: _onDrawUpdate,
                                  onDrawEnd: _onDrawEnd,
                                  onPendingMove: _onPendingMove,
                                  onPendingResize: _onPendingResize,
                                  selectedLineRect: _displaySelectedLineRect,
                                  onSelectedLineMove: _onSelectedLineMove,
                                  onSelectedLineResize: _onSelectedLineResize,
                                  onSelectedLineEditEnd: _commitSelectedLineEdit,
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 8, 4),
          child: SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: OcrPageNavControls(
                      pageNumber: widget.page.page,
                      canPrev: widget.canPrev,
                      canNext: widget.canNext,
                      onPrevPage: widget.onPrevPage,
                      onNextPage: widget.onNextPage,
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 8,
                  thickness: 1,
                  indent: 4,
                  endIndent: 4,
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
                IconButton(
                  tooltip: _showDocumentBackground
                      ? l.ocr_hide_document_background
                      : l.ocr_show_document_background,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    _showDocumentBackground
                        ? Icons.layers_clear_outlined
                        : Icons.layers_outlined,
                    size: 14,
                  ),
                  onPressed: () {
                    setState(() {
                      _showDocumentBackground = !_showDocumentBackground;
                    });
                  },
                ),
                OcrPreviewZoomControls(
                  onZoomOut: () => _zoomBy(1 / 1.3),
                  onResetZoom: _resetZoom,
                  onZoomIn: () => _zoomBy(1.3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
