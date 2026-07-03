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
  final ValueChanged<OcrTextStyleModel> onLineStyleChanged;
  final ValueChanged<OcrTextPreset> onLinePresetChanged;
  final ValueChanged<String> onTableHtmlChanged;
  final ValueChanged<String> onImageReplaced;
  final VoidCallback? onDeleteLine;
  final VoidCallback? onAddLine;
  final VoidCallback? onNextMissingLine;
  final VoidCallback? onPrevMissingLine;
  final VoidCallback? onMoveLineUp;
  final VoidCallback? onMoveLineDown;
  final VoidCallback? onDeleteImage;
  final VoidCallback? onDeleteTable;

  const OcrEditorPanel({
    super.key,
    required this.page,
    this.selection,
    required this.onLineTextChanged,
    required this.onLineStyleChanged,
    required this.onLinePresetChanged,
    required this.onTableHtmlChanged,
    required this.onImageReplaced,
    this.onDeleteLine,
    this.onAddLine,
    this.onNextMissingLine,
    this.onPrevMissingLine,
    this.onMoveLineUp,
    this.onMoveLineDown,
    this.onDeleteImage,
    this.onDeleteTable,
  });

  @override
  State<OcrEditorPanel> createState() => _OcrEditorPanelState();
}

class _OcrEditorPanelState extends State<OcrEditorPanel> {
  late final TextEditingController _textController;
  late final TextEditingController _tableController;
  final _imagePicker = ImagePicker();

