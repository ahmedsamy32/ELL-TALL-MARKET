import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ell_tall_market/screens/merchant/merchant_policies_screen.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class MerchantHelpScreen extends StatelessWidget {
  const MerchantHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('المساعدة والدعم'), centerTitle: true),
      body: ResponsiveCenter(
        maxWidth: 700,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // بطاقة الاتصال بالدعم
              _buildContactCard(colorScheme, textTheme),
              const SizedBox(height: 16),

              // الأسئلة الشائعة
              _buildSectionTitle('الأسئلة الشائعة', textTheme, colorScheme),
              const SizedBox(height: 8),
              _buildFAQSection(colorScheme, textTheme),
              const SizedBox(height: 24),

              // دليل سريع
              _buildSectionTitle('دليل سريع', textTheme, colorScheme),
              const SizedBox(height: 8),
              _buildQuickGuideSection(colorScheme, textTheme),
              const SizedBox(height: 24),

              // الشروط والسياسات
              _buildSectionTitle('الشروط والسياسات', textTheme, colorScheme),
              const SizedBox(height: 8),
              _buildPoliciesSection(context, colorScheme, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Text(
      title,
      style: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildContactCard(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.support_agent_rounded,
              size: 64,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'تواصل معنا',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'فريق الدعم الفني متاح لمساعدتك',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildContactButton(
              'واتساب',
              Icons.chat,
              colorScheme.primary,
              () => _launchWhatsApp(),
            ),
            const SizedBox(height: 12),
            _buildContactButton(
              'البريد الإلكتروني',
              Icons.email_outlined,
              colorScheme.secondary,
              () => _launchEmail(),
            ),
            const SizedBox(height: 12),
            _buildContactButton(
              'اتصل بنا',
              Icons.phone,
              colorScheme.tertiary,
              () => _launchPhone(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ساعات العمل: 9 صباحاً - 10 مساءً',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFAQSection(ColorScheme colorScheme, TextTheme textTheme) {
    final faqs = [
      {
        'question': 'كيف أضيف منتج جديد؟',
        'answer':
            'اضغط على "إضافة منتج" من القائمة الجانبية، املأ البيانات المطلوبة (الاسم، السعر، الوصف، الصورة)، ثم اضغط حفظ.',
      },
      {
        'question': 'كيف أدير الطلبات؟',
        'answer':
            'انتقل إلى تبويب "الطلبات" من الشريط السفلي. يمكنك الموافقة على الطلبات الجديدة وتحديث حالتها حتى التوصيل.',
      },
      {
        'question': 'كيف أسحب أرباحي؟',
        'answer':
            'افتح "المحفظة" من القائمة الجانبية، اضغط على "سحب الأرباح"، أدخل المبلغ ومعلومات الحساب البنكي.',
      },
      {
        'question': 'كيف أنشئ كوبون خصم؟',
        'answer':
            'افتح "الكوبونات" من القائمة الجانبية، اضغط "إضافة كوبون"، حدد نوع الخصم والمدة والشروط.',
      },
      {
        'question': 'كيف أتابع إحصائيات المبيعات؟',
        'answer':
            'افتح تبويب "التقارير" من الشريط السفلي لرؤية المبيعات اليومية، المنتجات الأكثر مبيعاً، والأرباح.',
      },
    ];

    return Column(
      children: faqs
          .map(
            (faq) => _buildFAQItem(
              faq['question']!,
              faq['answer']!,
              colorScheme,
              textTheme,
            ),
          )
          .toList(),
    );
  }

  Widget _buildFAQItem(
    String question,
    String answer,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.help_outline,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          title: Text(
            question,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          children: [
            Text(
              answer,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickGuideSection(ColorScheme colorScheme, TextTheme textTheme) {
    final guides = [
      {
        'icon': Icons.inventory_2_outlined,
        'title': 'إدارة المنتجات',
        'description': 'أضف، عدل، أو احذف منتجات متجرك بسهولة',
      },
      {
        'icon': Icons.shopping_cart_outlined,
        'title': 'معالجة الطلبات',
        'description': 'راجع وأدر طلبات العملاء بكفاءة',
      },
      {
        'icon': Icons.local_offer_outlined,
        'title': 'العروض والخصومات',
        'description': 'أنشئ كوبونات لجذب المزيد من العملاء',
      },
      {
        'icon': Icons.bar_chart_outlined,
        'title': 'تتبع الأداء',
        'description': 'راقب مبيعاتك وإيراداتك في التقارير',
      },
    ];

    return Column(
      children: guides
          .map(
            (guide) => _buildGuideCard(
              guide['icon'] as IconData,
              guide['title'] as String,
              guide['description'] as String,
              colorScheme,
              textTheme,
            ),
          )
          .toList(),
    );
  }

  Widget _buildGuideCard(
    IconData icon,
    String title,
    String description,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colorScheme.secondary),
        ),
        title: Text(
          title,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            description,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoliciesSection(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final policies = [
      {
        'icon': Icons.description_outlined,
        'title': 'شروط الاستخدام',
        'subtitle': 'اقرأ شروط استخدام المنصة للتجار',
        'tab': 0,
      },
      {
        'icon': Icons.privacy_tip_outlined,
        'title': 'سياسة الخصوصية',
        'subtitle': 'تعرف على كيفية حماية بياناتك',
        'tab': 1,
      },
      {
        'icon': Icons.payments_outlined,
        'title': 'سياسة العمولات',
        'subtitle': 'تفاصيل العمولات ورسوم المعاملات',
        'tab': 2,
      },
    ];

    return Column(
      children: policies
          .map(
            (policy) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Icon(
                  policy['icon'] as IconData,
                  color: colorScheme.primary,
                ),
                title: Text(
                  policy['title'] as String,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    policy['subtitle'] as String,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MerchantPoliciesScreen(
                        initialTab: policy['tab'] as int,
                      ),
                    ),
                  );
                },
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _launchWhatsApp() async {
    // رقم واتساب الدعم الفني
    final Uri whatsappUri = Uri.parse('https://wa.me/201234567890');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@elltallmarket.com',
      query: 'subject=استفسار من تطبيق التاجر',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _launchPhone() async {
    final Uri phoneUri = Uri.parse('tel:+201234567890');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }
}
