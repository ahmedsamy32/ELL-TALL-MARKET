import 'package:flutter/material.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: const Text(
            'السياسات',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.privacy_tip_outlined, size: 20),
                text: 'سياسة الخصوصية',
              ),
              Tab(
                icon: Icon(Icons.assignment_return_outlined, size: 20),
                text: 'سياسة الاسترجاع',
              ),
            ],
          ),
        ),
        body: ResponsiveCenter(
          maxWidth: 700,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPrivacyPolicyTab(context),
              _buildReturnPolicyTab(context),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // تبويب سياسة الخصوصية
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPrivacyPolicyTab(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        _buildHeaderCard(
          icon: Icons.privacy_tip_rounded,
          title: 'سياسة الخصوصية',
          subtitle: 'آخر تحديث: 1 فبراير 2026',
          color: AppColors.primary,
        ),
        const SizedBox(height: 20),

        _buildPolicySection(
          number: '1',
          title: 'مقدمة',
          content:
              'نحن في "سوق التل" نقدّر خصوصيتك ونلتزم بحماية بياناتك الشخصية. توضح سياسة الخصوصية هذه كيف نجمع معلوماتك ونستخدمها ونحميها عند استخدامك لتطبيقنا وخدماتنا.',
        ),

        _buildPolicySection(
          number: '2',
          title: 'المعلومات التي نجمعها',
          content: '',
          bulletPoints: [
            'معلومات الحساب: الاسم، البريد الإلكتروني، رقم الهاتف، وعنوان التوصيل.',
            'معلومات الطلبات: تفاصيل المشتريات، تاريخ الطلب، وطريقة الدفع.',
            'معلومات الموقع: لتقديم خدمة التوصيل وتحديد نطاق الخدمة.',
            'معلومات الجهاز: نوع الجهاز، نظام التشغيل، ومعرّف الجهاز لتحسين الأداء.',
            'بيانات الاستخدام: كيفية تفاعلك مع التطبيق لتحسين تجربة المستخدم.',
          ],
        ),

        _buildPolicySection(
          number: '3',
          title: 'كيف نستخدم معلوماتك',
          content: '',
          bulletPoints: [
            'معالجة وتنفيذ طلباتك وتوصيلها إليك.',
            'التواصل معك بخصوص طلباتك وحسابك.',
            'تحسين خدماتنا وتطوير ميزات جديدة.',
            'إرسال عروض وتخفيضات مخصصة (بموافقتك).',
            'الحفاظ على أمان التطبيق ومنع الاحتيال.',
            'الامتثال للمتطلبات القانونية والتنظيمية.',
          ],
        ),

        _buildPolicySection(
          number: '4',
          title: 'مشاركة المعلومات',
          content:
              'لا نبيع أو نؤجر معلوماتك الشخصية لأي طرف ثالث. قد نشارك بعض المعلومات الضرورية مع:',
          bulletPoints: [
            'شركاء التوصيل (الكابتن) لإيصال طلبك.',
            'مزودي خدمات الدفع لمعالجة المدفوعات بأمان.',
            'التجار المعنيين بطلبك فقط.',
            'الجهات الحكومية عند الطلب القانوني.',
          ],
        ),

        _buildPolicySection(
          number: '5',
          title: 'حماية البيانات',
          content:
              'نستخدم أحدث تقنيات التشفير والأمان لحماية بياناتك الشخصية. يتم تخزين جميع البيانات على خوادم آمنة مع إجراءات حماية متعددة المستويات.',
        ),

        _buildPolicySection(
          number: '6',
          title: 'حقوقك',
          content: 'لديك الحق في:',
          bulletPoints: [
            'الوصول إلى بياناتك الشخصية وطلب نسخة منها.',
            'تصحيح أو تحديث معلوماتك الشخصية.',
            'طلب حذف حسابك وبياناتك.',
            'إلغاء الاشتراك من الإشعارات التسويقية.',
            'تقييد معالجة بياناتك في حالات معينة.',
          ],
        ),

        _buildPolicySection(
          number: '7',
          title: 'ملفات تعريف الارتباط (Cookies)',
          content:
              'نستخدم ملفات تعريف الارتباط وتقنيات مشابهة لتحسين تجربتك وتقديم محتوى مخصص. يمكنك التحكم في إعدادات ملفات تعريف الارتباط من خلال إعدادات جهازك.',
        ),

        _buildPolicySection(
          number: '8',
          title: 'التواصل معنا',
          content:
              'إذا كان لديك أي أسئلة أو استفسارات حول سياسة الخصوصية، يرجى التواصل معنا عبر:\n\n📧 البريد الإلكتروني: privacy@elltall.com\n📞 الهاتف: +20 123 456 7890',
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // تبويب سياسة الاسترجاع
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildReturnPolicyTab(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        _buildHeaderCard(
          icon: Icons.assignment_return_rounded,
          title: 'سياسة الاسترجاع والاستبدال',
          subtitle: 'آخر تحديث: 1 فبراير 2026',
          color: AppColors.secondary,
        ),
        const SizedBox(height: 20),

        // Important Note
        _buildImportantNote(
          'نحرص في "سوق التل" على رضا عملائنا. إذا لم تكن راضيًا عن مشترياتك، يمكنك الاستفادة من سياسة الاسترجاع والاستبدال الخاصة بنا.',
        ),
        const SizedBox(height: 16),

        _buildPolicySection(
          number: '1',
          title: 'شروط الاسترجاع',
          content: '',
          bulletPoints: [
            'يجب أن يكون المنتج في حالته الأصلية ولم يتم استخدامه.',
            'يجب تقديم طلب الاسترجاع خلال 7 أيام من تاريخ الاستلام.',
            'يجب إرفاق فاتورة الشراء أو رقم الطلب.',
            'يجب أن يكون المنتج في عبوته الأصلية مع جميع الملحقات.',
          ],
        ),

        _buildPolicySection(
          number: '2',
          title: 'المنتجات غير القابلة للاسترجاع',
          content: 'لا يمكن إرجاع المنتجات التالية:',
          bulletPoints: [
            'المنتجات الغذائية القابلة للتلف والمواد سريعة الانتهاء.',
            'المنتجات المخصصة أو المصنعة حسب الطلب.',
            'منتجات العناية الشخصية المفتوحة لأسباب صحية.',
            'المنتجات التي تم استخدامها أو تلفها بعد الاستلام.',
            'البطاقات والقسائم الرقمية بعد تفعيلها.',
          ],
        ),

        _buildPolicySection(
          number: '3',
          title: 'خطوات طلب الاسترجاع',
          content: '',
          numberedPoints: [
            'افتح التطبيق واذهب إلى "طلباتي السابقة".',
            'اختر الطلب الذي تريد إرجاعه.',
            'اضغط على "طلب استرجاع" وحدد سبب الإرجاع.',
            'التقط صورًا واضحة للمنتج وأرفقها مع الطلب.',
            'انتظر مراجعة طلبك من فريقنا خلال 24-48 ساعة.',
            'في حال الموافقة، سيتم ترتيب استلام المنتج أو يمكنك إرساله.',
          ],
        ),

        _buildPolicySection(
          number: '4',
          title: 'سياسة الاستبدال',
          content:
              'يمكنك استبدال المنتج بمنتج آخر بنفس القيمة أو بفرق سعر يتم دفعه أو استرداده. تنطبق نفس شروط الاسترجاع على طلبات الاستبدال.',
        ),

        _buildPolicySection(
          number: '5',
          title: 'طريقة استرداد المبلغ',
          content: '',
          bulletPoints: [
            'الدفع الإلكتروني: يتم الاسترداد إلى نفس وسيلة الدفع خلال 5-10 أيام عمل.',
            'الدفع عند الاستلام: يتم الاسترداد إلى محفظتك في التطبيق أو عبر تحويل بنكي.',
            'رسوم التوصيل: لا يتم استردادها إلا في حالة وجود خطأ من جانبنا.',
          ],
        ),

        _buildPolicySection(
          number: '6',
          title: 'حالات الاسترجاع المجاني',
          content: 'نتحمل تكلفة الإرجاع في الحالات التالية:',
          bulletPoints: [
            'استلام منتج خاطئ أو مختلف عن الطلب.',
            'استلام منتج تالف أو معيب.',
            'عدم مطابقة المنتج للوصف المعروض في التطبيق.',
          ],
        ),

        _buildPolicySection(
          number: '7',
          title: 'التواصل لطلبات الاسترجاع',
          content:
              'لأي استفسارات حول الاسترجاع والاستبدال:\n\n📧 البريد الإلكتروني: returns@elltall.com\n📞 الهاتف: +20 123 456 7890\n⏰ ساعات العمل: من السبت إلى الخميس، 9 صباحًا - 9 مساءً',
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Shared Widgets
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHeaderCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Cairo',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportantNote(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: AppColors.info, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontFamily: 'Cairo',
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection({
    required String number,
    required String title,
    required String content,
    List<String>? bulletPoints,
    List<String>? numberedPoints,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),

          if (content.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontFamily: 'Cairo',
                height: 1.7,
              ),
            ),
          ],

          // Bullet Points
          if (bulletPoints != null) ...[
            const SizedBox(height: 10),
            ...bulletPoints.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontFamily: 'Cairo',
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Numbered Points
          if (numberedPoints != null) ...[
            const SizedBox(height: 10),
            ...numberedPoints.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontFamily: 'Cairo',
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
