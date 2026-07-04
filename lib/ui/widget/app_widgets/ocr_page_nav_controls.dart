import 'package:flutter/material.dart';
import 'package:readbox/gen/i18n/generated_locales/l10n.dart';

/// Thanh điều hướng trang phía dưới preview: trang trước / số trang / trang sau.
class OcrPageNavControls extends StatelessWidget {
  final int pageNumber;
  final bool canPrev;
  final bool canNext;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;

  const OcrPageNavControls({
    super.key,
    required this.pageNumber,
    this.canPrev = false,
    this.canNext = false,
    this.onPrevPage,
    this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: canPrev ? onPrevPage : null,
          icon: const Icon(Icons.chevron_left, size: 14),
        ),
        Text(
          AppLocalizations.of(context).ocr_page_label(pageNumber),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
            fontSize: 12,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: canNext ? onNextPage : null,
          icon: const Icon(Icons.chevron_right, size: 14),
        ),
      ],
    );
  }
}
