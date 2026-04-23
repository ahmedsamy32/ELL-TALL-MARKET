import 'package:flutter/material.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class MerchantPoliciesScreen extends StatelessWidget {
  final int initialTab;

  const MerchantPoliciesScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('السياسات والشروط'),
            centerTitle: true,
            elevation: 0,
            bottom: TabBar(
              indicatorColor: colorScheme.primary,
              labelColor: colorScheme.primary,
              labelStyle: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: textTheme.titleSmall,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: const [
                Tab(text: 'شروط الاستخدام'),
                Tab(text: 'سياسة الخصوصية'),
                Tab(text: 'سياسة العمولات'),
              ],
            ),
          ),
          body: ResponsiveCenter(
            maxWidth: 700,
            child: TabBarView(
              children: [
                SafeArea(child: _TermsOfServiceTab()),
                SafeArea(child: _PrivacyPolicyTab()),
                SafeArea(child: _CommissionPolicyTab()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== تبويب شروط الاستخدام =====
class _TermsOfServiceTab extends StatelessWidget {
  const _TermsOfServiceTab();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // مقدمة
        _buildSectionCard(
          context,
          icon: Icons.description_outlined,
          iconColor: colorScheme.primary,
          title: 'مرحباً بك في Ell Tall Market',
          content:
              'هذه الشروط والأحكام تحكم استخدامك لمنصة Ell Tall Market كتاجر. باستخدام خدماتنا، فإنك توافق على الالتزام بهذه الشروط.',
        ),
        const SizedBox(height: 16),

        // القسم 1: التسجيل والحساب
        _buildSectionCard(
          context,
          icon: Icons.person_add_outlined,
          iconColor: Colors.blue,
          title: '1. التسجيل وإدارة الحساب',
          content: '''
• يجب عليك تقديم معلومات دقيقة وكاملة عند التسجيل
• أنت مسؤول عن الحفاظ على سرية حسابك وكلمة المرور
• يجب عليك إخطارنا فوراً بأي استخدام غير مصرح به لحسابك
• يجب أن يكون عمرك 18 عاماً على الأقل للتسجيل كتاجر
• يحق لنا تعليق أو إنهاء حسابك في حالة انتهاك الشروط''',
        ),
        const SizedBox(height: 16),

        // القسم 2: المنتجات والمحتوى
        _buildSectionCard(
          context,
          icon: Icons.inventory_2_outlined,
          iconColor: Colors.orange,
          title: '2. المنتجات والمحتوى',
          content: '''
• يجب أن تكون جميع المنتجات المعروضة قانونية ومطابقة للمواصفات
• أنت مسؤول عن دقة أوصاف المنتجات والصور والأسعار
• يحظر عرض منتجات مزيفة أو مضللة أو محظورة قانونياً
• يجب تحديث معلومات المخزون بشكل منتظم
• نحتفظ بالحق في إزالة أي منتج يخالف سياساتنا''',
        ),
        const SizedBox(height: 16),

        // القسم 3: الطلبات والمعاملات
        _buildSectionCard(
          context,
          icon: Icons.shopping_cart_outlined,
          iconColor: Colors.green,
          title: '3. الطلبات والمعاملات',
          content: '''
• يجب عليك تأكيد أو رفض الطلبات خلال 24 ساعة
• يجب تحضير الطلبات المؤكدة في الوقت المحدد
• أنت مسؤول عن جودة وسلامة المنتجات المباعة
• يجب التعامل مع شكاوى العملاء بطريقة احترافية
• الأسعار المعروضة هي نهائية ولا يمكن تغييرها بعد تأكيد الطلب''',
        ),
        const SizedBox(height: 16),

        // القسم 4: الدفع والعمولات
        _buildSectionCard(
          context,
          icon: Icons.payment_outlined,
          iconColor: Colors.purple,
          title: '4. الدفع والعمولات',
          content: '''
• تطبق عمولة المنصة على جميع المبيعات (راجع سياسة العمولات)
• يتم تحويل الأرباح إلى محفظتك بعد إتمام التوصيل
• يمكنك سحب الأرباح عند الوصول للحد الأدنى (500 ج.م)
• قد تستغرق عمليات السحب 3-5 أيام عمل
• أي رسوم بنكية أو تحويل يتحملها التاجر''',
        ),
        const SizedBox(height: 16),

        // القسم 5: المسؤوليات والالتزامات
        _buildSectionCard(
          context,
          icon: Icons.gavel_outlined,
          iconColor: Colors.red,
          title: '5. المسؤوليات والالتزامات',
          content: '''
• الالتزام بجميع القوانين المحلية والوطنية
• توفير خدمة عملاء عالية الجودة
• الرد على استفسارات العملاء في الوقت المناسب
• حل المشكلات والشكاوى بطريقة عادلة
• عدم انتهاك حقوق الملكية الفكرية للآخرين''',
        ),
        const SizedBox(height: 16),

        // القسم 6: إنهاء الخدمة
        _buildSectionCard(
          context,
          icon: Icons.exit_to_app_outlined,
          iconColor: Colors.grey,
          title: '6. إنهاء الخدمة',
          content: '''
• يمكنك إغلاق حسابك في أي وقت
• يحق لنا إنهاء حسابك في حالة انتهاك الشروط
• عند إنهاء الحساب، يتم تسوية جميع المعاملات المعلقة
• لا يمكن استرداد الرسوم المدفوعة مسبقاً
• يجب إكمال جميع الطلبات المعلقة قبل الإغلاق''',
        ),
        const SizedBox(height: 16),

        // تحديث الشروط
        _buildInfoBox(
          context,
          'نحتفظ بالحق في تحديث هذه الشروط في أي وقت. سيتم إشعارك بأي تغييرات جوهرية.',
          Icons.update_outlined,
        ),

        const SizedBox(height: 24),
        Text(
          'آخر تحديث: فبراير 2026',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ===== تبويب سياسة الخصوصية =====
class _PrivacyPolicyTab extends StatelessWidget {
  const _PrivacyPolicyTab();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // مقدمة
        _buildSectionCard(
          context,
          icon: Icons.privacy_tip_outlined,
          iconColor: colorScheme.primary,
          title: 'التزامنا بخصوصيتك',
          content:
              'نحن في Ell Tall Market نحترم خصوصيتك ونلتزم بحماية بياناتك الشخصية. توضح هذه السياسة كيفية جمع واستخدام وحماية معلوماتك.',
        ),
        const SizedBox(height: 16),

        // القسم 1: البيانات المجمعة
        _buildSectionCard(
          context,
          icon: Icons.folder_outlined,
          iconColor: Colors.blue,
          title: '1. البيانات التي نجمعها',
          content: '''
• معلومات الحساب: الاسم، البريد الإلكتروني، رقم الهاتف
• معلومات المتجر: اسم المتجر، العنوان، ساعات العمل
• المعلومات المالية: بيانات الحساب البنكي للتحويلات
• بيانات المعاملات: تفاصيل الطلبات والمبيعات
• البيانات الفنية: عنوان IP، نوع الجهاز، سجل الاستخدام''',
        ),
        const SizedBox(height: 16),

        // القسم 2: استخدام البيانات
        _buildSectionCard(
          context,
          icon: Icons.settings_applications_outlined,
          iconColor: Colors.orange,
          title: '2. كيف نستخدم بياناتك',
          content: '''
• تقديم وإدارة خدمات المنصة
• معالجة الطلبات والمدفوعات
• التواصل معك بشأن حسابك والطلبات
• تحسين خدماتنا وتجربة المستخدم
• الامتثال للمتطلبات القانونية والتنظيمية
• إرسال إشعارات تسويقية (يمكنك إلغاء الاشتراك)''',
        ),
        const SizedBox(height: 16),

        // القسم 3: مشاركة البيانات
        _buildSectionCard(
          context,
          icon: Icons.share_outlined,
          iconColor: Colors.green,
          title: '3. مشاركة البيانات',
          content: '''
• مع العملاء: معلومات المتجر والمنتجات
• مع السائقين: معلومات الطلب والموقع
• مع بوابات الدفع: معلومات الدفع اللازمة
• مع السلطات: عند الطلب القانوني
• لا نبيع بياناتك الشخصية لأطراف ثالثة''',
        ),
        const SizedBox(height: 16),

        // القسم 4: أمان البيانات
        _buildSectionCard(
          context,
          icon: Icons.security_outlined,
          iconColor: Colors.purple,
          title: '4. حماية بياناتك',
          content: '''
• استخدام تشفير SSL/TLS لجميع الاتصالات
• تخزين البيانات على خوادم آمنة ومحمية
• مراجعة أمنية منتظمة للأنظمة
• تقييد الوصول إلى البيانات الشخصية
• سياسات قوية لحماية كلمات المرور''',
        ),
        const SizedBox(height: 16),

        // القسم 5: حقوقك
        _buildSectionCard(
          context,
          icon: Icons.account_circle_outlined,
          iconColor: Colors.red,
          title: '5. حقوقك',
          content: '''
• الوصول إلى بياناتك الشخصية ومراجعتها
• طلب تصحيح البيانات غير الدقيقة
• طلب حذف بياناتك (مع مراعاة الالتزامات القانونية)
• الاعتراض على معالجة بياناتك
• طلب نقل بياناتك إلى خدمة أخرى
• سحب الموافقة على استخدام البيانات''',
        ),
        const SizedBox(height: 16),

        // القسم 6: ملفات تعريف الارتباط
        _buildSectionCard(
          context,
          icon: Icons.cookie_outlined,
          iconColor: Colors.brown,
          title: '6. ملفات تعريف الارتباط (Cookies)',
          content: '''
• نستخدم ملفات تعريف الارتباط لتحسين تجربتك
• ملفات تعريف الارتباط الأساسية: ضرورية لعمل المنصة
• ملفات تعريف الارتباط التحليلية: لفهم كيفية استخدام المنصة
• يمكنك التحكم في إعدادات ملفات تعريف الارتباط من متصفحك''',
        ),
        const SizedBox(height: 16),

        // القسم 7: الاحتفاظ بالبيانات
        _buildSectionCard(
          context,
          icon: Icons.schedule_outlined,
          iconColor: Colors.teal,
          title: '7. الاحتفاظ بالبيانات',
          content: '''
• نحتفظ بالبيانات طالما كان حسابك نشطاً
• بعد إغلاق الحساب، نحتفظ بالبيانات للامتثال القانوني
• البيانات المالية: 7 سنوات (حسب القانون المصري)
• بيانات التواصل: 3 سنوات بعد آخر تفاعل
• يمكنك طلب حذف البيانات في أي وقت''',
        ),
        const SizedBox(height: 16),

        // تحديث السياسة
        _buildInfoBox(
          context,
          'قد نقوم بتحديث هذه السياسة من وقت لآخر. سنخطرك بأي تغييرات مهمة عبر البريد الإلكتروني أو إشعار في المنصة.',
          Icons.update_outlined,
        ),

        const SizedBox(height: 24),
        Text(
          'آخر تحديث: فبراير 2026',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ===== تبويب سياسة العمولات =====
class _CommissionPolicyTab extends StatelessWidget {
  const _CommissionPolicyTab();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // مقدمة
        _buildSectionCard(
          context,
          icon: Icons.percent_outlined,
          iconColor: colorScheme.primary,
          title: 'نظام العمولات الشفاف',
          content:
              'نتقاضى عمولة عادلة على المبيعات لتغطية تكاليف التشغيل والتطوير. نلتزم بالشفافية الكاملة في جميع الرسوم.',
        ),
        const SizedBox(height: 16),

        // هيكل العمولات
        _buildHighlightCard(
          context,
          icon: Icons.account_balance_wallet_outlined,
          iconColor: Colors.green,
          title: 'هيكل العمولات',
          child: Column(
            children: [
              _buildCommissionRow(
                context,
                'عمولة المنصة الأساسية',
                '10%',
                'من قيمة كل طلب',
              ),
              const Divider(height: 24),
              _buildCommissionRow(
                context,
                'الحد الأدنى للعمولة',
                '5 ج.م',
                'للطلبات الصغيرة',
              ),
              const Divider(height: 24),
              _buildCommissionRow(
                context,
                'الحد الأقصى للعمولة',
                '200 ج.م',
                'للطلبات الكبيرة',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // القسم 1: احتساب العمولة
        _buildSectionCard(
          context,
          icon: Icons.calculate_outlined,
          iconColor: Colors.blue,
          title: '1. كيف يتم احتساب العمولة',
          content: '''
• العمولة = 10% من قيمة الطلب (بعد أي خصومات)
• إذا كانت العمولة أقل من 5 ج.م، يتم احتساب 5 ج.م
• إذا كانت العمولة أكثر من 200 ج.م، يتم احتساب 200 ج.م فقط
• لا يتم احتساب عمولة على رسوم التوصيل
• العمولة تخصم تلقائياً عند تحويل الأرباح''',
        ),
        const SizedBox(height: 16),

        // مثال توضيحي
        _buildExampleCard(context, 'مثال توضيحي', [
          {'label': 'قيمة الطلب', 'value': '300 ج.م'},
          {'label': 'الخصم (كوبون)', 'value': '- 30 ج.م'},
          {'label': 'القيمة بعد الخصم', 'value': '270 ج.م'},
          {'label': 'عمولة المنصة (10%)', 'value': '- 27 ج.م'},
          {'label': 'رسوم التوصيل', 'value': '25 ج.م'},
          {'label': 'صافي ربح التاجر', 'value': '243 ج.م', 'highlight': true},
        ]),
        const SizedBox(height: 16),

        // القسم 2: توقيت الدفع
        _buildSectionCard(
          context,
          icon: Icons.schedule_outlined,
          iconColor: Colors.orange,
          title: '2. متى يتم الدفع',
          content: '''
• يتم تحويل الأرباح إلى محفظتك بعد إتمام التوصيل
• تظهر الأرباح في محفظتك خلال 24 ساعة من التوصيل
• يمكنك طلب سحب الأموال عند الوصول للحد الأدنى (500 ج.م)
• عمليات السحب تتم خلال 3-5 أيام عمل
• لا توجد رسوم إضافية على السحب''',
        ),
        const SizedBox(height: 16),

        // القسم 3: الطلبات الملغاة
        _buildSectionCard(
          context,
          icon: Icons.cancel_outlined,
          iconColor: Colors.red,
          title: '3. الطلبات الملغاة',
          content: '''
• لا يتم احتساب عمولة على الطلبات الملغاة من العميل
• إذا ألغى التاجر الطلب بدون سبب وجيه، تطبق عمولة 50%
• الإلغاء المتكرر قد يؤدي لتعليق الحساب
• يمكنك إلغاء الطلب خلال 5 دقائق بدون عقوبة
• الطلبات الملغاة بسبب عدم توفر المنتج: بدون عمولة''',
        ),
        const SizedBox(height: 16),

        // القسم 4: المرتجعات والاسترداد
        _buildSectionCard(
          context,
          icon: Icons.keyboard_return_outlined,
          iconColor: Colors.purple,
          title: '4. المرتجعات والاسترداد',
          content: '''
• في حالة استرداد المبلغ للعميل، يتم رد العمولة للتاجر
• الاستردادات الجزئية: يتم احتساب العمولة على المبلغ النهائي
• عمليات الاسترداد تتم خلال 7-14 يوم عمل
• يتم خصم أي رسوم معالجة من المبلغ المسترد
• يجب أن يكون سبب الإرجاع مبرراً وموثقاً''',
        ),
        const SizedBox(height: 16),

        // القسم 5: الخصومات والعروض
        _buildSectionCard(
          context,
          icon: Icons.local_offer_outlined,
          iconColor: Colors.teal,
          title: '5. الخصومات والعروض',
          content: '''
• العمولة تحتسب على السعر بعد تطبيق الخصم
• خصومات المتجر: يتحمل التاجر قيمة الخصم بالكامل
• خصومات المنصة: تتحمل المنصة جزءاً من الخصم
• الكوبونات الترويجية: حسب الاتفاق مع المنصة
• العروض الموسمية: قد تطبق عمولات خاصة''',
        ),
        const SizedBox(height: 16),

        // القسم 6: خطط التجار المميزين
        _buildHighlightCard(
          context,
          icon: Icons.workspace_premium_outlined,
          iconColor: Colors.amber,
          title: 'خطط التجار المميزين (قريباً)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'نعمل على إطلاق خطط عضوية مميزة بعمولات مخفضة:',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              _buildFeatureRow(
                context,
                'الخطة الفضية',
                '8%',
                'من 5,000 ج.م شهرياً',
              ),
              _buildFeatureRow(
                context,
                'الخطة الذهبية',
                '6%',
                'من 15,000 ج.م شهرياً',
              ),
              _buildFeatureRow(
                context,
                'الخطة البلاتينية',
                '5%',
                'من 30,000 ج.م شهرياً',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // معلومات إضافية
        _buildInfoBox(
          context,
          'نحتفظ بالحق في تعديل هيكل العمولات مع إشعار مسبق 30 يوماً. سيتم إخطار جميع التجار بأي تغييرات.',
          Icons.info_outlined,
        ),

        const SizedBox(height: 16),

        // أسئلة شائعة
        _buildSectionCard(
          context,
          icon: Icons.help_outline,
          iconColor: Colors.indigo,
          title: 'أسئلة شائعة',
          content: '''
س: هل يمكنني التفاوض على العمولة؟
ج: التجار ذوو المبيعات العالية يمكنهم التواصل معنا لخطط خاصة.

س: متى يتم خصم العمولة؟
ج: تخصم تلقائياً عند تحويل الأرباح لمحفظتك.

س: هل توجد رسوم مخفية؟
ج: لا، نحن ملتزمون بالشفافية الكاملة في جميع الرسوم.''',
        ),

        const SizedBox(height: 24),
        Text(
          'آخر تحديث: فبراير 2026',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCommissionRow(
    BuildContext context,
    String label,
    String value,
    String description,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: textTheme.headlineSmall?.copyWith(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(
    BuildContext context,
    String plan,
    String commission,
    String requirement,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
                children: [
                  TextSpan(
                    text: '$plan: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: '$commission عمولة ',
                    style: TextStyle(color: Colors.green),
                  ),
                  TextSpan(text: '($requirement)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Shared Widget Builders =====

Widget _buildSectionCard(
  BuildContext context, {
  required IconData icon,
  required Color iconColor,
  required String title,
  required String content,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;

  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildHighlightCard(
  BuildContext context, {
  required IconData icon,
  required Color iconColor,
  required String title,
  required Widget child,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;

  return Card(
    elevation: 2,
    shadowColor: iconColor.withValues(alpha: 0.2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: iconColor.withValues(alpha: 0.3), width: 2),
    ),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [iconColor.withValues(alpha: 0.05), colorScheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

Widget _buildExampleCard(
  BuildContext context,
  String title,
  List<Map<String, dynamic>> items,
) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;

  return Card(
    elevation: 0,
    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final isHighlight = item['highlight'] == true;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['label'],
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: isHighlight ? FontWeight.bold : null,
                      color: isHighlight
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    item['value'],
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isHighlight ? Colors.green : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ),
  );
}

Widget _buildInfoBox(BuildContext context, String text, IconData icon) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colorScheme.primary, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}
