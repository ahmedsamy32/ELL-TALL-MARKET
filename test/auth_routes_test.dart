import 'package:ell_tall_market/models/profile_model.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/widgets/auth_route_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

class _TestAuth extends SupabaseProvider {
  @override
  bool isInitialized = true;
  @override
  bool isProfileLoading = false;
  @override
  User? currentUser;
  @override
  ProfileModel? currentProfile;
  @override
  bool get isLoggedIn => currentUser != null;

  void change({
    String? user,
    UserRole? role,
    String? profileId,
    bool active = true,
  }) {
    currentUser = user == null
        ? null
        : User(
            id: user,
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '',
          );
    currentProfile = role == null
        ? null
        : ProfileModel(
            id: profileId ?? user!,
            role: role,
            createdAt: DateTime(2026),
            isActive: active,
          );
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'protected content follows session and active profile ownership',
    (tester) async {
      final auth = _TestAuth()..isInitialized = false;
      int builds = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider<SupabaseProvider>.value(
          value: auth,
          child: MaterialApp(
            home: AuthRouteGuard(
              roles: const {UserRole.merchant},
              builder: (_) {
                builds++;
                return const Text('private');
              },
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      auth.isInitialized = true;
      auth.change();
      await tester.pump();
      expect(find.text('سجّل الدخول لفتح هذه الصفحة'), findsOneWidget);
      auth.isProfileLoading = true;
      auth.change(user: 'a');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      auth.isProfileLoading = false;
      for (final role in [UserRole.client, UserRole.admin, UserRole.captain]) {
        auth.change(user: 'a', role: role);
        await tester.pump();
        expect(find.text('ليس لديك صلاحية لفتح هذه الصفحة'), findsOneWidget);
      }
      auth.change(user: 'b', role: UserRole.merchant, profileId: 'a');
      await tester.pump();
      auth.change(user: 'b', role: UserRole.merchant, active: false);
      await tester.pump();
      expect(builds, 0);
      auth.change(user: 'b', role: UserRole.merchant);
      await tester.pump();
      expect(find.text('private'), findsOneWidget);
      auth.change();
      await tester.pump();
      expect(find.text('private'), findsNothing);
      expect(find.text('سجّل الدخول لفتح هذه الصفحة'), findsOneWidget);
    },
  );

  testWidgets(
    'named routes and notification links resolve through the same guard',
    (tester) async {
      final auth = _TestAuth();
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ChangeNotifierProvider<SupabaseProvider>.value(
          value: auth,
          child: MaterialApp(
            navigatorKey: nav,
            home: const SizedBox(),
            onGenerateRoute: AppRoutes.generateRoute,
          ),
        ),
      );
      final cases = <String, Set<UserRole>>{
        for (final path in [
          AppRoutes.adminDashboard,
          AppRoutes.manageUsers,
          AppRoutes.manageProducts,
          AppRoutes.manageOrders,
          AppRoutes.manageCategories,
          AppRoutes.manageCoupons,
          AppRoutes.storeWalletTopups,
          AppRoutes.appSettings,
          AppRoutes.dynamicUIBuilder,
          AppRoutes.analytics,
          AppRoutes.manageCaptains,
          AppRoutes.manageBanners,
          AppRoutes.deliveryZonePricing,
          AppRoutes.appUpdates,
          '/admin/orders/123',
        ])
          path: {UserRole.admin},
        for (final path in [
          AppRoutes.merchantDashboard,
          AppRoutes.merchantWallet,
          AppRoutes.merchantProducts,
          AppRoutes.addEditProduct,
          AppRoutes.merchantOrders,
          '/merchant/orders/123',
          'merchant_order',
          '/merchant_orders',
        ])
          path: {UserRole.merchant},
        for (final path in [
          AppRoutes.captainDashboard,
          AppRoutes.captainWallet,
          AppRoutes.captainOrders,
          AppRoutes.orderDelivery,
        ])
          path: {UserRole.captain},
        AppRoutes.deliveryCompanyDashboard: {
          UserRole.admin,
          UserRole.deliveryCompanyAdmin,
        },
        for (final path in [
          AppRoutes.checkout,
          AppRoutes.addresses,
          AppRoutes.editProfile,
          AppRoutes.profile,
          AppRoutes.orderHistory,
          AppRoutes.settings,
          AppRoutes.favorites,
          AppRoutes.notifications,
          AppRoutes.uploadPrescription,
          '/orders/123',
        ])
          path: {},
      };
      for (final entry in cases.entries) {
        nav.currentState!.pushNamed(entry.key, arguments: {'orderId': '123'});
        await tester.pumpAndSettle();
        final guard = tester.widget<AuthRouteGuard>(
          find.byType(AuthRouteGuard),
        );
        expect(guard.roles, entry.value, reason: entry.key);
        expect(find.text('سجّل الدخول لفتح هذه الصفحة'), findsOneWidget);
        nav.currentState!.pop();
        await tester.pumpAndSettle();
      }
    },
  );
}
