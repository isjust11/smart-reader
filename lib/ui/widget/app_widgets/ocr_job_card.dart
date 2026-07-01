import 'package:flutter/material.dart';
import 'package:readbox/domain/data/models/ocr_job_model.dart';
import 'package:readbox/res/app_size.dart';
import 'package:readbox/ui/widget/app_widgets/ocr_status_badge.dart';
import 'package:readbox/utils/common.dart';

/// Thẻ hiển thị một job OCR trong danh sách: tên file, trạng thái, tiến độ.
class OcrJobCard extends StatelessWidget {
  final OcrJobModel job;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  const OcrJobCard({super.key, required this.job, this.onTap, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isProcessing = job.status == OcrJobStatus.processing;
    final isFailed = job.status == OcrJobStatus.failed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _fileIcon(job.mimeType),
                      color: colorScheme.primary,
                      size: AppSize.iconSizeXXLarge,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.displayName,
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
                            _subtitle(),
                            style: TextStyle(
                              fontSize: AppSize.fontSizeSmall,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OcrStatusBadge(status: job.status),
                  ],
                ),
                if (isProcessing) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: job.progress > 0 ? job.progress : null,
                      minHeight: 6,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _progressLabel(),
                    style: TextStyle(
                      fontSize: AppSize.fontSizeSmall,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (isFailed) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          job.error ?? 'Xử lý OCR thất bại.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppSize.fontSizeSmall,
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                      if (onRetry != null)
                        TextButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Thử lại'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            foregroundColor: colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    parts.add('Ngôn ngữ: ${_langLabel(job.lang)}');
    if (job.fileSize > 0) {
      parts.add(Common.formatFileSize(job.fileSize));
    }
    if (job.createdAt != null) {
      parts.add(Common.formatDate(job.createdAt, format: 'dd/MM/yyyy HH:mm'));
    }
    return parts.join(' • ');
  }

  String _progressLabel() {
    final total = job.totalPages;
    if (total == null || total <= 0) {
      return 'Đang xử lý...';
    }
    return 'Trang ${job.processedPages}/$total';
  }

  String _langLabel(String lang) {
    switch (lang) {
      case 'vi':
        return 'Tiếng Việt';
      case 'en':
        return 'Tiếng Anh';
      default:
        return 'Tự động';
    }
  }

  IconData _fileIcon(String? mimeType) {
    if (mimeType == null) return Icons.description;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.startsWith('image/')) return Icons.image;
    return Icons.description;
  }
}
