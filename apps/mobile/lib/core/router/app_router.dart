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

class _AppShell extends StatefulWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  static const _tabs = ['/', '/feed', '/my-reports'];

  int _indexFor(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final i = _tabs.indexOf(loc);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indexFor(context),
        onTap: (i) => context.go(_tabs[i]),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.newspaper_outlined),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            label: 'My Reports',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/report/new'),
        tooltip: 'Submit Report',
        child: const Icon(Icons.add),
      ),
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
