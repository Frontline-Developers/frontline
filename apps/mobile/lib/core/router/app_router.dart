import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/reporting/presentation/screens/reporting_screen.dart';
import '../../features/my_reports/presentation/screens/my_reports_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const MapScreen()),
        GoRoute(path: '/feed', builder: (context, state) => const FeedScreen()),
        GoRoute(
          path: '/compare',
          builder: (context, state) => const _ComparePlaceholder(),
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

// ---------------------------------------------------------------------------
// App Shell — 5-tab bottom nav with elevated center Report FAB
// ---------------------------------------------------------------------------

class _AppShell extends StatefulWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  // Shell routes in display order (Report FAB is separate)
  static const _routes = ['/feed', '/', '/compare', '/my-reports'];

  int _indexFor(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString().split('?').first;
    final i = _routes.indexOf(loc);
    return i < 0 ? 1 : i; // default to Map
  }

  @override
  Widget build(BuildContext context) {
    final idx = _indexFor(context);
    return Scaffold(
      body: widget.child,
      floatingActionButton: _ReportFab(
        onTap: () => context.push('/report/new'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNavBar(
        activeIndex: idx,
        onTap: (i) => context.go(_routes[i]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Report FAB
// ---------------------------------------------------------------------------

class _ReportFab extends StatelessWidget {
  final VoidCallback onTap;
  const _ReportFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            onPressed: onTap,
            backgroundColor: const Color(0xFF1E3A8A),
            elevation: 4,
            shape: const CircleBorder(),
            heroTag: 'report_fab',
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Report',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom nav bar (4 visible items + notch for FAB)
// ---------------------------------------------------------------------------

class _BottomNavBar extends StatelessWidget {
  final int activeIndex;
  final void Function(int) onTap;

  const _BottomNavBar({required this.activeIndex, required this.onTap});

  static const _activeColor = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      height: 64,
      padding: EdgeInsets.zero,
      color: Colors.white,
      elevation: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.layers_outlined,
            label: 'Feed',
            active: activeIndex == 0,
            onTap: () => onTap(0),
            activeColor: _activeColor,
          ),
          _NavItem(
            icon: Icons.map_outlined,
            label: 'Map',
            active: activeIndex == 1,
            onTap: () => onTap(1),
            activeColor: _activeColor,
          ),
          const SizedBox(width: 72),
          _NavItem(
            icon: Icons.compare_arrows_outlined,
            label: 'Compare',
            active: activeIndex == 2,
            onTap: () => onTap(2),
            activeColor: _activeColor,
          ),
          _NavItem(
            icon: Icons.folder_outlined,
            label: 'My posts',
            active: activeIndex == 3,
            onTap: () => onTap(3),
            activeColor: _activeColor,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : Colors.grey.shade500;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholders
// ---------------------------------------------------------------------------

class _ComparePlaceholder extends StatelessWidget {
  const _ComparePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare')),
      body: const Center(child: Text('Compare — coming soon')),
    );
  }
}

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