  // Trạng thái toolbar định dạng
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  OcrTextStyleModel _lineStyle = const OcrTextStyleModel();

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
      setState(() {
        _isBold = false;
        _isItalic = false;
        _isUnderline = false;
        _lineStyle = const OcrTextStyleModel();
      });
      return;
    }
    switch (sel.kind) {
      case OcrEditorSelectionKind.line:
        if (sel.index < widget.page.lines.length) {
          final line = widget.page.lines[sel.index];
          final text = line.text;
          _textController.text = text;
          final style = line.style ?? const OcrTextStyleModel();
          setState(() {
            _lineStyle = style;
            _isBold = style.bold;
            _isItalic = style.italic;
            _isUnderline = style.underline;
          });
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
    return Column(
      children: [
        _buildFormatToolbar(colorScheme),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header('Dòng văn bản', Icons.text_fields, colorScheme),
              const SizedBox(height: 8),
              _buildPresetChips(colorScheme),
              const SizedBox(height: 12),
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
              if (widget.onPrevMissingLine != null || widget.onNextMissingLine != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.onPrevMissingLine != null)
                      OutlinedButton.icon(
                        onPressed: widget.onPrevMissingLine,
                        icon: const Icon(Icons.keyboard_arrow_up),
                        label: const Text('Dòng thiếu trước'),
                      ),
                    if (widget.onNextMissingLine != null)
                      OutlinedButton.icon(
                        onPressed: widget.onNextMissingLine,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        label: const Text('Dòng thiếu kế'),
                      ),
                  ],
                ),
              if (widget.onPrevMissingLine != null || widget.onNextMissingLine != null)
                const SizedBox(height: 16),
              if (widget.onMoveLineUp != null || widget.onMoveLineDown != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.onMoveLineUp != null)
                      OutlinedButton.icon(
                        onPressed: widget.onMoveLineUp,
                        icon: const Icon(Icons.arrow_upward),
                        label: const Text('Đưa lên'),
                      ),
                    if (widget.onMoveLineDown != null)
                      OutlinedButton.icon(
                        onPressed: widget.onMoveLineDown,
                        icon: const Icon(Icons.arrow_downward),
                        label: const Text('Đưa xuống'),
                      ),
                  ],
                ),
              if (widget.onMoveLineUp != null || widget.onMoveLineDown != null)
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
          ),
        ),
      ],
    );
  }

  // ─── Format toolbar ────────────────────────────────────────────────────────

  Widget _buildFormatToolbar(ColorScheme cs) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant),
          top: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          _toolbarBtn(
            icon: Icons.format_bold,
            tooltip: 'Đậm',
            selected: _isBold,
            onTap: () => _toggleStyle(bold: !_isBold),
          ),
          _toolbarBtn(
            icon: Icons.format_italic,
            tooltip: 'Nghiêng',
            selected: _isItalic,
            onTap: () => _toggleStyle(italic: !_isItalic),
          ),
          _toolbarBtn(
            icon: Icons.format_underlined,
            tooltip: 'Gạch chân',
            selected: _isUnderline,
            onTap: () => _toggleStyle(underline: !_isUnderline),
          ),
          Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 4), color: cs.outlineVariant),
          _toolbarBtn(
            icon: Icons.format_clear,
            tooltip: 'Xóa định dạng',
            selected: false,
            onTap: _clearFormatting,
          ),
          Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 4), color: cs.outlineVariant),
          _toolbarBtn(
            icon: Icons.text_fields_rounded,
            tooltip: 'VIẾT HOA',
            selected: false,
            onTap: () => _applyCase(true),
          ),
          _toolbarBtn(
            icon: Icons.text_format_rounded,
            tooltip: 'viết thường',
            selected: false,
            onTap: () => _applyCase(false),
          ),
          const Spacer(),
          if (_lineStyle.fontSize != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '${_lineStyle.fontSize!.toStringAsFixed(0)}pt',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: 'Định dạng đang lưu vào style model',
              child: Text(
                'STYLE',
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChips(ColorScheme cs) {
    final presets = <(String, OcrTextPreset)>[
      ('Body', OcrTextPreset.body),
      ('H1', OcrTextPreset.h1),
      ('H2', OcrTextPreset.h2),
      ('H3', OcrTextPreset.h3),
      ('Caption', OcrTextPreset.caption),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets
          .map(
            (entry) => ChoiceChip(
              label: Text(entry.$1),
              selected: _lineStyle.preset == entry.$2,
              onSelected: (_) {
                widget.onLinePresetChanged(entry.$2);
                // UI sẽ sync lại từ state mới ở frame kế tiếp.
              },
            ),
          )
          .toList(),
    );
  }

  Widget _toolbarBtn({
    required IconData icon,
    required String tooltip,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 36,
          height: 36,
          decoration: selected
              ? BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Icon(icon, size: 18,
              color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant),
        ),
      ),
    );
  }

  // ─── Format actions ────────────────────────────────────────────────────────

  void _toggleStyle({bool? bold, bool? italic, bool? underline}) {
    final next = _lineStyle.copyWith(
      bold: bold,
      italic: italic,
      underline: underline,
    );
    widget.onLineStyleChanged(next);
    setState(() {
      _lineStyle = next;
      _isBold = next.bold;
      _isItalic = next.italic;
      _isUnderline = next.underline;
    });
  }

  void _clearFormatting() {
    final next = const OcrTextStyleModel();
    widget.onLineStyleChanged(next);
    setState(() {
      _lineStyle = next;
      _isBold = false;
      _isItalic = false;
      _isUnderline = false;
    });
  }

  void _applyCase(bool toUpper) {
    final newText = toUpper
        ? _textController.text.toUpperCase()
        : _textController.text.toLowerCase();
    _textController.text = newText;
    widget.onLineTextChanged(newText);
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
        const SizedBox(height: 8),
        if (widget.onDeleteImage != null)
          OutlinedButton.icon(
            onPressed: widget.onDeleteImage,
            icon: Icon(Icons.delete_outline, color: colorScheme.error),
            label: Text(
              'Xóa ảnh',
              style: TextStyle(color: colorScheme.error),
            ),
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
        const SizedBox(height: 8),
        if (widget.onDeleteTable != null)
          OutlinedButton.icon(
            onPressed: widget.onDeleteTable,
            icon: Icon(Icons.delete_outline, color: colorScheme.error),
            label: Text(
              'Xóa bảng',
              style: TextStyle(color: colorScheme.error),
            ),
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
