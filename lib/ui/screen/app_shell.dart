import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readbox/blocs/cubit.dart';
import 'package:readbox/domain/data/models/models.dart';
import 'package:readbox/domain/repositories/ocr_repository.dart';
import 'package:readbox/injection_container.dart';
import 'package:readbox/res/dimens.dart';
import 'package:readbox/services/secure_storage_service.dart';
import 'package:readbox/ui/screen/home/home_screen.dart';
import 'package:readbox/ui/screen/ocr/ocr_job_list_screen.dart';
import 'package:readbox/ui/screen/ocr/ocr_upload_screen.dart';
import 'package:readbox/ui/screen/settings/page/notification_screen.dart';
import 'package:readbox/ui/screen/settings/setting_screen.dart';

// ─── InheritedWidget để các màn con có thể switch tab ──────────────────────

class AppShellScope extends InheritedWidget {
  final void Function(int index) switchTab;

  const AppShellScope({
    super.key,
    required this.switchTab,
    required super.child,
  });

  static AppShellScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellScope>();
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) => false;
}

// ─── AppShell ──────────────────────────────────────────────────────────────

class AppShell extends StatefulWidget {
  final int initialTab;
  const AppShell({super.key, this.initialTab = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationCubit>().getUnreadCount();
      }
    });
  }

  void _switchTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final notificationCubit = context.read<NotificationCubit>();

    // FAB chỉ hiển thị ở tab Home (0) và Tài liệu (1)
    final showFab = _currentIndex == 0 || _currentIndex == 1;

    return AppShellScope(
      switchTab: _switchTab,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            // Tab 0: Trang chủ
            BlocProvider(
              create: (_) => HomeCubit(getIt<OcrRepository>()),
              child: const HomeScreen(),
            ),
            // Tab 1: Tài liệu (OCR Job List)
            const OcrJobListScreen(),
            // Tab 2: Thông báo
            const NotificationScreen(),
            // Tab 3: Tài khoản
            const _AccountTab(),
          ],
        ),

        // ─── FAB ─────────────────────────────────────────────────────────
        floatingActionButton: showFab ? _buildFab(context) : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

        // ─── Bottom navigation ────────────────────────────────────────────
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _switchTab,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: cs.primary,
          unselectedItemColor: cs.onSurfaceVariant,
          backgroundColor: cs.surface,
          elevation: 8,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Trang chủ',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt_rounded),
              label: 'Tài liệu',
            ),
            BottomNavigationBarItem(
              icon: ValueListenableBuilder<int>(
                valueListenable: notificationCubit.unreadCountNotifier,
                builder: (_, count, __) => _NotifIcon(
                  count: count,
                  active: false,
                ),
              ),
              activeIcon: ValueListenableBuilder<int>(
                valueListenable: notificationCubit.unreadCountNotifier,
                builder: (_, count, __) => _NotifIcon(
                  count: count,
                  active: true,
                ),
              ),
              label: 'Thông báo',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () async {
        final job = await Navigator.push<OcrJobModel?>(
          context,
          MaterialPageRoute(builder: (_) => const OcrUploadScreen()),
        );
        // Sau khi tạo job xong, chuyển sang tab Tài liệu
        if (job != null && mounted) {
          _switchTab(1);
        }
      },
      icon: const Icon(Icons.document_scanner_rounded),
      label: const Text('Quét OCR'),
      tooltip: 'Quét tài liệu mới',
    );
  }
}

// ─── Badge icon thông báo ──────────────────────────────────────────────────

class _NotifIcon extends StatelessWidget {
  final int count;
  final bool active;
  const _NotifIcon({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    final icon = active
        ? Icons.notifications_rounded
        : Icons.notifications_outlined;

    if (count <= 0) return Icon(icon);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          top: -4,
          right: -6,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: AppDimens.SIZE_16,
              minHeight: AppDimens.SIZE_16,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(AppDimens.SIZE_8),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Account tab ──────────────────────────────────────────────────────────

class _AccountTab extends StatefulWidget {
  const _AccountTab();

  @override
  State<_AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<_AccountTab> {
  UserModel? _user;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await SecureStorageService().getUserInfo();
    if (mounted) setState(() { _user = user; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return SettingScreen(user: _user);
  }
}
