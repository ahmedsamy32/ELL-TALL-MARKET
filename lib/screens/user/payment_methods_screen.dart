import 'package:flutter/material.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/utils/navigation_service.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  late String selectedMethod;
  final ValueNotifier<bool> _isProcessingVN = ValueNotifier<bool>(false);
  String? savedCardLast4;
  bool showCardForm = false;
  CardFieldInputDetails? cardDetails;

  @override
  void dispose() {
    _isProcessingVN.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    selectedMethod = 'none';
    _fetchSavedCard();
  }

  Future<void> _fetchSavedCard() async {
    _isProcessingVN.value = true;
    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      final response = await http.get(
        Uri.parse(
          'https://your-server.com/get-payment-method?userId=${authProvider.currentUserProfile!.id}',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['last4'] != null) {
          if (!mounted) return;
          setState(() => savedCardLast4 = data['last4']);
        }
      }
    } catch (_) {}
    _isProcessingVN.value = false;
  }

  @override
  Widget build(BuildContext context) {
    // final authProvider = Provider.of<SupabaseProvider>(context); // Note: Use for payment method updates
    final paymentMethods = [
      {'id': 'cod', 'label': 'الدفع عند الاستلام', 'icon': Icons.money},
      {
        'id': 'credit_card',
        'label': 'بطاقة الائتمان',
        'icon': Icons.credit_card,
      },
      {
        'id': 'debit_card',
        'label': 'بطاقة الخصم المباشر',
        'icon': Icons.credit_card,
      },
      {'id': 'paypal', 'label': 'PayPal', 'icon': Icons.payment},
      {'id': 'google_pay', 'label': 'Google Pay', 'icon': Icons.g_mobiledata},
      {'id': 'apple_pay', 'label': 'Apple Pay', 'icon': Icons.apple},
      {'id': 'fawry', 'label': 'فوري', 'icon': Icons.store},
      {
        'id': 'vodafone_cash',
        'label': 'فودافون كاش',
        'icon': Icons.phone_android,
      },
      {
        'id': 'orange_money',
        'label': 'أورانج موني',
        'icon': Icons.attach_money,
      },
      {'id': 'etisalat_cash', 'label': 'اتصالات كاش', 'icon': Icons.money},
      {'id': 'meza', 'label': 'ميزة', 'icon': Icons.credit_card},
      {'id': 'meeza', 'label': 'ميزا', 'icon': Icons.credit_card},
      {
        'id': 'bank_transfer',
        'label': 'تحويل بنكي',
        'icon': Icons.account_balance,
      },
      {
        'id': 'cash_on_delivery',
        'label': 'الدفع نقداً عند الاستلام',
        'icon': Icons.local_shipping,
      },
      {'id': 'none', 'label': 'اختر لاحقاً', 'icon': Icons.do_not_disturb_on},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('طرق الدفع'),
        backgroundColor: Colors.green,
      ),
      body: ResponsiveCenter(
        maxWidth: 700,
        child: ValueListenableBuilder<bool>(
          valueListenable: _isProcessingVN,
          builder: (context, isProcessing, _) {
            if (isProcessing) {
              return AppShimmer.list(context);
            }
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      itemCount: paymentMethods.length,
                      separatorBuilder: (_, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final method = paymentMethods[index];
                        return Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                method['icon'] as IconData,
                                color: Colors.green,
                              ),
                              title: Text(method['label'] as String),
                              trailing: selectedMethod == method['id']
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : null,
                              onTap: () async {
                                if (method['id'] == 'credit_card' ||
                                    method['id'] == 'debit_card') {
                                  setState(() {
                                    showCardForm = true;
                                  });
                                } else if (method['id'] == 'paypal') {
                                  _handlePayPal();
                                } else if (method['id'] == 'google_pay') {
                                  _handleGooglePay();
                                } else if (method['id'] == 'apple_pay') {
                                  _handleApplePay();
                                } else {
                                  // Note: updatePreferredPayment method not yet implemented
                                  // This would update user's preferred payment method in profile
                                  setState(() {
                                    selectedMethod = method['id'] as String;
                                    showCardForm = false;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'تم اختيار ${method['name']}',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                            ),
                            // عرض تفاصيل إضافية لكل وسيلة دفع
                            if ((method['id'] == 'credit_card' ||
                                    method['id'] == 'debit_card') &&
                                savedCardLast4 != null)
                              _buildSavedCardWidget(savedCardLast4!),
                            if ((method['id'] == 'credit_card' ||
                                    method['id'] == 'debit_card') &&
                                showCardForm)
                              _buildCardForm(),
                            if (method['id'] == 'bank_transfer')
                              _buildBankDetails(),
                            if (method['id'] == 'fawry' &&
                                selectedMethod == 'fawry')
                              _buildFawryDetails(),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSavedCardWidget(String last4) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('**** **** **** $last4', style: const TextStyle(fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => deleteSavedCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildCardForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          CardField(
            onCardChanged: (details) => setState(() => cardDetails = details),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('حفظ البطاقة'),
            onPressed: cardDetails?.complete == true
                ? () => saveCardForLaterWithDetails(cardDetails!)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetails() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'تفاصيل الحساب البنكي:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('اسم البنك: البنك الأهلي المصري'),
          Text('رقم الحساب: XXXXXXXXXXXXXXXX'),
          Text('IBAN: EGXXXXXXXXXXXXXXXXXXXXXXXXX'),
          Text('اسم المستفيد: إيل تال ماركت'),
        ],
      ),
    );
  }

  Widget _buildFawryDetails() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('كود فوري:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('XXXXXXXX'),
          Text('يمكنك الدفع من خلال أي منفذ فوري'),
        ],
      ),
    );
  }

  Future<void> _handlePayPal() async {
    // تنفيذ عملية الدفع عبر PayPal
    _isProcessingVN.value = true;
    try {
      // قم بإضافة منطق PayPal هنا
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري تحويلك إلى PayPal...')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      _isProcessingVN.value = false;
    }
  }

  Future<void> _handleGooglePay() async {
    _isProcessingVN.value = true;
    try {
      // قم بإضافة منطق Google Pay هنا
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('جاري تجهيز Google Pay...')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      _isProcessingVN.value = false;
    }
  }

  Future<void> _handleApplePay() async {
    _isProcessingVN.value = true;
    try {
      // قم بإضافة منطق Apple Pay هنا
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('جاري تجهيز Apple Pay...')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      _isProcessingVN.value = false;
    }
  }

  Future<void> saveCardForLater() async {
    _isProcessingVN.value = true;

    // التقاط messenger قبل أي async operation
    final navContext = NavigationService.navigatorKey.currentContext;
    final messenger = navContext != null
        ? ScaffoldMessenger.of(navContext)
        : null;

    try {
      final navContextForProvider =
          NavigationService.navigatorKey.currentContext;
      if (navContextForProvider == null) {
        throw Exception('لا يمكن الوصول إلى سياق التطبيق حالياً');
      }

      final authProvider = Provider.of<SupabaseProvider>(
        navContextForProvider,
        listen: false,
      );

      final paymentMethod = await Stripe.instance.createPaymentMethod(
        params: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );
      final response = await http.post(
        Uri.parse('https://your-server.com/save-payment-method'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': authProvider.currentUserProfile!.id,
          'paymentMethodId': paymentMethod.id,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() => savedCardLast4 = data['last4']);
        messenger?.showSnackBar(
          const SnackBar(content: Text('تم حفظ معلومات البطاقة للدفع لاحقاً')),
        );
      } else {
        throw Exception('فشل حفظ البطاقة');
      }
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ البطاقة: $e')),
      );
    } finally {
      _isProcessingVN.value = false;
    }
  }

  Future<void> saveCardForLaterWithDetails(
    CardFieldInputDetails details,
  ) async {
    _isProcessingVN.value = true;

    // التقاط messenger قبل أي async operation
    final navContext = NavigationService.navigatorKey.currentContext;
    final messenger = navContext != null
        ? ScaffoldMessenger.of(navContext)
        : null;

    try {
      final navContextForProvider =
          NavigationService.navigatorKey.currentContext;
      if (navContextForProvider == null) {
        throw Exception('لا يمكن الوصول إلى سياق التطبيق حالياً');
      }

      final authProvider = Provider.of<SupabaseProvider>(
        navContextForProvider,
        listen: false,
      );

      final paymentMethod = await Stripe.instance.createPaymentMethod(
        params: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(),
          ),
        ),
      );
      final response = await http.post(
        Uri.parse('https://your-server.com/save-payment-method'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': authProvider.currentUserProfile!.id,
          'paymentMethodId': paymentMethod.id,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          savedCardLast4 = data['last4'];
          showCardForm = false;
        });
        messenger?.showSnackBar(
          const SnackBar(content: Text('تم حفظ معلومات البطاقة بنجاح')),
        );
      } else {
        throw Exception('فشل حفظ البطاقة');
      }
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ البطاقة: $e')),
      );
    } finally {
      _isProcessingVN.value = false;
    }
  }

  Future<void> deleteSavedCard() async {
    _isProcessingVN.value = true;
    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      final response = await http.post(
        Uri.parse('https://your-server.com/delete-payment-method'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': authProvider.currentUserProfile!.id}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          savedCardLast4 = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف البطاقة المحفوظة')),
        );
      } else {
        throw Exception('فشل حذف البطاقة');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء حذف البطاقة: $e')));
    } finally {
      _isProcessingVN.value = false;
    }
  }
}
