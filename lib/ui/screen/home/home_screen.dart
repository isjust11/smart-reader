import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readbox/blocs/base_bloc/base_state.dart';
import 'package:readbox/blocs/home/home_cubit.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/res/dimens.dart';
import 'package:readbox/ui/screen/app_shell.dart';
import 'package:readbox/ui/screen/home/widgets/recent_job_card.dart';
import 'package:readbox/ui/screen/home/widgets/tool_card_widget.dart';
import 'package:readbox/ui/screen/ocr/ocr_editor_screen.dart';
import 'package:readbox/ui/screen/ocr/ocr_upload_screen.dart';
import 'package:readbox/ui/screen/tools/document_scanner_screen.dart';
import 'package:readbox/ui/screen/tools/word_to_pdf_converter_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HomeCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<HomeCubit>().refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: _buildScanBanner(context)),
              SliverToBoxAdapter(child: _buildToolsSection(context)),
              SliverToBoxAdapter(child: _buildRecentJobsSection(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.SIZE_16,
        AppDimens.SIZE_16,
        AppDimens.SIZE_8,
        AppDimens.SIZE_8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Reader',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  'Nhận dạng & biên tập tài liệu thông minh',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.search_rounded, color: cs.onSurface),
            onPressed: () {}, // TODO: search
          ),
        ],
      ),
    );
  }

  // ─── Scan banner CTA ───────────────────────────────────────────────────────

  Widget _buildScanBanner(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.SIZE_16,
        vertical: AppDimens.SIZE_4,
      ),
      child: GestureDetector(
        onTap: () async {
          final job = await Navigator.push<OcrJobModel?>(
            context,
            MaterialPageRoute(builder: (_) => const OcrUploadScreen()),
          );
          if (!mounted) return;
          if (job != null) AppShellScope.of(this.context)?.switchTab(1);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.SIZE_16,
            vertical: AppDimens.SIZE_14,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.tertiary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(AppDimens.SIZE_16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quét tài liệu ngay',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nhận dạng văn bản bằng PaddleOCR',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppDimens.SIZE_10),
                decoration: BoxDecoration(
                  color: cs.onPrimary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.document_scanner_rounded,
                  color: cs.onPrimary,
                  size: AppDimens.SIZE_26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tools section ─────────────────────────────────────────────────────────

  Widget _buildToolsSection(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.SIZE_16,
            AppDimens.SIZE_16,
            AppDimens.SIZE_16,
            AppDimens.SIZE_8,
          ),
          child: Text(
            'Công cụ chuyển đổi',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: 116,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.SIZE_12,
            ),
            children: [
              ToolCardWidget(
                icon: Icons.picture_as_pdf_rounded,
                iconColor: Colors.blue.shade700,
                bgColor: Colors.blue.shade50,
                label: 'Word\n→ PDF',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WordToPdfConverterScreen(),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.SIZE_8),
              ToolCardWidget(
                icon: Icons.article_rounded,
                iconColor: Colors.indigo.shade700,
                bgColor: Colors.indigo.shade50,
                label: 'PDF\n→ Word',
                comingSoon: true,
              ),
              const SizedBox(width: AppDimens.SIZE_8),
              ToolCardWidget(
                icon: Icons.image_rounded,
                iconColor: Colors.green.shade700,
                bgColor: Colors.green.shade50,
                label: 'Image\n→ PDF',
                comingSoon: true,
              ),
              const SizedBox(width: AppDimens.SIZE_8),
              ToolCardWidget(
                icon: Icons.camera_alt_rounded,
                iconColor: Colors.teal.shade700,
                bgColor: Colors.teal.shade50,
                label: 'Scan\n& OCR',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DocumentScannerScreen(),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.SIZE_8),
              ToolCardWidget(
                icon: Icons.compress_rounded,
                iconColor: Colors.orange.shade700,
                bgColor: Colors.orange.shade50,
                label: 'Nén\nPDF',
                comingSoon: true,
              ),
              const SizedBox(width: AppDimens.SIZE_12),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Recent OCR jobs ───────────────────────────────────────────────────────

  Widget _buildRecentJobsSection(BuildContext context) {
    return BlocBuilder<HomeCubit, BaseState>(
      builder: (context, state) {
        if (state is LoadingState) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimens.SIZE_24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final jobs = state is LoadedState<HomeLoaded>
            ? state.data.recentJobs
            : <OcrJobModel>[];

        if (jobs.isEmpty) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final cs = theme.colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.SIZE_16,
                AppDimens.SIZE_16,
                AppDimens.SIZE_8,
                AppDimens.SIZE_8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Job OCR gần đây',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  TextButton(
                    onPressed: () => AppShellScope.of(context)?.switchTab(1),
                    child: Text(
                      'Xem tất cả',
                      style: TextStyle(color: cs.primary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.SIZE_12,
                ),
                itemCount: jobs.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppDimens.SIZE_8),
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  return RecentJobCard(
                    job: job,
                    onTap: () {
                      if (job.status == OcrJobStatus.done) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OcrEditorScreen(
                              jobId: job.id,
                              title: job.originalName,
                            ),
                          ),
                        );
                      } else {
                        // Job chưa xong → chuyển sang tab Tài liệu để theo dõi
                        AppShellScope.of(context)?.switchTab(1);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
