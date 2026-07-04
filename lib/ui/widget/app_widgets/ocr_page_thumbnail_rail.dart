import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/services/ocr_page_render_service.dart';
import 'package:readbox/ui/widget/base_network_image.dart';

/// Dải thumbnail các trang tài liệu — cột hẹp, cuộn dọc, cố định bên trái
/// màn editor. Chạm vào 1 thumbnail để nhảy tới trang đó ở khu vực thao tác.
class OcrPageThumbnailRail extends StatefulWidget {
  final OcrJobModel job;
  final List<OcrPageModel> pages;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const OcrPageThumbnailRail({
    super.key,
    required this.job,
    required this.pages,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  State<OcrPageThumbnailRail> createState() => _OcrPageThumbnailRailState();
}

class _OcrPageThumbnailRailState extends State<OcrPageThumbnailRail> {
  static const double _baseRailWidth = 104;
  static const double _minZoom = 0.7;
  static const double _maxZoom = 2.2;

  final _renderService = OcrPageRenderService();
  final _scrollController = ScrollController();
  final Map<int, Future<Uint8List?>> _thumbFutures = {};

  double _zoom = 1.0;

  double get _railWidth => _baseRailWidth * _zoom;

  @override
  void didUpdateWidget(covariant OcrPageThumbnailRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _scrollToCurrent();
    }
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    final itemExtent = _railWidth * 1.35 + 24;
    final target = widget.currentIndex * itemExtent;
    _scrollController.animateTo(
      target.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _setZoom(double value) {
    setState(() => _zoom = value.clamp(_minZoom, _maxZoom));
  }

  Future<Uint8List?> _thumbFuture(String url, int pageNumber) {
    return _thumbFutures.putIfAbsent(pageNumber, () async {
      final local = await _renderService.ensureLocalFile(url);
      if (local == null) return null;
      return _renderService.renderPdfPage(
        localPath: local,
        pageNumber: pageNumber,
        targetWidth: 220,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: _railWidth + 20,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              // Pinch để thu phóng thumbnail (bên cạnh 2 nút +/-).
              onScaleUpdate: (details) => _setZoom(_zoom * details.scale),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(4),
                itemCount: widget.pages.length,
                itemBuilder: (context, index) =>
                    _buildItem(context, colorScheme, index),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, ColorScheme colorScheme, int index) {
    final page = widget.pages[index];
    final selected = index == widget.currentIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => widget.onSelect(index),
        child: Column(
          children: [
            SizedBox(
              width: _railWidth,
              child: AspectRatio(
                aspectRatio: page.width > 0 && page.height > 0
                    ? page.width / page.height
                    : 0.72,
                child: Container(
                  decoration: BoxDecoration(
                    // borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected
                          ? colorScheme.primary.withValues(alpha: 0.5)
                          : colorScheme.outline.withValues(alpha: 0.3),
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: colorScheme.primary.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildThumb(page, colorScheme),
                ),
              ),
            ),
            Text(
              '${page.page}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumb(OcrPageModel page, ColorScheme colorScheme) {
    // Ưu tiên ảnh trang do worker upload sẵn (khớp chính xác bbox) — nhẹ
    // hơn nhiều so với tự tải + render lại cả file PDF gốc chỉ để lấy thumb.
    final pageImageUrl = page.pageImageUrl;
    if (pageImageUrl != null && pageImageUrl.isNotEmpty) {
      return BaseNetworkImage(
        url: pageImageUrl,
        fit: BoxFit.cover,
      );
    }

    final url = widget.job.fileUrl;
    if (url == null) {
      return ColoredBox(color: colorScheme.surfaceContainerLow);
    }
    if (!_renderService.isPdf(widget.job.mimeType, url)) {
      return BaseNetworkImage(
        url: url,
        fit: BoxFit.cover,
      );
    }
    return FutureBuilder<Uint8List?>(
      future: _thumbFuture(url, page.page),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ColoredBox(color: colorScheme.surfaceContainerLow);
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return ColoredBox(color: colorScheme.surfaceContainerLow);
        }
        return Image.memory(bytes, fit: BoxFit.cover);
      },
    );
  }
}
