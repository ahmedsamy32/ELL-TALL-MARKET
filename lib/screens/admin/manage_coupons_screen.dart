import 'package:flutter/material.dart';

class ManageCouponsScreen extends StatefulWidget {
  const ManageCouponsScreen({super.key});

  @override
  State<ManageCouponsScreen> createState() => _ManageCouponsScreenState();
}

class _ManageCouponsScreenState extends State<ManageCouponsScreen> {
  final List<Map<String, dynamic>> _coupons = [
    {"code": "WELCOME10", "discount": 10, "isActive": true},
    {"code": "SALE20", "discount": 20, "isActive": false},
    {"code": "FREESHIP", "discount": 100, "isActive": true},
  ];

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  void _addCoupon() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("إضافة كوبون جديد"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: "كود الكوبون"),
              ),
              TextField(
                controller: _discountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "نسبة الخصم"),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("إلغاء"),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              child: const Text("إضافة"),
              onPressed: () {
                setState(() {
                  _coupons.add({
                    "code": _codeController.text,
                    "discount": int.tryParse(_discountController.text) ?? 0,
                    "isActive": true,
                  });
                  _codeController.clear();
                  _discountController.clear();
                });
                Navigator.pop(ctx);
              },
            ),
          ],
        );
      },
    );
  }

  void _toggleCoupon(int index) {
    setState(() {
      _coupons[index]["isActive"] = !_coupons[index]["isActive"];
    });
  }

  void _deleteCoupon(int index) {
    setState(() {
      _coupons.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة الكوبونات"),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addCoupon),
        ],
      ),
      body: ListView.builder(
        itemCount: _coupons.length,
        padding: const EdgeInsets.all(12),
        itemBuilder: (ctx, index) {
          final coupon = _coupons[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(
                Icons.local_offer,
                color: coupon["isActive"] ? Colors.green : Colors.grey,
              ),
              title: Text(
                coupon["code"],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("خصم ${coupon["discount"]}%"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: coupon["isActive"],
                    onChanged: (_) => _toggleCoupon(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteCoupon(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
