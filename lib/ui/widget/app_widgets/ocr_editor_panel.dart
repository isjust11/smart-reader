import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:readbox/blocs/ocr/ocr_editor_state.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/gen/i18n/generated_locales/l10n.dart';
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
        oldWidget.page.page != widget.page.page ||
        _hasExternalSelectionUpdate(oldWidget)) {
      _syncControllers();
    }
  }

  bool _hasExternalSelectionUpdate(OcrEditorPanel oldWidget) {
    final sel = widget.selection;
    if (sel == null) return false;

    switch (sel.kind) {
      case OcrEditorSelectionKind.line:
        if (sel.index >= widget.page.lines.length ||
            sel.index >= oldWidget.page.lines.length) {
          return true;
        }
        final oldLine = oldWidget.page.lines[sel.index];
        final newLine = widget.page.lines[sel.index];
        return !_styleEquals(oldLine.style, newLine.style) ||
            (oldLine.text != newLine.text &&
                newLine.text != _textController.text);
      case OcrEditorSelectionKind.table:
        if (sel.index >= widget.page.tables.length ||
            sel.index >= oldWidget.page.tables.length) {
          return true;
        }
        final oldHtml = oldWidget.page.tables[sel.index].tableHtml ?? '';
        final newHtml = widget.page.tables[sel.index].tableHtml ?? '';
        return oldHtml != newHtml && newHtml != _tableController.text;
      case OcrEditorSelectionKind.image:
        if (sel.index >= widget.page.images.length ||
            sel.index >= oldWidget.page.images.length) {
          return true;
        }
        final oldAsset = oldWidget.page.images[sel.index];
        final newAsset = widget.page.images[sel.index];
        return oldAsset.localImagePath != newAsset.localImagePath ||
            oldAsset.imageUrl != newAsset.imageUrl;
    }
  }

  bool _styleEquals(OcrTextStyleModel? a, OcrTextStyleModel? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.preset == b.preset &&
        a.fontFamily == b.fontFamily &&
        a.fontSize == b.fontSize &&
        a.colorHex == b.colorHex &&
        a.bold == b.bold &&
        a.italic == b.italic &&
        a.underline == b.underline &&
        a.align == b.align &&
        a.lineHeight == b.lineHeight;
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
          if (_textController.text != text) {
            _textController.text = text;
          }
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
          final html = widget.page.tables[sel.index].tableHtml ?? '';
          if (_tableController.text != html) {
            _tableController.text = html;
          }
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
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15)),
        ),
      ),
      child: sel == null
          ? _buildEmpty(colorScheme)
          : _buildEditor(context, colorScheme, sel),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) {
    final l = AppLocalizations.current;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, size: 40, color: colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              l.ocr_editor_empty_hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: AppSize.fontSizeSmall,
              ),
            ),
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
    final l = AppLocalizations.current;
    final line = widget.page.lines[index];
    final needsInput = line.text.trim().isEmpty;
    return Column(
      children: [
        _buildTextFormatToolbar(colorScheme),
        Expanded(
          child: ListView(
            // padding: const EdgeInsets.all(16),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      _header(l.ocr_line_header, Icons.text_fields, colorScheme),
                      const Spacer(),
                      Text(
                        l.ocr_confidence(
                          (line.confidence * 100).toStringAsFixed(0),
                        ),
                        style: TextStyle(
                          fontSize: AppSize.fontSizeSmall,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (needsInput)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            l.ocr_line_empty_hint,
                            style: TextStyle(
                              fontSize: AppSize.fontSizeSmall,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: TextField(
                  key: ValueKey('line-text-$index'),
                  controller: _textController,
                  maxLines: 8,
                  autofocus: needsInput,
                  style: _editorTextStyle(_lineStyle),
                  decoration: InputDecoration(
                    labelText: l.ocr_content,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  onChanged: (v) => widget.onLineTextChanged(v),
                ),
              ),
              )
            ],
          ),
        ),
      ],
    );
  }

  // ─── Format toolbar ────────────────────────────────────────────────────────

  Widget _buildTextFormatToolbar(ColorScheme cs) {
    final l = AppLocalizations.current;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant),
          top: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            _toolbarBtn(
              icon: Icons.format_bold,
              tooltip: l.ocr_bold,
              selected: _isBold,
              onTap: () => _toggleStyle(bold: !_isBold),
            ),
            _toolbarBtn(
              icon: Icons.format_italic,
              tooltip: l.ocr_italic,
              selected: _isItalic,
              onTap: () => _toggleStyle(italic: !_isItalic),
            ),
            _toolbarBtn(
              icon: Icons.format_underlined,
              tooltip: l.ocr_underline,
              selected: _isUnderline,
              onTap: () => _toggleStyle(underline: !_isUnderline),
            ),
            _vDivider(cs),
            _toolbarBtn(
              icon: Icons.format_align_left,
              tooltip: l.ocr_align_left,
              selected: _lineStyle.align == 'left',
              onTap: () => _setAlign('left'),
            ),
            _toolbarBtn(
              icon: Icons.format_align_center,
              tooltip: l.ocr_align_center,
              selected: _lineStyle.align == 'center',
              onTap: () => _setAlign('center'),
            ),
            _toolbarBtn(
              icon: Icons.format_align_right,
              tooltip: l.ocr_align_right,
              selected: _lineStyle.align == 'right',
              onTap: () => _setAlign('right'),
            ),
            _toolbarBtn(
              icon: Icons.format_align_justify,
              tooltip: l.ocr_align_justify,
              selected: _lineStyle.align == 'justify',
              onTap: () => _setAlign('justify'),
            ),
            _vDivider(cs),
            _toolbarBtn(
              icon: Icons.format_clear,
              tooltip: l.ocr_clear_format,
              selected: false,
              onTap: _clearFormatting,
            ),
            _toolbarBtn(
              icon: Icons.text_fields_rounded,
              tooltip: l.ocr_uppercase,
              selected: false,
              onTap: () => _applyCase(true),
            ),
            _toolbarBtn(
              icon: Icons.text_format_rounded,
              tooltip: l.ocr_lowercase,
              selected: false,
              onTap: () => _applyCase(false),
            ),
            _vDivider(cs),
            _buildPresetDropdown(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildImageToolbar(ColorScheme cs) {
    final l = AppLocalizations.current;
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
            icon: Icons.photo_library_outlined,
            tooltip: l.ocr_change_image,
            selected: false,
            onTap: _pickImage,
          ),
          if (widget.onDeleteImage != null)
            _toolbarBtn(
              icon: Icons.delete_outline,
              tooltip: l.ocr_delete_image,
              selected: false,
              onTap: widget.onDeleteImage!,
              destructive: true,
            ),
        ],
      ),
    );
  }

  Widget _buildTableToolbar(ColorScheme cs) {
    final l = AppLocalizations.current;
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
          if (widget.onDeleteTable != null)
            _toolbarBtn(
              icon: Icons.delete_outline,
              tooltip: l.ocr_delete_table,
              selected: false,
              onTap: widget.onDeleteTable!,
              destructive: true,
            ),
        ],
      ),
    );
  }

  Widget _buildPresetDropdown(ColorScheme cs) {
    final l = AppLocalizations.current;
    final presets = <(String, OcrTextPreset)>[
      (l.ocr_preset_body, OcrTextPreset.body),
      (l.ocr_preset_h1, OcrTextPreset.h1),
      (l.ocr_preset_h2, OcrTextPreset.h2),
      (l.ocr_preset_h3, OcrTextPreset.h3),
      (l.ocr_preset_caption, OcrTextPreset.caption),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<OcrTextPreset>(
          isDense: true,
          value: _lineStyle.preset,
          borderRadius: BorderRadius.circular(8),
          icon: Icon(Icons.arrow_drop_down, color: cs.onSurfaceVariant, size: 20),
          selectedItemBuilder: (context) => presets
              .map(
                (entry) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    entry.$1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              )
              .toList(),
          items: presets
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.$2,
                  child: Text(entry.$1),
                ),
              )
              .toList(),
          onChanged: (preset) {
            if (preset != null) _changePreset(preset);
          },
        ),
      ),
    );
  }

  Widget _vDivider(ColorScheme cs) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: cs.outlineVariant,
    );
  }

  Widget _toolbarBtn({
    required IconData icon,
    required String tooltip,
    required bool selected,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final fg = destructive
        ? cs.error
        : selected
            ? cs.onPrimaryContainer
            : cs.onSurfaceVariant;
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
          child: Icon(icon, size: 18, color: fg),
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

  void _setAlign(String align) {
    final next = _lineStyle.copyWith(align: align);
    widget.onLineStyleChanged(next);
    setState(() => _lineStyle = next);
  }

  void _changePreset(OcrTextPreset preset) {
    widget.onLinePresetChanged(preset);
  }

  TextStyle _editorTextStyle(OcrTextStyleModel style) {
    return TextStyle(
      fontFamily: style.fontFamily,
      fontSize: style.fontSize ?? AppSize.fontSizeMedium,
      fontWeight: style.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
      decoration: style.underline ? TextDecoration.underline : null,
      height: style.lineHeight,
      color: _parseColor(style.colorHex) ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final value = hex.replaceFirst('#', '');
    final normalized = value.length == 6 ? 'FF$value' : value;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  Widget _buildImageEditor(ColorScheme colorScheme, int index) {
    final l = AppLocalizations.current;
    final asset = widget.page.images[index];
    final preview = asset.localImagePath != null
        ? Image.file(File(asset.localImagePath!), fit: BoxFit.contain)
        : (asset.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: asset.imageUrl!,
                fit: BoxFit.contain,
              )
            : const Icon(Icons.image_not_supported));

    return Column(
      children: [
        _buildImageToolbar(colorScheme),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(
                asset.type == 'figure' ? l.ocr_figure : l.ocr_embedded_image,
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableEditor(ColorScheme colorScheme, int index) {
    final l = AppLocalizations.current;
    final asset = widget.page.tables[index];
    return Column(
      children: [
        _buildTableToolbar(colorScheme),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(l.ocr_table, Icons.table_chart, colorScheme),
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
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  labelText: l.ocr_table_html,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                onChanged: widget.onTableHtmlChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(String title, IconData icon, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 14),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: AppSize.fontSizeMedium,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
