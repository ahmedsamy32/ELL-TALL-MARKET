import 'package:flutter/material.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/widgets/dashboard_card.dart';

class CaptainDashboardScreen extends StatelessWidget {
  const CaptainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الكابتن'),
        centerTitle: true,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          DashboardCard(
            title: 'الطلبات الجديدة',
            icon: Icons.delivery_dining,
            onTap: () => Navigator.pushNamed(context, AppRoutes.captainOrders),
          ),

          DashboardCard(
            title: 'المحفظة',
            icon: Icons.account_balance_wallet,
            onTap: () => Navigator.pushNamed(context, AppRoutes.captainWallet),
          ),

          DashboardCard(
            title: 'الإحصائيات',
            icon: Icons.analytics,
            onTap: () {
              // TODO: Implement statistics navigation
            },
          ),

          DashboardCard(
            title: 'الملف الشخصي',
            icon: Icons.person,
            onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
          ),
        ],
      ),
    );
  }
}
