import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/core/router/app_router.dart';
import 'package:hoyaid/core/theme/app_theme.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/classification/providers/classification_provider.dart';
import 'package:hoyaid/features/classification/services/offline_sync_reminder_service.dart';
import 'package:hoyaid/firebase_options.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void offlineSyncReminderCallback() {
  Workmanager().executeTask((task, inputData) async {
    await OfflineSyncReminderService.showIfNeeded();
    return true;
  });
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Init Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );

    await OfflineSyncReminderService.requestPermission();
    await Workmanager().initialize(offlineSyncReminderCallback);
    await Workmanager().registerPeriodicTask(
      OfflineSyncReminderService.taskName,
      OfflineSyncReminderService.taskName,
      constraints: Constraints(networkType: NetworkType.connected),
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );

    // 2. Init App Check (debug provider untuk development)
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    );

    // 3. Init Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    runApp(
      const ProviderScope(
        child: HoyaApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('=== UNCAUGHT ERROR ===\n$error\n$stack');
  });
}

class HoyaApp extends ConsumerStatefulWidget {
  const HoyaApp({super.key});

  @override
  ConsumerState<HoyaApp> createState() => _HoyaAppState();
}

class _HoyaAppState extends ConsumerState<HoyaApp> {
  StreamSubscription? _syncSubscription;
  String? _syncSessionKey;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      accountSessionProvider,
      (_, __) => _restartAutoSync(),
      fireImmediately: true,
    );
  }

  void _restartAutoSync() {
    final session = ref.read(accountSessionProvider);
    final sessionKey = '${session.activeSlot.name}:${session.currentUser?.uid}';
    if (_syncSessionKey == sessionKey) return;

    _syncSubscription?.cancel();
    _syncSessionKey = sessionKey;
    _syncSubscription =
        ref.read(offlineClassificationQueueServiceProvider).startAutoSync();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'iHoya',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
