import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/compare/presentation/screens/compare_screen.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/my_reports/presentation/screens/my_reports_screen.dart';
import '../../features/reporting/presentation/screens/reporting_screen.dart';

const _navy = Color(0xFF1E3A8A);
const _inkTertiary = Color(0xFF868E96);
const _hairline = Color(0xFFDEE2E6);

final appRouter = GoRouter(
  initialLocation: '/feed',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(path: '/feed', builder: (context, state) => const FeedScreen()),
        GoRoute(path: '/', builder: (context, state) => const MapScreen()),
        GoRoute(
          path: '/compare',
          builder: (context, state) => const CompareScreen(),
        ),
        GoRoute(
          path: '/my-reports',
          builder: (context, state) => const MyReportsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/report/new',
      builder: (context, state) => const ReportingScreen(),
    ),
    GoRoute(
      path: '/report/:id',
      builder: (context, state) =>
          _ReportDetailPlaceholder(id: state.pathParameters['id']!),
    ),
  ],
);

class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  int _indexFor(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    return switch (loc) {
      '/feed' => 0,
      '/' => 1,
      '/compare' => 3,
      '/my-reports' => 4,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _indexFor(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: _AppNavBar(
        currentIndex: currentIndex,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/feed');
            case 1:
              context.go('/');
            case 2:
              context.push('/report/new');
            case 3:
              context.go('/compare');
            case 4:
              context.go('/my-reports');
          }
        },
      ),
    );
  }
}

// ── Custom 5-tab nav bar ──────────────────────────────────────────────────────

class _AppNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  const _AppNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _hairline, width: 0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavTab(
                icon: Icons.layers_outlined,
                activeIcon: Icons.layers,
                label: 'Feed',
                active: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavTab(
                icon: Icons.map_outlined,
                activeIcon: Icons.map,
                label: 'Map',
                active: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _ReportTab(onTap: () => onTap(2)),
              _NavTab(
                icon: Icons.compare_arrows_outlined,
                activeIcon: Icons.compare_arrows,
                label: 'Compare',
                active: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _NavTab(
                icon: Icons.folder_outlined,
                activeIcon: Icons.folder,
                label: 'My posts',
                active: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _navy : _inkTertiary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTab extends StatelessWidget {
  final VoidCallback onTap;
  const _ReportTab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _navy,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x331E3A8A),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.verified_user,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Report',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: _inkTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Placeholder ───────────────────────────────────────────────────────────────

class _ReportDetailPlaceholder extends StatelessWidget {
  final String id;
  const _ReportDetailPlaceholder({required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: Center(child: Text('Report $id — coming soon')),
    );
  }
}
