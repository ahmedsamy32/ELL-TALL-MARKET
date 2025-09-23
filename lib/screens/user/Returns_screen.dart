import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/firebase_auth_provider.dart';
import 'package:ell_tall_market/config/supabase_config.dart';

class ReturnItem {
  final String id;
  final String orderId;
  final String productName;
  final String reason;
  final String status; // Pending, Approved, Rejected
  final DateTime date;

  ReturnItem({
    required this.id,
    required this.orderId,
    required this.productName,
    required this.reason,
    required this.status,
    required this.date,
  });

  factory ReturnItem.fromMap(Map<String, dynamic> data, String id) {
    return ReturnItem(
      id: id,
      orderId: data['order_id'] ?? '',
      productName: data['product_name'] ?? '',
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      date: DateTime.parse(data['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap(String userId) {
    return {
      'user_id': userId,
      'order_id': orderId,
      'product_name': productName,
      'reason': reason,
      'status': status,
      'created_at': date.toIso8601String(),
    };
  }
}

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  final _supabase = SupabaseConfig.client;

  Future<void> addOrEditReturn(BuildContext context, ReturnItem? existing) async {
    final authProvider = Provider.of<FirebaseAuthProvider>(context, listen: false);
    String productName = existing?.productName ?? '';
    String reason = existing?.reason ?? '';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'إضافة طلب مرتجع' : 'تعديل الطلب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'اسم المنتج'),
                controller: TextEditingController(text: productName),
                onChanged: (value) => productName = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'سبب الإرجاع'),
                controller: TextEditingController(text: reason),
                onChanged: (value) => reason = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (productName.isNotEmpty && reason.isNotEmpty) {
                  Navigator.pop(context);
                }
              },
              child: Text(existing == null ? 'إرسال' : 'تحديث'),
            ),
          ],
        );
      },
    );

    if (productName.isEmpty || reason.isEmpty) return;

    try {
      if (existing == null) {
        final newReturn = ReturnItem(
          id: '',
          orderId: 'ORD${DateTime.now().millisecondsSinceEpoch}',
          productName: productName,
          reason: reason,
          status: 'pending',
          date: DateTime.now(),
        );
        await _supabase
            .from('returns')
            .insert(newReturn.toMap(authProvider.user!.id));
      } else {
        await _supabase
            .from('returns')
            .update({
              'product_name': productName,
              'reason': reason,
            })
            .eq('id', existing.id)
            .eq('user_id', authProvider.user!.id);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'تم إضافة الطلب' : 'تم تحديث الطلب'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    }
  }

  Future<void> deleteReturn(ReturnItem item) async {
    if (item.status != 'pending') return;

    try {
      await _supabase
          .from('returns')
          .delete()
          .eq('id', item.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الطلب')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<FirebaseAuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('المرتجعات')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('returns')
            .stream(primaryKey: ['id'])
            .eq('user_id', authProvider.user!.id)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.assignment_return, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد طلبات مرتجعة حتى الآن'),
                ],
              ),
            );
          }

          final returnItems = snapshot.data!
              .map((doc) => ReturnItem.fromMap(doc, doc['id'] as String))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: returnItems.length,
            itemBuilder: (context, index) {
              final item = returnItems[index];
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: getStatusColor(item.status).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.status,
                              style: TextStyle(
                                color: getStatusColor(item.status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('رقم الطلب: ${item.orderId}'),
                      Text(
                        'تاريخ الإرجاع: ${item.date.day}/${item.date.month}/${item.date.year}',
                      ),
                      Text('سبب الإرجاع: ${item.reason}'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (item.status == 'pending') ...[
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => addOrEditReturn(context, item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteReturn(item),
                            ),
                          ],
                          TextButton(
                            onPressed: () {},
                            child: const Text('عرض التفاصيل'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => addOrEditReturn(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
