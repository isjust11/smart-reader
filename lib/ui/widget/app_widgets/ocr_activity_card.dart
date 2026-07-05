import 'package:flutter/material.dart';
import 'package:readbox/domain/data/models/ocr_job_model.dart';
import 'package:readbox/gen/i18n/generated_locales/l10n.dart';
import 'package:readbox/res/app_size.dart';
import 'package:readbox/ui/widget/app_widgets/ocr_status_badge.dart';
import 'package:readbox/utils/common.dart';

enum OcrActivityKind {
  ocrPending,
  exportPending,
  exportReady,
  exportFailed,
}

/// Thẻ job trên màn theo dõi OCR / export đang chờ hoặc vừa hoàn tất.
class OcrActivityCard extends StatelessWidget {
  final OcrJobModel job;
  final OcrActivityKind kind;
  final VoidCallback? onTap;
  final VoidCallback? onOpenPdf;
  final VoidCallback? onOpenTxt;

  const OcrActivityCard({
    super.key,
    required this.job,
    required this.kind,
    this.onTap,
    this.onOpenPdf,
    this.onOpenTxt,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                      _leadingIcon(),
                      color: _leadingColor(colorScheme),
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
                            _subtitle(l10n),
                            style: TextStyle(
                              fontSize: AppSize.fontSizeSmall,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTrailingBadge(colorScheme),
                  ],
                ),
                ..._buildBody(context, l10n, colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    switch (kind) {
      case OcrActivityKind.ocrPending:
        if (job.status != OcrJobStatus.processing) return const [];
        return [
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
            _ocrProgressLabel(l10n),
            style: TextStyle(
              fontSize: AppSize.fontSizeSmall,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ];
      case OcrActivityKind.exportPending:
        return [
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.ocr_export_pdf_processing,
                  style: TextStyle(
                    fontSize: AppSize.fontSizeSmall,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ];
      case OcrActivityKind.exportReady:
        return [
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (job.pdfUrl != null && job.pdfUrl!.isNotEmpty)
                FilledButton.tonalIcon(
                  onPressed: onOpenPdf,
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text(l10n.ocr_activity_open_pdf),
                ),
              if (job.txtUrl != null && job.txtUrl!.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: onOpenTxt,
                  icon: const Icon(Icons.text_snippet_outlined, size: 18),
                  label: Text(l10n.ocr_activity_open_txt),
                ),
              if (onTap != null)
                TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l10n.ocr_activity_open_editor),
                ),
            ],
          ),
        ];
      case OcrActivityKind.exportFailed:
        return [
          const SizedBox(height: 10),
          Text(
            job.exportError ?? l10n.ocr_activity_export_failed_hint,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppSize.fontSizeSmall,
              color: colorScheme.error,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(l10n.ocr_activity_open_editor),
              ),
            ),
          ],
        ];
    }
  }

  Widget _buildTrailingBadge(ColorScheme colorScheme) {
    switch (kind) {
      case OcrActivityKind.ocrPending:
        return OcrStatusBadge(status: job.status);
      case OcrActivityKind.exportPending:
        return _chip(colorScheme, Icons.upload_file, 'PDF');
      case OcrActivityKind.exportReady:
        return _chip(colorScheme, Icons.check_circle_outline, 'OK');
      case OcrActivityKind.exportFailed:
        return _chip(colorScheme, Icons.error_outline, '!', isError: true);
    }
  }

  Widget _chip(
    ColorScheme colorScheme,
    IconData icon,
    String label, {
    bool isError = false,
  }) {
    final fg = isError ? colorScheme.error : colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: AppSize.fontSizeSmall,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(AppLocalizations l10n) {
    final parts = <String>[];
    switch (kind) {
      case OcrActivityKind.ocrPending:
        parts.add(l10n.ocr_activity_kind_ocr);
        break;
      case OcrActivityKind.exportPending:
      case OcrActivityKind.exportReady:
      case OcrActivityKind.exportFailed:
        parts.add(l10n.ocr_activity_kind_export);
        break;
    }
    if (job.createdAt != null) {
      parts.add(Common.formatDate(job.createdAt, format: 'dd/MM/yyyy HH:mm'));
    }
    return parts.join(' • ');
  }

  String _ocrProgressLabel(AppLocalizations l10n) {
    final total = job.totalPages;
    if (total == null || total <= 0) {
      return l10n.ocr_activity_processing;
    }
    return l10n.ocr_activity_page_progress(job.processedPages, total);
  }

  IconData _leadingIcon() {
    switch (kind) {
      case OcrActivityKind.ocrPending:
        if (job.mimeType?.startsWith('image/') == true) {
          return Icons.image_outlined;
        }
        return Icons.document_scanner_outlined;
      case OcrActivityKind.exportPending:
      case OcrActivityKind.exportReady:
      case OcrActivityKind.exportFailed:
        return Icons.picture_as_pdf_outlined;
    }
  }

  Color _leadingColor(ColorScheme colorScheme) {
    if (kind == OcrActivityKind.exportFailed) {
      return colorScheme.error;
    }
    return colorScheme.primary;
  }
}
