import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:readbox/blocs/ocr/ocr_editor_state.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/res/app_size.dart';

/// Panel chỉnh sửa text / ảnh / bảng cho vùng bbox đã chọn.
class OcrEditorPanel extends StatefulWidget {
  final OcrPageModel page;
  final OcrEditorSelection? selection;
  final ValueChanged<String> onLineTextChanged;
  final ValueChanged<String> onTableHtmlChanged;
  final ValueChanged<String> onImageReplaced;
  final VoidCallback? onDeleteLine;
  final VoidCallback? onAddLine;

  const OcrEditorPanel({
    super.key,
    required this.page,
    this.selection,
    required this.onLineTextChanged,
    required this.onTableHtmlChanged,
    required this.onImageReplaced,
    this.onDeleteLine,
    this.onAddLine,
  });

  @override
  State<OcrEditorPanel> createState() => _OcrEditorPanelState();
}

class _OcrEditorPanelState extends State<OcrEditorPanel> {
  late final TextEditingController _textController;
  late final TextEditingController _tableController;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _tableController = TextEditingController();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant OcrEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection ||
        oldWidget.page.page != widget.page.page) {
      _syncControllers();
    }
  }

  void _syncControllers() {
    final sel = widget.selection;
    if (sel == null) {
      _textController.clear();
      _tableController.clear();
      return;
    }
    switch (sel.kind) {
      case OcrEditorSelectionKind.line:
        if (sel.index < widget.page.lines.length) {
          _textController.text = widget.page.lines[sel.index].text;
        }
        break;
      case OcrEditorSelectionKind.table:
        if (sel.index < widget.page.tables.length) {
          _tableController.text =
              widget.page.tables[sel.index].tableHtml ?? '';
        }
        break;
      case OcrEditorSelectionKind.image:
        break;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _tableController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      widget.onImageReplaced(file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sel = widget.selection;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15)),
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15)),
        ),
      ),
      child: sel == null
          ? _buildEmpty(colorScheme)
          : _buildEditor(context, colorScheme, sel),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, size: 48, color: colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'Chạm vào vùng bbox trên preview để chỉnh sửa text hoặc hình ảnh.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            if (widget.onAddLine != null) ...[
              const SizedBox(height: 16),
              Text(
                'OCR bỏ sót một đoạn text? Thêm dòng thủ công để nhập.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppSize.fontSizeSmall,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onAddLine,
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Thêm dòng text mới'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(
    BuildContext context,
    ColorScheme colorScheme,
    OcrEditorSelection sel,
  ) {
    switch (sel.kind) {
      case OcrEditorSelectionKind.line:
        return _buildLineEditor(colorScheme, sel.index);
      case OcrEditorSelectionKind.image:
        return _buildImageEditor(colorScheme, sel.index);
      case OcrEditorSelectionKind.table:
        return _buildTableEditor(colorScheme, sel.index);
    }
  }

  Widget _buildLineEditor(ColorScheme colorScheme, int index) {
    final line = widget.page.lines[index];
    final needsInput = line.text.trim().isEmpty;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header('Dòng văn bản', Icons.text_fields, colorScheme),
        const SizedBox(height: 8),
        if (needsInput)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade700, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.edit_note, size: 18, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chưa có nội dung — OCR không nhận dạng được, hãy nhập tay bên dưới.',
                    style: TextStyle(
                      fontSize: AppSize.fontSizeSmall,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            'Độ tin cậy: ${(line.confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: AppSize.fontSizeSmall,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          key: ValueKey('line-text-$index'),
          controller: _textController,
          maxLines: 8,
          autofocus: needsInput,
          decoration: const InputDecoration(
            labelText: 'Nội dung',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: (v) => widget.onLineTextChanged(v),
        ),
        const SizedBox(height: 16),
        if (widget.onDeleteLine != null)
          OutlinedButton.icon(
            onPressed: widget.onDeleteLine,
            icon: Icon(Icons.delete_outline, color: colorScheme.error),
            label: Text(
              'Xóa dòng',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildImageEditor(ColorScheme colorScheme, int index) {
    final asset = widget.page.images[index];
    final preview = asset.localImagePath != null
        ? Image.file(File(asset.localImagePath!), fit: BoxFit.contain)
        : (asset.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: asset.imageUrl!,
                fit: BoxFit.contain,
              )
            : const Icon(Icons.image_not_supported));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header(
          asset.type == 'figure' ? 'Hình minh họa' : 'Ảnh nhúng',
          Icons.image,
          colorScheme,
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 180,
            width: double.infinity,
            color: colorScheme.surfaceContainerHighest,
            child: preview,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Đổi ảnh'),
        ),
      ],
    );
  }

  Widget _buildTableEditor(ColorScheme colorScheme, int index) {
    final asset = widget.page.tables[index];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header('Bảng', Icons.table_chart, colorScheme),
        const SizedBox(height: 12),
        if (asset.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: asset.imageUrl!,
              height: 120,
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _tableController,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: 'HTML bảng',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: widget.onTableHtmlChanged,
        ),
      ],
    );
  }

  Widget _header(String title, IconData icon, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: AppSize.fontSizeLarge,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
