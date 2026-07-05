import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:readbox/blocs/base_bloc/base_state.dart';
import 'package:readbox/blocs/ocr/ocr.dart';
import 'package:readbox/gen/i18n/generated_locales/l10n.dart';
import 'package:readbox/injection_container.dart';
import 'package:readbox/res/app_size.dart';
import 'package:readbox/res/dimens.dart';
import 'package:readbox/res/enum.dart';
import 'package:readbox/ui/screen/ocr/ocr_activity_screen.dart';
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

class _OcrUploadBody extends StatefulWidget {
  const _OcrUploadBody();

  @override
  State<_OcrUploadBody> createState() => _OcrUploadBodyState();
}

class _OcrUploadBodyState extends State<_OcrUploadBody> {
  static const _allowedExtensions = [
    'pdf',
    'png',
    'jpg',
    'jpeg',
    'webp',
    'tif',
    'tiff',
  ];
  final _imagePicker = ImagePicker();

  Future<void> _captureFromCamera() async {
    final l = AppLocalizations.current;
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: l.ocr_camera_permission,
          snackBarType: SnackBarType.error,
        );
      }
      return;
    }
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked != null && mounted) {
      context.read<OcrUploadCubit>().addImagePages([File(picked.path)]);
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await _imagePicker.pickMultiImage(imageQuality: 90);
    if (picked.isNotEmpty && mounted) {
      context
          .read<OcrUploadCubit>()
          .addImagePages(picked.map((e) => File(e.path)).toList());
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      allowMultiple: true,
    );
    final paths = result?.files
            .map((f) => f.path)
            .whereType<String>()
            .where((p) => p.isNotEmpty)
            .toList() ??
        [];
    if (paths.isEmpty || !mounted) return;

    final cubit = context.read<OcrUploadCubit>();
    final imagePaths = paths.where(_isImagePath).toList();
    final pdfPaths = paths.where((p) => !_isImagePath(p)).toList();

    if (pdfPaths.length > 1) {
      AppSnackBar.show(
        context,
        message: 'Chỉ chọn một file PDF mỗi lần.',
        snackBarType: SnackBarType.warning,
      );
      return;
    }

    if (pdfPaths.length == 1) {
      cubit.selectDocument(File(pdfPaths.first));
      return;
    }

    cubit.addImagePages(imagePaths.map(File.new).toList());
  }

  bool _isImagePath(String path) {
    return RegExp(
      r'\.(png|jpg|jpeg|webp|tif|tiff)$',
      caseSensitive: false,
    ).hasMatch(path);
  }

  Future<void> _createJob() async {
    final cubit = context.read<OcrUploadCubit>();
    final job = await cubit.createJob();
    if (job != null && mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, job);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OcrJobListScreen(newlyCreatedJob: job),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l = AppLocalizations.current;

    return BlocBuilder<OcrUploadCubit, BaseState>(
      builder: (context, state) {
        final cubit = context.read<OcrUploadCubit>();
        final selection = cubit.selection;
        final hasSelection = cubit.hasSelection;
        final isUploading = state is LoadingState;

        return BaseScreen<OcrUploadCubit>(
          colorBg: colorScheme.surfaceContainerLowest,
          title: 'Quét tài liệu OCR',
          showGlobalFloatingActions: false,
          rightWidgets: [
            IconButton(
              tooltip: 'Đang xử lý',
              icon: const Icon(Icons.pending_actions_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OcrActivityScreen(),
                  ),
                );
              },
            ),
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
            padding: const EdgeInsets.fromLTRB(
              AppDimens.SIZE_16,
              AppDimens.SIZE_12,
              AppDimens.SIZE_16,
              AppDimens.SIZE_24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!hasSelection) ...[
                  _buildCameraButton(colorScheme, isUploading),
                  const SizedBox(height: AppDimens.SIZE_16),
                  _buildDivider(colorScheme),
                  const SizedBox(height: AppDimens.SIZE_16),
                  _buildSecondaryActions(colorScheme, isUploading),
                ] else if (selection.hasDocument) ...[
                  _buildSelectedDocument(
                    selection.documentFile!,
                    colorScheme,
                    isUploading,
                    cubit,
                  ),
                ] else ...[
                  _buildImagePagesList(
                    cubit.imagePages,
                    colorScheme,
                    isUploading,
                    cubit,
                    l,
                  ),
                ],
                const SizedBox(height: AppDimens.SIZE_20),
                _buildSettingsCard(context, cubit, colorScheme, isUploading),
                const SizedBox(height: AppDimens.SIZE_20),
                if (hasSelection)
                  isUploading
                      ? _buildUploadProgress(cubit, colorScheme)
                      : FilledButton.icon(
                          onPressed: _createJob,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Bắt đầu OCR'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppDimens.SIZE_14,
                            ),
                          ),
                        ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraButton(ColorScheme cs, bool disabled) {
    return GestureDetector(
      onTap: disabled ? null : _captureFromCamera,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.tertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppDimens.SIZE_20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimens.SIZE_16),
              decoration: BoxDecoration(
                color: cs.onPrimary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: AppDimens.SIZE_44,
                color: cs.onPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.SIZE_12),
            Text(
              'Chụp ảnh tài liệu',
              style: TextStyle(
                fontSize: AppSize.fontSizeXLarge,
                fontWeight: FontWeight.bold,
                color: cs.onPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Chụp nhiều trang, sắp xếp lại trước khi OCR',
              style: TextStyle(
                fontSize: AppSize.fontSizeSmall,
                color: cs.onPrimary.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme cs) {
    return Row(
      children: [
        Expanded(child: Divider(color: cs.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.SIZE_12),
          child: Text(
            'hoặc',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ),
        Expanded(child: Divider(color: cs.outlineVariant)),
      ],
    );
  }

  Widget _buildSecondaryActions(ColorScheme cs, bool disabled) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Thư viện'),
          ),
        ),
        const SizedBox(width: AppDimens.SIZE_12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : _pickDocument,
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('PDF / File'),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDocument(
    File file,
    ColorScheme cs,
    bool isUploading,
    OcrUploadCubit cubit,
  ) {
    final name = file.path.split(RegExp(r'[/\\]')).last;
    final isImage = _isImagePath(name);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.SIZE_16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimens.SIZE_16),
              ),
              child: Image.file(
                file,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.SIZE_14),
            child: Row(
              children: [
                Icon(
                  isImage ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
                  color: cs.primary,
                  size: AppDimens.SIZE_28,
                ),
                const SizedBox(width: AppDimens.SIZE_10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        Common.formatFileSize(file.lengthSync()),
                        style: TextStyle(
                          fontSize: AppSize.fontSizeSmall,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isUploading)
                  IconButton(
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    onPressed: cubit.clearSelection,
                    tooltip: 'Chọn lại',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePagesList(
    List<File> pages,
    ColorScheme cs,
    bool isUploading,
    OcrUploadCubit cubit,
    AppLocalizations l,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.SIZE_16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
            child: Row(
              children: [
                Icon(Icons.collections_bookmark_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.ocr_upload_pages_count(pages.length),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        l.ocr_upload_reorder_hint,
                        style: TextStyle(
                          fontSize: AppSize.fontSizeSmall,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isUploading)
                  TextButton(
                    onPressed: cubit.clearSelection,
                    child: Text(l.ocr_clear_all),
                  ),
              ],
            ),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: pages.length,
            onReorder: cubit.reorderImagePages,
            itemBuilder: (context, index) {
              final file = pages[index];
              return _buildPageTile(
                key: ValueKey(file.path),
                index: index,
                file: file,
                cs: cs,
                isUploading: isUploading,
                onRemove: () => cubit.removeImagePage(index),
              );
            },
          ),
          if (!isUploading)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _captureFromCamera,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: Text(l.ocr_add_page),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Thư viện'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageTile({
    required Key key,
    required int index,
    required File file,
    required ColorScheme cs,
    required bool isUploading,
    required VoidCallback onRemove,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            if (!isUploading)
              ReorderableDragStartListener(
                index: index,
                child: Icon(Icons.drag_handle, color: cs.onSurfaceVariant),
              )
            else
              Icon(Icons.drag_handle, color: cs.outlineVariant),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                width: 52,
                height: 68,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppLocalizations.current.pages} ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    file.path.split(RegExp(r'[/\\]')).last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppSize.fontSizeSmall,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!isUploading)
              IconButton(
                icon: Icon(Icons.close, color: cs.onSurfaceVariant, size: 20),
                onPressed: onRemove,
                tooltip: 'Xóa trang',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context,
    OcrUploadCubit cubit,
    ColorScheme cs,
    bool disabled,
  ) {
    const langOptions = {
      'auto': 'Tự động',
      'vi': 'Tiếng Việt',
      'en': 'Tiếng Anh',
    };

    return Container(
      padding: const EdgeInsets.all(AppDimens.SIZE_16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppDimens.SIZE_16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cài đặt nhận dạng',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: AppDimens.SIZE_12),
          Text(
            'Ngôn ngữ',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppDimens.SIZE_6),
          Wrap(
            spacing: AppDimens.SIZE_8,
            children: langOptions.entries.map((e) {
              return ChoiceChip(
                label: Text(e.value),
                selected: cubit.lang == e.key,
                onSelected: disabled ? null : (_) => cubit.setLang(e.key),
              );
            }).toList(),
          ),
          const Divider(height: AppDimens.SIZE_20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Tách hình ảnh & bảng'),
            subtitle: Text(
              'Trích xuất riêng figure, bảng và ảnh nhúng.',
              style: TextStyle(
                fontSize: AppSize.fontSizeSmall,
                color: cs.onSurfaceVariant,
              ),
            ),
            value: cubit.extractImages,
            onChanged: disabled ? null : cubit.setExtractImages,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadProgress(OcrUploadCubit cubit, ColorScheme cs) {
    final percent =
        (cubit.uploadProgress * 100).clamp(0, 100).toStringAsFixed(0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: cubit.uploadProgress > 0 ? cubit.uploadProgress : null,
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: AppDimens.SIZE_8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Đang tải lên... $percent%',
              style: TextStyle(
                fontSize: AppSize.fontSizeMedium,
                color: cs.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: cubit.cancelUpload,
              child: const Text('Huỷ'),
            ),
          ],
        ),
      ],
    );
  }
}
