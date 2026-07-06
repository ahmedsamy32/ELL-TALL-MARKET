import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class ManageSubscriptionTiersScreen extends StatefulWidget {
  const ManageSubscriptionTiersScreen({super.key});

  @override
  State<ManageSubscriptionTiersScreen> createState() => _ManageSubscriptionTiersScreenState();
}

class _ManageSubscriptionTiersScreenState extends State<ManageSubscriptionTiersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tiers = [];
  String _instapayAddress = '';
  String _instapayPhone = '';
  String _topupInstructions = '';
  int _freeTrialMonths = 2;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTiers();
  }

  Future<void> _loadTiers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('subscription_tiers')
          .select()
          .order('id');
      
      final instapayResponse = await Supabase.instance.client
          .from('settings')
          .select()
          .eq('setting_key', 'admin_instapay_address')
          .maybeSingle();

      final phoneResponse = await Supabase.instance.client
          .from('settings')
          .select()
          .eq('setting_key', 'admin_instapay_phone')
          .maybeSingle();

      final instructionsResponse = await Supabase.instance.client
          .from('settings')
          .select()
          .eq('setting_key', 'merchant_topup_instructions')
          .maybeSingle();

      final freeTrialResponse = await Supabase.instance.client
          .from('settings')
          .select()
          .eq('setting_key', 'merchant_free_trial_months')
          .maybeSingle();

      setState(() {
        _tiers = List<Map<String, dynamic>>.from(response);
        if (instapayResponse != null) {
          _instapayAddress = instapayResponse['setting_value'] as String? ?? '';
        }
        if (phoneResponse != null) {
          _instapayPhone = phoneResponse['setting_value'] as String? ?? '';
        }
        if (instructionsResponse != null) {
          _topupInstructions = instructionsResponse['setting_value'] as String? ?? '';
        }
        if (freeTrialResponse != null) {
          _freeTrialMonths = int.tryParse(freeTrialResponse['setting_value'] as String? ?? '2') ?? 2;
        } else {
          _freeTrialMonths = 2;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل تحميل باقات الاشتراك والتعليمات: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _editTier(Map<String, dynamic> tier) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: tier['name']);
    final priceController = TextEditingController(text: (tier['monthly_price'] as num).toStringAsFixed(0));
    final ordersController = TextEditingController(text: tier['included_orders'].toString());
    final feeController = TextEditingController(text: (tier['overlimit_fee_per_order'] as num).toStringAsFixed(2));
    final maxOverlimitController = TextEditingController(text: tier['max_overlimit_orders'].toString());
    bool isUnlimited = tier['included_orders'] == -1;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  20,
                  16,
                  MediaQuery.of(dialogContext).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'تعديل تفاصيل باقة الاشتراك',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم الباقة',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'سعر الاشتراك الشهري (ج.م)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'هذا الحقل مطلوب';
                            if (double.tryParse(v) == null) return 'يرجى إدخال رقم صحيح';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('أوردرات غير محدودة'),
                          value: isUnlimited,
                          onChanged: (val) {
                            setDialogState(() {
                              isUnlimited = val;
                              if (val) {
                                ordersController.text = '-1';
                                feeController.text = '0.00';
                                maxOverlimitController.text = '0';
                              } else {
                                ordersController.text = tier['included_orders'] == -1 ? '30' : tier['included_orders'].toString();
                                feeController.text = (tier['overlimit_fee_per_order'] as num).toStringAsFixed(2);
                                maxOverlimitController.text = tier['max_overlimit_orders'].toString();
                              }
                            });
                          },
                        ),
                        if (!isUnlimited) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: ordersController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'عدد الأوردرات المشمولة شهرياً',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (isUnlimited) return null;
                              if (v == null || v.trim().isEmpty) return 'هذا الحقل مطلوب';
                              final val = int.tryParse(v);
                              if (val == null || val <= 0) return 'يرجى إدخال عدد صحيح أكبر من الصفر';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: feeController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'رسوم الأوردر الإضافي',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) {
                                    if (isUnlimited) return null;
                                    if (v == null || v.trim().isEmpty) return 'هذا الحقل مطلوب';
                                    if (double.tryParse(v) == null) return 'يرجى إدخال رقم صحيح';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: maxOverlimitController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'أقصى عدد أوردرات إضافية',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) {
                                    if (isUnlimited) return null;
                                    if (v == null || v.trim().isEmpty) return 'هذا الحقل مطلوب';
                                    if (int.tryParse(v) == null) return 'يرجى إدخال عدد صحيح';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                child: const Text('إلغاء'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) return;
                                  
                                  final messenger = ScaffoldMessenger.of(context);
                                  final navigator = Navigator.of(sheetContext);

                                  try {
                                    await Supabase.instance.client
                                        .from('subscription_tiers')
                                        .update({
                                          'name': nameController.text.trim(),
                                          'monthly_price': double.parse(priceController.text.trim()),
                                          'included_orders': isUnlimited ? -1 : int.parse(ordersController.text.trim()),
                                          'overlimit_fee_per_order': isUnlimited ? 0.00 : double.parse(feeController.text.trim()),
                                          'max_overlimit_orders': isUnlimited ? 0 : int.parse(maxOverlimitController.text.trim()),
                                        })
                                        .eq('id', tier['id']);
                                    
                                    navigator.pop();
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('✅ تم تعديل الباقة بنجاح'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    _loadTiers();
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('❌ فشل حفظ التعديلات: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: const Text('حفظ التعديلات'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editInstapayAddress() async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: _instapayAddress);
    final phoneController = TextEditingController(text: _instapayPhone);
    final instructionsController = TextEditingController(text: _topupInstructions);
    final trialController = TextEditingController(text: _freeTrialMonths.toString());

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              20,
              16,
              MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تعديل تفاصيل طريقة الشحن والإعدادات العامة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'عنوان InstaPay (مثال: name@instapay)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف المرتبط بالحساب (إنستا باي أو المحفظة)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: trialController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'مدة الفترة التجريبية المجانية للتجار الجدد (بالأشهر)',
                        helperText: 'أدخل 0 لإلغاء الفترة المجانية تماماً',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'هذا الحقل مطلوب';
                        final val = int.tryParse(v.trim());
                        if (val == null || val < 0) return 'يرجى إدخال رقم صحيح (0 أو أكبر)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: instructionsController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'تعليمات وطريقة الشحن بالتفصيل للتاجر',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(sheetContext);

                              try {
                                // Save InstaPay Address
                                await Supabase.instance.client.from('settings').upsert({
                                  'setting_key': 'admin_instapay_address',
                                  'setting_value': controller.text.trim(),
                                  'setting_type': 'string',
                                  'description': 'عنوان إنستا باي الخاص بالإدارة لاستلام الدفعات',
                                  'is_public': true,
                                }, onConflict: 'setting_key');

                                // Save Phone Number
                                await Supabase.instance.client.from('settings').upsert({
                                  'setting_key': 'admin_instapay_phone',
                                  'setting_value': phoneController.text.trim(),
                                  'setting_type': 'string',
                                  'description': 'رقم الهاتف المرتبط بحساب إنستا باي أو المحفظة',
                                  'is_public': true,
                                }, onConflict: 'setting_key');

                                // Save Free Trial Months Setting
                                await Supabase.instance.client.from('settings').upsert({
                                  'setting_key': 'merchant_free_trial_months',
                                  'setting_value': trialController.text.trim(),
                                  'setting_type': 'number',
                                  'description': 'عدد أشهر الفترة المجانية للتجار الجدد عند التسجيل لأول مرة',
                                  'is_public': true,
                                }, onConflict: 'setting_key');

                                await Supabase.instance.client.from('settings').upsert({
                                  'setting_key': 'merchant_topup_instructions',
                                  'setting_value': instructionsController.text.trim(),
                                  'setting_type': 'string',
                                  'description': 'تعليمات شحن المحفظة المعروضة للتجار',
                                  'is_public': true,
                                }, onConflict: 'setting_key');
                                
                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ تم حفظ الإعدادات بنجاح'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                _loadTiers();
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('❌ فشل حفظ التعديلات: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: const Text('حفظ'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstapayCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade800,
              Colors.blue.shade500,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.payment_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'معلومات وطريقة شحن المحفظة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: _editInstapayAddress,
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 24),
            const Text(
              'عنوان تحويل إنستا باي (InstaPay):',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              _instapayAddress.isEmpty ? 'لم يتم تعيين عنوان بعد' : _instapayAddress,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'رقم الهاتف المرتبط (إنستا باي أو المحفظة):',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              _instapayPhone.isEmpty ? 'لم يتم تعيين هاتف بعد' : _instapayPhone,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'الفترة التجريبية المجانية للتجار الجدد:',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              _freeTrialMonths == 0 ? 'موقوفة (لا يوجد فترة مجانية)' : '$_freeTrialMonths أشهر مجانية للتجار الجدد عند التسجيل',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'طريقة الشحن والتعليمات المعروضة للتاجر:',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              _topupInstructions.isEmpty ? 'لم يتم تعيين تعليمات شحن بعد' : _topupInstructions,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📦 إدارة باقات التجار'),
        centerTitle: true,
      ),
      body: ResponsiveCenter(
        maxWidth: 800,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadTiers,
            child: _isLoading
                ? AppShimmer.centeredLines(context)
                : (_errorMessage != null
                    ? _buildErrorState()
                    : _buildTiersList()),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadTiers,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTiersList() {
    if (_tiers.isEmpty && _instapayAddress.isEmpty) {
      return const Center(child: Text('لا توجد باقات اشتراك مضافة في النظام حالياً'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tiers.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildInstapayCard();
        }

        final tier = _tiers[index - 1];
        final String name = tier['name'];
        final double price = (tier['monthly_price'] as num).toDouble();
        final int includedOrders = tier['included_orders'];
        final double overlimitFee = (tier['overlimit_fee_per_order'] as num).toDouble();
        final int maxOverlimit = tier['max_overlimit_orders'];

        String arabicName = name;
        if (name.toLowerCase() == 'basic') {
          arabicName = 'الباقة الأساسية';
        } else if (name.toLowerCase() == 'pro') {
          arabicName = 'الباقة الاحترافية (Pro)';
        } else if (name.toLowerCase() == 'unlimited') {
          arabicName = 'الباقة غير المحدودة (Unlimited)';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      arabicName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editTier(tier),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildInfoRow('السعر الشهري', '${price.toStringAsFixed(2)} ج.م'),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'الأوردرات المشمولة',
                  includedOrders == -1 ? 'غير محدود' : '$includedOrders أوردر',
                ),
                if (includedOrders != -1) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow('رسوم الأوردر الإضافي', '${overlimitFee.toStringAsFixed(2)} ج.م'),
                  const SizedBox(height: 8),
                  _buildInfoRow('أقصى أوردرات إضافية مسموحة', '$maxOverlimit أوردر'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
