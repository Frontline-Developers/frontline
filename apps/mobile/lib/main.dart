import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/pin/domain/entities/pin_state.dart';
import 'features/pin/presentation/providers/pin_provider.dart';
import 'features/pin/presentation/screens/pin_screen.dart';
import 'features/search/data/datasources/search_datasource.dart';
import 'features/search/presentation/providers/search_provider.dart';

import 'firebase_options.dart';

const _useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (_useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
    // Reporting CF is deployed to asia-southeast1; the regional instance must
    // also be pointed at the emulator or callable() will fail on the wrong host.
    FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).useFunctionsEmulator('localhost', 5001);
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);

    // Sign in anonymously up front so the FAB → /report/new flow always has
    // a uid available for the submit pipeline (matches firestore.rules).
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  // Sign in anonymously so all Firestore rules (request.auth != null) pass.
  // Required in both emulator and prod — without this the feed gets permission-denied.
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('Anonymous sign-in failed: $e');
      // Schedule a single retry after a brief delay — covers the common case
      // where the network is not ready at cold start (e.g. app opens before
      // connectivity is fully established).
      Future.delayed(const Duration(seconds: 5), () async {
        if (FirebaseAuth.instance.currentUser == null) {
          try {
            await FirebaseAuth.instance.signInAnonymously();
          } catch (_) {}
        }
      });
    }
  }

  final prefs = await SharedPreferences.getInstance();
  final searchRepo = SearchDatasourceImpl(prefs);

  runApp(
    ProviderScope(
      overrides: [searchRepositoryProvider.overrideWithValue(searchRepo)],
      child: const FrontlineApp(),
    ),
  );
}

class FrontlineApp extends ConsumerWidget {
  const FrontlineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pin = ref.watch(pinNotifierProvider);

    // Always use a single MaterialApp.router so the Flutter engine view is
    // never disposed and recreated on PIN unlock (which causes an
    // "Trying to render a disposed EngineFlutterView" assertion on web).
    // The PIN screen is overlaid via the builder callback instead.
    return MaterialApp.router(
      title: 'Frontline',
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      scrollBehavior: _AppScrollBehavior(),
      builder: (context, child) {
        // Always keep child (GoRouter's navigator) in the tree so its
        // GlobalKey is never orphaned. PinScreen is stacked on top when
        // locked — removing it on unlock avoids the duplicate-key crash.
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (pin.status != PinStatus.unlocked) const PinScreen(),
          ],
        );
      },
    );
  }
}

/// Enables mouse-drag scrolling on web/desktop in addition to touch.
class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}
