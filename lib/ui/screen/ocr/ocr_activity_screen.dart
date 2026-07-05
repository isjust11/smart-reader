import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readbox/blocs/base_bloc/base_state.dart';
import 'package:readbox/blocs/ocr/ocr_activity_cubit.dart';
import 'package:readbox/blocs/ocr/ocr_activity_state.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/gen/i18n/generated_locales/l10n.dart';
import 'package:readbox/injection_container.dart';
import 'package:readbox/res/dimens.dart';
import 'package:readbox/ui/screen/ocr/ocr_editor_screen.dart';
import 'package:readbox/ui/widget/widget.dart';
import 'package:url_launcher/url_launcher.dart';

/// Màn theo dõi ảnh/văn bản đang OCR và file export đang chờ kết quả.
class OcrActivityScreen extends StatelessWidget {
  const OcrActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OcrActivityCubit>()..load(),
      child: const _OcrActivityBody(),
    );
  }
}

class _OcrActivityBody extends StatefulWidget {
  const _OcrActivityBody();

  @override
  State<_OcrActivityBody> createState() => _OcrActivityBodyState();
}

class _OcrActivityBodyState extends State<_OcrActivityBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<OcrActivityCubit>();
      cubit.bindSocket();
      cubit.startPolling();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return BaseScreen<OcrActivityCubit>(
      colorBg: colorScheme.surface,
      title: l10n.ocr_activity_title,
      showGlobalFloatingActions: false,
      body: BlocBuilder<OcrActivityCubit, BaseState>(
        builder: (context, state) {
          if (state is LoadingState) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ErrorState) {
            return _buildError(context, state, colorScheme, l10n);
          }
          final data = state is LoadedState<OcrActivityData>
              ? state.data
              : const OcrActivityData();
          if (data.isEmpty) {
            return _buildEmpty(context, colorScheme, l10n);
          }
          return RefreshIndicator(
            onRefresh: () => context.read<OcrActivityCubit>().refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (data.ocrPending.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.document_scanner_outlined,
                    title: l10n.ocr_activity_section_ocr,
                    count: data.ocrPending.length,
                  ),
                  ...data.ocrPending.map(
                    (job) => OcrActivityCard(
                      job: job,
                      kind: OcrActivityKind.ocrPending,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (data.exportPending.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.picture_as_pdf_outlined,
                    title: l10n.ocr_activity_section_export,
                    count: data.exportPending.length,
                  ),
                  ...data.exportPending.map(
                    (job) => OcrActivityCard(
                      job: job,
                      kind: OcrActivityKind.exportPending,
                      onTap: () => _openEditor(context, job),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (data.exportReady.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.download_done_outlined,
                    title: l10n.ocr_activity_section_ready,
                    count: data.exportReady.length,
                  ),
                  ...data.exportReady.map(
                    (job) => OcrActivityCard(
                      job: job,
                      kind: OcrActivityKind.exportReady,
                      onTap: () => _openEditor(context, job),
                      onOpenPdf: job.pdfUrl != null
                          ? () => _openUrl(job.pdfUrl!)
                          : null,
                      onOpenTxt: job.txtUrl != null
                          ? () => _openUrl(job.txtUrl!)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (data.exportFailed.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.error_outline,
                    title: l10n.ocr_activity_section_export_failed,
                    count: data.exportFailed.length,
                    isError: true,
                  ),
                  ...data.exportFailed.map(
                    (job) => OcrActivityCard(
                      job: job,
                      kind: OcrActivityKind.exportFailed,
                      onTap: () => _openEditor(context, job),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.SIZE_24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_disabled_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.ocr_activity_empty_title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.ocr_activity_empty_subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    ErrorState state,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.SIZE_24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 48, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(state.message ?? l10n.ocr_load_error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.read<OcrActivityCubit>().load(),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.ocr_activity_retry),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, OcrJobModel job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OcrEditorScreen(
          jobId: job.id,
          title: job.displayName,
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final bool isError;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg = isError ? colorScheme.error : colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
