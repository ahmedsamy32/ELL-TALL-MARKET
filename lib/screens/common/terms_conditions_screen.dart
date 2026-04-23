import 'package:flutter/material.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: ResponsiveCenter(
          maxWidth: 700,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── App Bar ──
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                stretch: true,
                backgroundColor: AppColors.primary,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.primary, Color(0xFF1A4FA0)],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.gavel_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'الشروط والأحكام',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'آخر تحديث: 1 فبراير 2026',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Body Content ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Important notice
                      _buildNoticeCard(
                        'باستخدامك لتطبيق "سوق التل" فإنك توافق على الالتزام بهذه الشروط والأحكام. يرجى قراءتها بعناية قبل استخدام خدماتنا.',
                      ),
                      const SizedBox(height: 20),

                      _buildTermSection(
                        context,
                        number: '1',
                        title: 'التعريفات',
                        content:
                            'في هذه الشروط والأحكام، تشير المصطلحات التالية إلى:',
                        bulletPoints: [
                          '"التطبيق": تطبيق سوق التل للهواتف المحمولة.',
                          '"الخدمة": جميع الخدمات المقدمة عبر التطبيق بما في ذلك البيع والتوصيل.',
                          '"المستخدم": أي شخص يقوم بتسجيل حساب واستخدام التطبيق.',
                          '"التاجر": أي بائع مسجل يعرض منتجاته عبر التطبيق.',
                          '"الكابتن": مسؤول التوصيل المعتمد لدينا.',
                          '"نحن" أو "الشركة": إدارة تطبيق سوق التل.',
                        ],
                      ),

                      _buildTermSection(
                        context,
                        number: '2',
                        title: 'شروط الاستخدام',
                        content: '',
                        bulletPoints: [
                          'يجب أن يكون عمرك 18 عامًا على الأقل لاستخدام التطبيق.',
                          'يجب تقديم معلومات صحيحة ودقيقة عند التسجيل.',
                          'أنت مسؤول عن الحفاظ على سرية بيانات حسابك.',
                          'يُحظر استخدام التطبيق لأي أغراض غير قانونية.',
                          'يُحظر إنشاء أكثر من حساب لنفس الشخص.',
                          'يجب الالتزام بالقوانين المحلية السارية عند استخدام الخدمة.',
                        ],
                      ),

                      _buildTermSection(
                        context,
                        number: '3',
                        title: 'الطلبات والشراء',
                        content: '',
                        bulletPoints: [
                          'جميع الأسعار المعروضة بالجنيه المصري وتشمل الضريبة (إن وجدت).',
                          'يحق لنا رفض أو إلغاء أي طلب لأسباب مشروعة.',
                          'يتم تأكيد الطلب بعد التحقق من توفر المنتج وصحة البيانات.',
                          'قد تختلف الأسعار وتوفر المنتجات دون إشعار مسبق.',
                          'رسوم التوصيل تُحسب حسب المنطقة وحجم الطلب ويتم عرضها قبل التأكيد.',
                        ],
                      ),

                      _buildTermSection(
                        context,
                        number: '4',
                        title: 'التوصيل',
                        content: '',
                        bulletPoints: [
                          'نسعى لتوصيل الطلبات في الوقت المحدد، لكن قد تحدث تأخيرات بسبب ظروف خارجة عن إرادتنا.',
                          'يجب أن يكون عنوان التوصيل ضمن نطاق الخدمة.',
                          'يجب تواجد المستلم في العنوان المحدد وقت التوصيل.',
                          'في حال عدم تواجد المستلم، سيتم محاولة التواصل وقد يتم إرجاع الطلب.',
                          'لا نتحمل مسؤولية التأخير الناتج عن بيانات توصيل خاطئة.',
                        ],
                      ),

                      _buildTermSection(
                        context,
                        number: '5',
                        title: 'المدفوعات',
                        content: '',
                        bulletPoints: [
                          'نقبل الدفع عند الاستلام والدفع الإلكتروني.',
                          'جميع المعاملات المالية مشفرة وآمنة.',
                          'في حال فشل الدفع الإلكتروني، قد يتم إلغاء الطلب تلقائيًا.',
                          'لا نحتفظ ببيانات بطاقات الدفع الخاصة بك على خوادمنا.',
                        ],
                      ),

                      _buildTermSection(
                        context,
                        number: '6',
                        title: 'حقوق الملكية الفكرية',
                        content:
                            'جميع المحتويات المعروضة في التطبيق بما في ذلك النصوص والصور والشعارات والتصميمات هي ملكية حصرية لسوق التل أو مرخصة لنا. يُحظر نسخ أو إعادة إنتاج أو توزيع أي محتوى دون إذن كتابي مسبق.',
                      ),

                      _buildTermSection(
                        context,
                        number: '7',
                        title: 'المسؤولية والضمانات',
                        content: '',
                        bulletPoints: [
                          'نسعى لضمان دقة المعلومات المعروضة لكن لا نضمن خلوها من الأخطاء.',
                          'التاجر مسؤول عن جودة المنتجات المعروضة ومطابقتها للوصف.',
                          'لا نتحمل مسؤولية الأضرار غير المباشرة الناتجة عن استخدام الخدمة.',
                          'نحتفظ بالحق في تعليق أو إنهاء حسابك في حال مخالفة الشروط.',
                        ],
                      ),

                      _buildTermSection(
                        context,
                        number: '8',
                        title: 'الكوبونات والعروض',
                        content: '',
                        bulletPoints: [
                          'الكوبونات لها تاريخ صلاحية محدد ولا يمكن تمديده.',
                          'لا يمكن الجمع بين أكثر من كوبون في طلب واحد إلا إذا ذُكر خلاف ذلك.',
                          'يحق لنا إلغاء أي كوبون أو عرض في أي وقت.',
                          'الكوبونات غير قابلة للتحويل أو الاستبدال النقدي.',
                        ],
                      ),

                      _buildTermSection(
                        context,
                        number: '9',
                        title: 'تعديل الشروط والأحكام',
                        content:
                            'نحتفظ بالحق في تعديل هذه الشروط والأحكام في أي وقت. سيتم إخطارك بأي تغييرات جوهرية عبر التطبيق أو البريد الإلكتروني. استمرارك في استخدام الخدمة بعد التعديل يعني موافقتك على الشروط الجديدة.',
                      ),

                      _buildTermSection(
                        context,
                        number: '10',
                        title: 'القانون الحاكم',
                        content:
                            'تخضع هذه الشروط والأحكام لقوانين جمهورية مصر العربية. أي نزاع ينشأ عن استخدام الخدمة يخضع لاختصاص المحاكم المصرية المختصة.',
                      ),

                      _buildTermSection(
                        context,
                        number: '11',
                        title: 'التواصل والاستفسارات',
                        content:
                            'لأي أسئلة أو استفسارات حول هذه الشروط والأحكام:\n\n📧 البريد الإلكتروني: legal@elltall.com\n📞 الهاتف: +20 123 456 7890\n🏢 العنوان: التل الكبير - مصر',
                      ),

                      const SizedBox(height: 24),

                      // Acceptance note
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppColors.accent,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'باستخدامك للتطبيق فإنك تقر بقراءة وفهم وموافقتك على جميع الشروط والأحكام المذكورة أعلاه.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontFamily: 'Cairo',
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Notice Card ──
  Widget _buildNoticeCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                fontFamily: 'Cairo',
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Term Section ──
  Widget _buildTermSection(
    BuildContext context, {
    required String number,
    required String title,
    required String content,
    List<String>? bulletPoints,
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
        ],
      ),
    );
  }
}
