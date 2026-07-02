import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:readbox/blocs/ocr/ocr_editor_state.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/services/ocr_page_render_service.dart';
import 'package:readbox/ui/widget/app_widgets/ocr_bbox_overlay.dart';

/// Preview trang tài liệu + overlay bbox có thể click + cơ chế thu phóng
/// (pinch + nút zoom in/out/reset).
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

  /// Gọi khi người dùng vẽ xong một khung mới (chế độ "thêm dòng thủ công")
  /// — dùng cho vùng text mà OCR bỏ sót/không nhận dạng được. [rect] theo hệ
  /// toạ độ pixel gốc của trang (page.width x page.height).
  final ValueChanged<Rect>? onAddLine;

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
    this.onAddLine,
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

  bool _addMode = false;
  Offset? _drawStart;
  Rect? _drawRect;

  /// Ảnh raster đầy đủ do worker upload (đúng pixel space bbox) — ưu tiên
  /// hiển thị ảnh này thay vì tự render lại PDF trên client.
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
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    // Đã có ảnh trang sẵn từ worker (chính xác pixel-space với bbox) — không
    // cần tự tải + render lại PDF nữa.
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

  void _toggleAddMode() {
    setState(() {
      _addMode = !_addMode;
      _drawStart = null;
      _drawRect = null;
    });
  }

  void _onDrawStart(DragStartDetails details) {
    setState(() {
      _drawStart = details.localPosition;
      _drawRect = null;
    });
  }

  void _onDrawUpdate(DragUpdateDetails details) {
    final start = _drawStart;
    if (start == null) return;
    setState(() => _drawRect = Rect.fromPoints(start, details.localPosition));
  }

  void _onDrawEnd(DragEndDetails details) {
    final rect = _drawRect;
    setState(() {
      _drawStart = null;
      _drawRect = null;
    });
    // Bỏ qua thao tác chạm nhầm (kéo quá nhỏ).
    if (rect != null && rect.width > 12 && rect.height > 8) {
      widget.onAddLine?.call(rect);
    }
  }

  void _zoomBy(double factor) {
    final currentScale = _transformCtrl.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(_minScale, _maxScale);
    final actualFactor = targetScale / currentScale;
    if (actualFactor == 1) return;
    final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final updated = _transformCtrl.value.clone()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(actualFactor, actualFactor, actualFactor, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    _transformCtrl.value = updated;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                              // Tắt pan của InteractiveViewer khi đang vẽ khung
                              // mới để gesture kéo được GestureDetector bên
                              // trong xử lý thay vì bị dùng để cuộn ảnh.
                              panEnabled: !_addMode,
                              child: Center(
                                child: _buildPageContent(constraints.biggest),
                              ),
                            );
                          },
                        ),
                  if (_addMode)
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: _buildAddModeHint(colorScheme),
                    ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _buildAddModeToggle(colorScheme),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _buildZoomControls(colorScheme),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildPageControls(colorScheme),
      ],
    );
  }

  Widget _buildAddModeHint(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Kéo trên vùng OCR bỏ sót để vẽ khung mới, sau đó nhập text ở bảng bên cạnh.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAddModeToggle(ColorScheme colorScheme) {
    return Material(
      color: _addMode ? colorScheme.primary : colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: widget.onAddLine == null ? null : _toggleAddMode,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_box_outlined,
                size: 18,
                color: _addMode ? colorScheme.onPrimary : colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Thêm dòng',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _addMode
                      ? colorScheme.onPrimary
                      : colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControls(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Thu nhỏ',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18),
            onPressed: () => _zoomBy(1 / 1.3),
          ),
          IconButton(
            tooltip: 'Về kích thước gốc',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.crop_free, size: 18),
            onPressed: _resetZoom,
          ),
          IconButton(
            tooltip: 'Phóng to',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => _zoomBy(1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(Size maxSize) {
    final networkImageUrl = _pageImageUrl;
    final url = widget.job.fileUrl;
    Widget imageWidget;

    if (networkImageUrl != null && networkImageUrl.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: networkImageUrl,
        fit: BoxFit.fill,
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      );
    } else if (url == null) {
      return const Text('Không có file gốc để preview.');
    } else if (_renderService.isPdf(widget.job.mimeType, url)) {
      if (_pdfBytes == null) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Không render được trang PDF.'),
        );
      }
      // fill: ảnh đã được render đúng page.width x page.height (khớp không
      // gian pixel mà worker OCR dùng để tính bbox) nên không cần letterbox.
      imageWidget = Image.memory(_pdfBytes!, fit: BoxFit.fill);
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.fill,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      );
    }

    // Dựng ảnh + overlay trong ĐÚNG hệ toạ độ pixel gốc của OCR
    // (page.width x page.height, scale 1:1 — bbox không cần quy đổi), rồi để
    // FittedBox co toàn khối xuống vừa khung nhìn bằng MỘT phép biến đổi
    // đồng nhất. Ảnh và bbox cùng chịu một transform nên không thể lệch nhau,
    // kể cả khi viewport ép chiều cao (nguyên nhân lệch dồn trước đây).
    final pageW = widget.page.width > 0 ? widget.page.width.toDouble() : 1000.0;
    final pageH =
        widget.page.height > 0 ? widget.page.height.toDouble() : 1400.0;

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: pageW,
        height: pageH,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            OcrBboxOverlay(
              page: widget.page,
              displaySize: Size(pageW, pageH),
              selection: widget.selection,
              onLineTap: widget.onLineTap,
              onImageTap: widget.onImageTap,
              onTableTap: widget.onTableTap,
            ),
            if (_addMode)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _onDrawStart,
                onPanUpdate: _onDrawUpdate,
                onPanEnd: _onDrawEnd,
                child: CustomPaint(
                  painter: _DrawRectPainter(rect: _drawRect),
                  size: Size(pageW, pageH),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageControls(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: widget.canPrev ? widget.onPrevPage : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            'Trang ${widget.page.page}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          IconButton(
            onPressed: widget.canNext ? widget.onNextPage : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// Vẽ khung xem trước khi người dùng đang kéo để tạo dòng text thủ công.
class _DrawRectPainter extends CustomPainter {
  final Rect? rect;

  const _DrawRectPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final r = rect;
    if (r == null) return;
    final fillPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawRect(r, fillPaint);
    final borderPaint = Paint()
      ..color = Colors.amber.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width / 250;
    canvas.drawRect(r, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _DrawRectPainter oldDelegate) =>
      oldDelegate.rect != rect;
}
