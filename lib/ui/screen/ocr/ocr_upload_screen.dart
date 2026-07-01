import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readbox/blocs/base_bloc/base_state.dart';
import 'package:readbox/blocs/ocr/ocr.dart';
import 'package:readbox/injection_container.dart';
import 'package:readbox/res/app_size.dart';
import 'package:readbox/ui/screen/ocr/ocr_job_list_screen.dart';
import 'package:readbox/ui/widget/widget.dart';
import 'package:readbox/utils/common.dart';

/// Màn hình upload tài liệu để tạo job OCR (chọn PDF/ảnh, ngôn ngữ, tách ảnh).
class OcrUploadScreen extends StatelessWidget {
  const OcrUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OcrUploadCubit>(),
      child: const _OcrUploadBody(),
    );
  }
}

class _OcrUploadBody extends StatelessWidget {
  const _OcrUploadBody();

  static const _allowedExtensions = [
    'pdf',
    'png',
    'jpg',
    'jpeg',
    'webp',
    'tif',
    'tiff',
  ];

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
    );
    final path = result?.files.single.path;
    if (path != null && context.mounted) {
      context.read<OcrUploadCubit>().selectFile(File(path));
    }
  }

  Future<void> _createJob(BuildContext context) async {
    final cubit = context.read<OcrUploadCubit>();
    final job = await cubit.createJob();
    if (job != null && context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OcrJobListScreen(newlyCreatedJob: job),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocBuilder<OcrUploadCubit, BaseState>(
      builder: (context, state) {
        final cubit = context.read<OcrUploadCubit>();
        final selectedFile = cubit.selectedFile;
        final isUploading = state is LoadingState;

        return BaseScreen<OcrUploadCubit>(
          colorBg: colorScheme.surface,
          title: 'Nhận dạng văn bản (OCR)',
          showGlobalFloatingActions: false,
          rightWidgets: [
            IconButton(
              tooltip: 'Danh sách công việc',
              icon: const Icon(Icons.list_alt),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OcrJobListScreen(),
                  ),
                );
              },
            ),
          ],
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(colorScheme),
                const SizedBox(height: 16),
                _buildLangSelector(context, cubit, colorScheme, isUploading),
                const SizedBox(height: 12),
                _buildExtractSwitch(context, cubit, colorScheme, isUploading),
                const SizedBox(height: 16),
                _buildPickButton(context, colorScheme, isUploading),
                if (selectedFile != null) ...[
                  const SizedBox(height: 16),
                  _buildSelectedFile(selectedFile, colorScheme),
                  const SizedBox(height: 16),
                  if (isUploading)
                    _buildUploadingProgress(context, cubit, colorScheme)
                  else
                    ElevatedButton.icon(
                      onPressed: () => _createJob(context),
                      icon: const Icon(Icons.document_scanner),
                      label: const Text('Bắt đầu OCR'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.document_scanner, size: 44, color: colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            'Trích xuất văn bản từ PDF & ảnh',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppSize.fontSizeXLarge,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn tài liệu, hệ thống sẽ xử lý và trả kết quả (văn bản + vị trí) '
            'trong nền. Bạn có thể theo dõi tiến độ ở danh sách công việc.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppSize.fontSizeMedium,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangSelector(
    BuildContext context,
    OcrUploadCubit cubit,
    ColorScheme colorScheme,
    bool disabled,
  ) {
    const options = {
      'auto': 'Tự động',
      'vi': 'Tiếng Việt',
      'en': 'Tiếng Anh',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ngôn ngữ',
          style: TextStyle(
            fontSize: AppSize.fontSizeMedium,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.entries.map((entry) {
            final selected = cubit.lang == entry.key;
            return ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              onSelected:
                  disabled ? null : (_) => cubit.setLang(entry.key),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExtractSwitch(
    BuildContext context,
    OcrUploadCubit cubit,
    ColorScheme colorScheme,
    bool disabled,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Tách hình ảnh / bảng'),
        subtitle: Text(
          'Trích xuất riêng figure, bảng và ảnh nhúng trong tài liệu.',
          style: TextStyle(
            fontSize: AppSize.fontSizeSmall,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        value: cubit.extractImages,
        onChanged: disabled ? null : cubit.setExtractImages,
      ),
    );
  }

  Widget _buildPickButton(
    BuildContext context,
    ColorScheme colorScheme,
    bool disabled,
  ) {
    return OutlinedButton.icon(
      onPressed: disabled ? null : () => _pickFile(context),
      icon: const Icon(Icons.upload_file),
      label: const Text('Chọn tài liệu (PDF / ảnh)'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: colorScheme.primary),
      ),
    );
  }

  Widget _buildSelectedFile(File file, ColorScheme colorScheme) {
    final name = file.path.split(RegExp(r'[/\\]')).last;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppSize.fontSizeLarge,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Common.formatFileSize(file.lengthSync()),
                  style: TextStyle(
                    fontSize: AppSize.fontSizeSmall,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingProgress(
    BuildContext context,
    OcrUploadCubit cubit,
    ColorScheme colorScheme,
  ) {
    final percent = (cubit.uploadProgress * 100).clamp(0, 100).toStringAsFixed(0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: cubit.uploadProgress > 0 ? cubit.uploadProgress : null,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Đang tải lên... $percent%',
              style: TextStyle(
                fontSize: AppSize.fontSizeMedium,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: cubit.cancelUpload,
              child: const Text('Hủy'),
            ),
          ],
        ),
      ],
    );
  }
}
