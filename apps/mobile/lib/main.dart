import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/mapbox_web_token.dart' if (dart.library.io) 'core/mapbox_web_token_stub.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

const _useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);
const _mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (_mapboxToken.isNotEmpty) {
    if (kIsWeb) {
      // mapbox_maps_flutter's MapboxOptions.setAccessToken crashes on Flutter
      // web DDC (debug) because their log_configuration.dart uses a non-const
      // bool.fromEnvironment. Set the token directly on the Mapbox GL JS
      // library instead (loaded in web/index.html).
      setMapboxWebToken(_mapboxToken);
    } else {
      MapboxOptions.setAccessToken(_mapboxToken);
    }
  }

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

  runApp(const ProviderScope(child: FrontlineApp()));
}

class FrontlineApp extends StatelessWidget {
  const FrontlineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Frontline',
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
