import 'package:flutter/material.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/res/dimens.dart';

/// Card hiển thị một job OCR gần đây trong HomeScreen — horizontal list.
class RecentJobCard extends StatelessWidget {
  final OcrJobModel job;
  final VoidCallback onTap;

  const RecentJobCard({super.key, required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statusColor = _statusColor(job.status, cs);
    final statusLabel = _statusLabel(job.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(AppDimens.SIZE_12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppDimens.SIZE_12),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(AppDimens.SIZE_8),
              ),
              child: Icon(
                Icons.description_outlined,
                color: cs.onPrimaryContainer,
                size: AppDimens.SIZE_20,
              ),
            ),
            const SizedBox(height: AppDimens.SIZE_8),
            Text(
              job.originalName ?? 'Tài liệu',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: AppDimens.SIZE_6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (job.status == OcrJobStatus.processing &&
                job.totalPages != null &&
                job.totalPages! > 0) ...[
              const SizedBox(height: AppDimens.SIZE_6),
              LinearProgressIndicator(
                value: job.processedPages / job.totalPages!,
                backgroundColor: cs.surfaceContainerHighest,
                color: cs.primary,
                borderRadius: BorderRadius.circular(4),
                minHeight: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(OcrJobStatus status, ColorScheme cs) {
    switch (status) {
      case OcrJobStatus.done:
        return Colors.green.shade600;
      case OcrJobStatus.processing:
        return cs.primary;
      case OcrJobStatus.failed:
        return Colors.red.shade600;
      case OcrJobStatus.queued:
        return Colors.orange.shade600;
    }
  }

  String _statusLabel(OcrJobStatus status) {
    switch (status) {
      case OcrJobStatus.done:
        return 'Hoàn tất';
      case OcrJobStatus.processing:
        return 'Đang xử lý';
      case OcrJobStatus.failed:
        return 'Thất bại';
      case OcrJobStatus.queued:
        return 'Đang chờ';
    }
  }
}
