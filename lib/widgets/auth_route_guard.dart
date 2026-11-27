import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile_model.dart';
import '../providers/supabase_provider.dart';

/// An empty role set allows every active, signed-in account.
class AuthRouteGuard extends StatelessWidget {
  const AuthRouteGuard({
    super.key,
    required this.builder,
    this.roles = const {},
  });

  final WidgetBuilder builder;
  final Set<UserRole> roles;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<SupabaseProvider>();
    final profile = auth.currentProfile;
    if (!auth.isInitialized ||
        (auth.isLoggedIn && auth.isProfileLoading && profile == null)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isLoggedIn) {
      return Scaffold(
        body: Center(
          child: FilledButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('سجّل الدخول لفتح هذه الصفحة'),
            onPressed: () => Navigator.of(context).pushNamed('/login'),
          ),
        ),
      );
    }
    if (profile == null || profile.id != auth.currentUser?.id) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: auth.refreshCurrentProfile,
            child: const Text('تعذّر تحميل بيانات الحساب. إعادة المحاولة'),
          ),
        ),
      );
    }
    if (!profile.isActive ||
        (roles.isNotEmpty && !roles.contains(profile.role))) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('ليس لديك صلاحية لفتح هذه الصفحة')),
      );
    }
    return KeyedSubtree(
      key: ValueKey(profile.id),
      child: Builder(builder: builder),
    );
  }
}

/// Also used by screens pushed directly with Navigator.push.
MaterialPageRoute<T> protectedPage<T>({
  required WidgetBuilder builder,
  Set<UserRole> roles = const {},
  RouteSettings? settings,
}) => MaterialPageRoute<T>(
  settings: settings,
  builder: (_) => AuthRouteGuard(roles: roles, builder: builder),
);
