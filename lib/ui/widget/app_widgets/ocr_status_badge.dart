import 'package:flutter/material.dart';
import 'package:readbox/domain/data/models/ocr_job_model.dart';
import 'package:readbox/res/app_size.dart';

/// Badge hiển thị trạng thái job OCR với màu sắc tương ứng.
class OcrStatusBadge extends StatelessWidget {
  final OcrJobStatus status;

  const OcrStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _configFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.color),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              fontSize: AppSize.fontSizeSmall,
              fontWeight: FontWeight.w600,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _configFor(OcrJobStatus status) {
    switch (status) {
      case OcrJobStatus.queued:
        return const _BadgeConfig('Đang chờ', Icons.schedule, Color(0xFF6C757D));
      case OcrJobStatus.processing:
        return const _BadgeConfig(
          'Đang xử lý',
          Icons.sync,
          Color(0xFF1967D2),
        );
      case OcrJobStatus.done:
        return const _BadgeConfig(
          'Hoàn tất',
          Icons.check_circle,
          Color(0xFF0E631D),
        );
      case OcrJobStatus.failed:
        return const _BadgeConfig(
          'Thất bại',
          Icons.error,
          Color(0xFFE21B14),
        );
    }
  }
}

class _BadgeConfig {
  final String label;
  final IconData icon;
  final Color color;

  const _BadgeConfig(this.label, this.icon, this.color);
}
