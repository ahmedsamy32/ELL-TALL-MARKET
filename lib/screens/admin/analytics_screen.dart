import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final List<SalesData> _salesData = [
    SalesData('يناير', 35),
    SalesData('فبراير', 28),
    SalesData('مارس', 34),
    SalesData('أبريل', 32),
    SalesData('مايو', 40),
    SalesData('يونيو', 45),
    SalesData('يوليو', 50),
    SalesData('أغسطس', 55),
    SalesData('سبتمبر', 60),
    SalesData('أكتوبر', 65),
    SalesData('نوفمبر', 70),
    SalesData('ديسمبر', 75),
  ];

  final List<CategoryData> _categoryData = [
    CategoryData('إلكترونيات', 35, Colors.blue),
    CategoryData('ملابس', 25, Colors.green),
    CategoryData('أثاث', 20, Colors.orange),
    CategoryData('أجهزة', 15, Colors.purple),
    CategoryData('أخرى', 5, Colors.grey),
  ];

  final List<Activity> _activities = [
    Activity(
      'طلب جديد #1234',
      'تم إنشاء طلب جديد',
      'منذ دقيقتين',
      Colors.green,
    ),
    Activity('دفع ناجح', 'تم دفع 250 ج.م', 'منذ 5 دقائق', Colors.blue),
    Activity('مستخدم جديد', 'تسجيل حساب جديد', 'منذ 10 دقائق', Colors.orange),
    Activity('تحديث منتج', 'هاتف Samsung محدث', 'منذ 15 دقيقة', Colors.purple),
    Activity('تقييم جديد', '⭐ 5 نجوم لمنتج Dell', 'منذ 20 دقيقة', Colors.amber),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatsGrid(),
            const SizedBox(height: 20),
            _buildSalesChart(),
            const SizedBox(height: 20),
            _buildCategoryChart(),
            const SizedBox(height: 20),
            _buildRecentActivities(),
          ],
        ),
      ),
    );
  }

  // 🟢 كروت الإحصائيات السريعة
  Widget _buildStatsGrid() {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      children: [
        _buildStatCard(
          'إجمالي المبيعات',
          '125,000 ج.م',
          Icons.attach_money,
          Colors.green,
        ),
        _buildStatCard(
          'عدد الطلبات',
          '1,250',
          Icons.shopping_cart,
          Colors.blue,
        ),
        _buildStatCard('العملاء الجدد', '350', Icons.people, Colors.orange),
        _buildStatCard(
          'متوسط الطلب',
          '100 ج.م',
          Icons.trending_up,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // 🔵 شارت المبيعات الشهرية
  Widget _buildSalesChart() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "المبيعات الشهرية",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                series: <CartesianSeries>[
                  LineSeries<SalesData, String>(
                    dataSource: _salesData,
                    xValueMapper: (SalesData data, _) => data.month,
                    yValueMapper: (SalesData data, _) => data.sales,
                    markerSettings: const MarkerSettings(isVisible: true),
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🟣 شارت توزيع الفئات
  Widget _buildCategoryChart() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "توزيع المبيعات حسب الفئة",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCircularChart(
                legend: const Legend(
                  isVisible: true,
                  overflowMode: LegendItemOverflowMode.wrap,
                ),
                series: <CircularSeries>[
                  DoughnutSeries<CategoryData, String>(
                    dataSource: _categoryData,
                    xValueMapper: (CategoryData data, _) => data.category,
                    yValueMapper: (CategoryData data, _) => data.percentage,
                    pointColorMapper: (CategoryData data, _) => data.color,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🟠 قائمة النشاطات الحديثة
  Widget _buildRecentActivities() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "النشاطات الأخيرة",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._activities.map((activity) => _buildActivityItem(activity)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Activity activity) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: activity.color.withValues(alpha: 0.1),
        child: Icon(Icons.circle, color: activity.color, size: 14),
      ),
      title: Text(activity.title),
      subtitle: Text(activity.description),
      trailing: Text(
        activity.time,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }
}

// ================== Models ==================
class SalesData {
  final String month;
  final double sales;
  SalesData(this.month, this.sales);
}

class CategoryData {
  final String category;
  final double percentage;
  final Color color;
  CategoryData(this.category, this.percentage, this.color);
}

class Activity {
  final String title;
  final String description;
  final String time;
  final Color color;
  Activity(this.title, this.description, this.time, this.color);
}
