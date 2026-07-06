import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/auth/screens/login_screen.dart';
import 'package:hoyaid/features/auth/screens/register_screen.dart';
import 'package:hoyaid/features/auth/screens/profile_screen.dart';
import 'package:hoyaid/features/admin/screens/admin_dashboard_screen.dart';
import 'package:hoyaid/features/admin/screens/admin_export_screen.dart';
import 'package:hoyaid/features/admin/screens/admin_model_upload_screen.dart';
import 'package:hoyaid/features/admin/screens/admin_users_screen.dart';
import 'package:hoyaid/features/admin/screens/admin_verification_queue_screen.dart';
import 'package:hoyaid/features/classification/models/classification_models.dart';
import 'package:hoyaid/features/classification/screens/classification_camera_screen.dart';
import 'package:hoyaid/features/classification/screens/classification_result_screen.dart';
import 'package:hoyaid/features/classification/screens/classification_screen.dart';
import 'package:hoyaid/features/classification/screens/manual_location_picker_screen.dart';
import 'package:hoyaid/features/history/screens/classification_detail_screen.dart';
import 'package:hoyaid/features/history/screens/history_screen.dart';
import 'package:hoyaid/features/home/screens/main_menu_screen.dart';
import 'package:hoyaid/features/map/screens/distribution_map_screen.dart';
import 'package:hoyaid/features/species/screens/admin_label_map_screen.dart';
import 'package:hoyaid/features/species/screens/admin_species_form_screen.dart';
import 'package:hoyaid/features/species/screens/admin_species_list_screen.dart';
import 'package:hoyaid/features/species/screens/species_detail_screen.dart';
import 'package:hoyaid/features/species/screens/species_list_screen.dart';
import 'package:hoyaid/features/splash/screens/splash_screen.dart';

/// Custom Listenable to wrap Stream for GoRouter refreshListenable
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Provider untuk GoRouter dengan Auth Guard
final appRouterProvider = Provider<GoRouter>((ref) {
  final authService = ref.read(authServiceProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    redirect: (context, state) {
      final isLoggedIn = authService.currentUser != null;
      final isSplash = state.matchedLocation == '/splash';
      final isLogin = state.matchedLocation == '/login';
      final isRegister = state.matchedLocation == '/register';

      // If in splash, let splash screen handle its own delay,
      // but usually you'd want splash to redirect to login or home.
      // We will let splash screen redirect manually after animation.
      if (isSplash) return null;

      if (!isLoggedIn && !isLogin && !isRegister) {
        return '/login';
      }

      if (isLoggedIn && (isLogin || isRegister)) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const MainMenuScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/classification',
        name: 'classification',
        builder: (context, state) => const ClassificationScreen(),
      ),
      GoRoute(
        path: '/classification/camera',
        name: 'classification-camera',
        builder: (context, state) => const ClassificationCameraScreen(),
      ),
      GoRoute(
        path: '/classification/result',
        name: 'classification-result',
        builder: (context, state) {
          final extra = state.extra;
          return ClassificationResultScreen(
            draft: extra is ClassificationDraft ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/classification/location-picker',
        name: 'classification-location-picker',
        builder: (context, state) => const ManualLocationPickerScreen(),
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/history/:classificationId',
        name: 'classification-detail',
        builder: (context, state) {
          return ClassificationDetailScreen(
            classificationId: state.pathParameters['classificationId']!,
          );
        },
      ),
      GoRoute(
        path: '/map',
        name: 'distribution-map',
        builder: (context, state) => const DistributionMapScreen(),
      ),
      GoRoute(
        path: '/species',
        name: 'species',
        builder: (context, state) => const SpeciesListScreen(),
      ),
      GoRoute(
        path: '/species/:speciesId',
        name: 'species-detail',
        builder: (context, state) {
          return SpeciesDetailScreen(
            speciesId: state.pathParameters['speciesId']!,
          );
        },
      ),
      GoRoute(
        path: '/admin',
        name: 'admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        name: 'admin-users',
        builder: (context, state) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: '/admin/verification',
        name: 'admin-verification',
        builder: (context, state) => const AdminVerificationQueueScreen(),
      ),
      GoRoute(
        path: '/admin/export',
        name: 'admin-export',
        builder: (context, state) => const AdminExportScreen(),
      ),
      GoRoute(
        path: '/admin/model-upload',
        name: 'admin-model-upload',
        builder: (context, state) => const AdminModelUploadScreen(),
      ),
      GoRoute(
        path: '/admin/species',
        name: 'admin-species',
        builder: (context, state) => const AdminSpeciesListScreen(),
      ),
      GoRoute(
        path: '/admin/species/new',
        name: 'admin-species-new',
        builder: (context, state) => const AdminSpeciesFormScreen(),
      ),
      GoRoute(
        path: '/admin/species/:speciesId/edit',
        name: 'admin-species-edit',
        builder: (context, state) {
          return AdminSpeciesFormScreen(
            speciesId: state.pathParameters['speciesId']!,
          );
        },
      ),
      GoRoute(
        path: '/admin/label-map',
        name: 'admin-label-map',
        builder: (context, state) => const AdminLabelMapScreen(),
      ),
    ],
  );
});
