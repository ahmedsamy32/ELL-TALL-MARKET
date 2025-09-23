import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/widgets/custom_search_bar.dart';

class ManageOrdersScreen extends StatefulWidget {
  const ManageOrdersScreen({super.key});

  @override
  _ManageOrdersScreenState createState() => _ManageOrdersScreenState();
}

class _ManageOrdersScreenState extends State<ManageOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).fetchAllOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلبات'),
        centerTitle: true,
        elevation: 1,
      ),
      body: Column(
        children: [
          _buildStatsRow(orderProvider),
          _buildSearchAndFilterBar(),
          Expanded(child: _buildOrdersList(orderProvider)),
        ],
      ),
    );
  }

  /// 🔹 بطاقات الإحصائيات
  Widget _buildStatsRow(OrderProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard("الكل", provider.orders.length, Colors.blue),
          _buildStatCard(
            "قيد التنفيذ",
            provider.orders.where((o) => o.status == "pending").length,
            Colors.orange,
          ),
          _buildStatCard(
            "مكتمل",
            provider.orders.where((o) => o.status == "completed").length,
            Colors.green,
          ),
          _buildStatCard(
            "ملغي",
            provider.orders.where((o) => o.status == "canceled").length,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, Color color) {
    return Expanded(
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(title, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 6),
              Text(
                value.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔹 البحث والفلاتر
  Widget _buildSearchAndFilterBar() {
    return AdminSearchBar(
      controller: _searchController,
      hintText: 'ابحث برقم الطلب',
      onChanged: (_) => setState(() {}),
      filterChips: [
        _buildFilterChip('الكل', 'all'),
        _buildFilterChip('قيد التنفيذ', 'pending'),
        _buildFilterChip('مكتمل', 'completed'),
        _buildFilterChip('ملغي', 'canceled'),
      ],
    );
  }

  Widget _buildFilterChip(String label, String filter) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == filter,
      onSelected: (_) => setState(() => _selectedFilter = filter),
      selectedColor: AppColors.primary.withValues(alpha: 51), // 0.2 * 255 = 51
      checkmarkColor: AppColors.primary,
    );
  }

  /// 🔹 قائمة الطلبات
  Widget _buildOrdersList(OrderProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا يوجد طلبات', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    final filteredOrders = _filterOrders(provider.orders);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        if (_searchController.text.isNotEmpty &&
            !order.id.contains(_searchController.text)) {
          return const SizedBox.shrink();
        }
        return _buildOrderCard(order);
      },
    );
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    switch (_selectedFilter) {
      case 'pending':
        return orders.where((o) => o.status == "pending").toList();
      case 'completed':
        return orders.where((o) => o.status == "completed").toList();
      case 'canceled':
        return orders.where((o) => o.status == "canceled").toList();
      default:
        return orders;
    }
  }

  /// 🔹 بطاقة الطلب
  Widget _buildOrderCard(OrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.shopping_cart, color: Colors.white),
        ),
        title: Text(
          "طلب #${order.id}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "العميل: ${order.userName}\nالإجمالي: ${order.finalAmount} ر.س",
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == "عرض التفاصيل") {
              _viewOrderDetails(order);
            } else if (value == "تغيير الحالة") {
              _changeOrderStatus(order);
            } else if (value == "حذف") {
              _deleteOrder(order);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: "عرض التفاصيل",
              child: Text("عرض التفاصيل"),
            ),
            const PopupMenuItem(
              value: "تغيير الحالة",
              child: Text("تغيير الحالة"),
            ),
            const PopupMenuItem(value: "حذف", child: Text("حذف")),
          ],
        ),
      ),
    );
  }

  /// 🔹 عرض تفاصيل الطلب
  void _viewOrderDetails(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('تفاصيل الطلب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("رقم الطلب: ${order.id}"),
            Text("اسم العميل: ${order.userName}"),
            Text("الإجمالي: ${order.finalAmount} ر.س"),
            Text("الحالة: ${order.status}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  /// 🔹 تغيير حالة الطلب
  void _changeOrderStatus(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('تغيير حالة الطلب'),
        content: DropdownButtonFormField<String>(
          initialValue: order.status.name,
          items: const [
            DropdownMenuItem(value: "pending", child: Text("قيد التنفيذ")),
            DropdownMenuItem(value: "completed", child: Text("مكتمل")),
            DropdownMenuItem(value: "canceled", child: Text("ملغي")),
          ],
          onChanged: (value) {
            // TODO: تحديث الحالة في Firebase
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: حفظ الحالة الجديدة
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  /// 🔹 حذف الطلب
  void _deleteOrder(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('حذف الطلب'),
        content: Text('هل أنت متأكد من حذف الطلب #${order.id}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              // TODO: حذف الطلب من Firebase
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
