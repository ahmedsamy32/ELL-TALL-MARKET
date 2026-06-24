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
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.1),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'الشروط والأحكام',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            centerTitle: true,
            bottom: TabBar(
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
              labelStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.normal,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'العملاء والمستخدمين'),
                Tab(text: 'التجار والمتاجر'),
                Tab(text: 'مكاتب الدليفري'),
              ],
            ),
          ),
          body: TabBarView(
            physics: const BouncingScrollPhysics(),
            children: [
              _buildCustomersTab(context),
              _buildMerchantsTab(context),
              _buildLogisticsTab(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── Customer Tab (Document 2) ──
  Widget _buildCustomersTab(BuildContext context) {
    return ResponsiveCenter(
      maxWidth: 700,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildDocumentHeader(
            title: 'وثيقة رقم (2)',
            subtitle: 'الشروط والأحكام الخاصة بالعملاء والمستخدمين',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),
          _buildNoticeCard(
            'تطبيق "سوق التل" هو منصة إلكترونية وسيطة تربط العميل بالمتاجر المتنوعة ومقدمي خدمات التوصيل داخل مصر.',
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 16),
          _buildArticleCard(
            context,
            articleNumber: '1',
            title: 'حساب المستخدم وبيانات التوصيل',
            paragraphs: [
              'يلتزم العميل بإنشاء حساب حقيقي وتقديم بيانات صحيحة ودقيقة تشمل (الاسم، رقم الهاتف الفعّال، وعنوان التوصيل بالتفصيل).',
              'يتحمل العميل مسؤولية أي تأخير أو فشل في تسليم الأوردر نتيجة خطأ في البيانات.',
            ],
          ),
          _buildArticleCard(
            context,
            articleNumber: '2',
            title: 'سياسة طلب وإلغاء الأوردرات',
            paragraphs: [
              'يحق للعميل إلغاء الطلب مجاناً وبدون أي رسوم طالما لم يقم المتجر بقبوله والبدء في تجهيزه.',
              'في حال إلغاء العميل للأوردر لأسباب شخصية بعد قبول المتجر له وتحرك مندوب الدليفري (الطيار) بالشحنة فعلياً، يحق للتطبيق فرض رسوم توصيل ثابتة (حق مشوار للطيار) تُخصم من حساب العميل أو تُضاف إجبارياً على قيمته الإجمالية في أوردره القادم.',
            ],
          ),
          _buildArticleCard(
            context,
            articleNumber: '3',
            title: 'المرتجعات والمنتجات الطازجة',
            paragraphs: [
              'نظراً للطبيعة الاستهلاككية الخاصة بالمواد الغذائية والمنتجات الطازجة (مثل الخضروات، الفواكه، اللحوم، والمأكولات الساخنة)، لا يحق للعميل طلب إرجاعها أو استبدالها بعد مغادرة المندوب إلا في حال وجود عيب واضح في الجودة أو تلف ظاهر يتم إثباته ومراجعته مع المندوب فوراً وقت التسليم وقبل الاستلام.',
              'بالنسبة للمنتجات غير الاستهلاكية (كالملابس أو الأدوات المنزلية)، تخضع لسياسة الاستبدال والاسترجاع المحددة من قِبل المتجر البائع ووفقاً لقانون حماية المستهلك المصري.',
            ],
          ),
          const SizedBox(height: 16),
          _buildAcceptanceFooter(),
        ],
      ),
    );
  }

  // ── Merchant Tab (Document 1) ──
  Widget _buildMerchantsTab(BuildContext context) {
    return ResponsiveCenter(
      maxWidth: 700,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildDocumentHeader(
            title: 'وثيقة رقم (1)',
            subtitle: 'الشروط والأحكام الخاصة بالتجار والمتاجر الشريكة',
            icon: Icons.storefront_outlined,
          ),
          const SizedBox(height: 16),
          _buildArticleCard(
            context,
            articleNumber: '1',
            title: 'طبيعة الخدمة ونظام العمل المالي',
            paragraphs: [
              'يعتمد تطبيق "سوق التل" في جمهورية مصر العربية على نظام الباقات مسبقة الدفع (Prepaid Wallet). يلتزم التاجر بشحن محفظته الإلكترونية مسبقاً بقيمة الباقة المتفق عليها لتفعيل ظهور متجره على المنصة واستقبال طلبات العملاء.',
              'تنتهي صلاحية الباقة المشترك بها تلقائياً بمرور 30 (ثلاثين) يوماً من تاريخ التفعيل، أو بنفاذ عدد الأوردرات المحدد في الباقة (أيهما أقرب).',
              'في حال نفاذ عدد أوردرات الباقة قبل نهاية مدة الصلاحية (30 يوماً)، يحق للتاجر الاستمرار في استقبال الطلبات بنظام "الأوردر الإضافي" مقابل رسوم ثابتة ومقطوعة تتراوح بين 6 إلى 7 جنيهات عن كل أوردر إضافي، وتُخصم تلقائياً من رصيد محفظته.',
              'يوضع حد أقصى (Cap Limit) لعدد الأوردرات الإضافية المسموح بها؛ وعند تجاوزه، يتم تعليق حساب المتجر إلكترونياً ولا يعاد تفعيله إلا بعد تجديد الباقة أو الترقية للباقة الأعلى.',
              'يحق لإدارة تطبيق "سوق التل" حظر وظهور المتجر فوراً (Hard Block) في حال وصول رصيد محفظة التاجر إلى (صفر جنيه).',
            ],
          ),
          _buildArticleCard(
            context,
            articleNumber: '2',
            title: 'سياسة إلغاء الطلبات ومكافحة التحايل التجاري',
            paragraphs: [
              'يُحظر تماماً على التاجر الشريك تحويل الطلبات الواردة إليه عبر منصة "سوق التل" إلى معاملات خارجية مباشرة مع العميل للتهرب من الرسوم؛ وإذا ثبت ذلك، يحق لإدارة التطبيق حظر حساب المتجر نهائياً واتخاذ الإجراءات القانونية لحفظ حقوقها.',
              'تخضع نسبة إلغاء الأوردرات (Cancellation Rate) من قِبل المتجر للرقابة المستمرة؛ وفي حال تكرار إلغاء الطلبات المقبولة بدون أسباب قهرية تتجاوز النسبة التشغيلية المقبولة، يحق للتطبيق توقيف الحساب للمراجعة.',
              'بمجرد قبول الطلب من قِبل مندوب الدليفري (الطيار) وتحديث حالته على النظام إلى "تم الاستلام من المتجر"، تسقط صلاحية الإلغاء تماماً من لوحة تحكم التاجر، ويُعد الأوردر نافذاً وتُستحق عنه الرسوم.',
            ],
          ),
          _buildArticleCard(
            context,
            articleNumber: '3',
            title: 'أمانة التسعير وجودة المنتجات',
            paragraphs: [
              'يلتزم التاجر بتقديم أسعار حقيقية ومطابقة للسياسة المتفق عليها مع المنصة، ويتحمل وحده مسؤولية أي تضليل في الأسعار قد يضر بالسمعة التجارية للتطبيق.',
              'التاجر هو المسؤول القانوني والجنائي والمدني الأول والوايد عن جودة وصلاحية وسلامة المنتجات المعروضة (خاصة المواد الغذائية والمنتجات الطازجة) أمام الجهات الرقابية الحكومية وأمام المستهلك، دون أدنى مسؤولية على التطبيق.',
            ],
          ),
          const SizedBox(height: 16),
          _buildAcceptanceFooter(),
        ],
      ),
    );
  }

  // ── Logistics Tab (Document 3) ──
  Widget _buildLogisticsTab(BuildContext context) {
    return ResponsiveCenter(
      maxWidth: 700,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildDocumentHeader(
            title: 'وثيقة رقم (3)',
            subtitle: 'اتفاقية شروط تقديم الخدمات اللوجستية (مكاتب الدليفري)',
            icon: Icons.local_shipping_outlined,
          ),
          const SizedBox(height: 16),
          _buildArticleCard(
            context,
            articleNumber: '1',
            title: 'طبيعة التعاقد ونفي الشراكة التجارية',
            paragraphs: [
              'يعتبر هذا الاتفاق عقد "تقديم خدمات لوجستية وتوصيل عند الطلب" (On-Demand Delivery)، والعلاقة بين تطبيق "سوق التل" ومكتب الدليفري (المشار إليه بـ "مقدم الخدمة") هي علاقة بين طرفين مستقلين تماماً (عميل ومُورّد خدمة).',
              'يقر مكتب الدليفري صراحةً بأنه لا يترتب على هذا التعاقد أو تنفيذ الأوردرات أي حق له أو لتابعيه في المطالبة بأي شراكة تجارية، أو حصة، أو أسهم، أو نسبة من أرباح التطبيق أو ملكيته الفكرية.',
              'يحاسب مكتب الدليفري بناءً على رسوم توصيل ثابتة ومقطوعة متفق عليها عن كل أوردر ناجح يتم تسليمه (وفقاً لجدول المناطق والزونات المرفق)، وليس له أي علاقة بقيمة الفاتورة أو حجم مبيعات المنصة.',
            ],
          ),
          _buildArticleCard(
            context,
            articleNumber: '2',
            title: 'مستوى الخدمة والالتزام بالتوقيت (SLA)',
            paragraphs: [
              'يلتزم مكتب الدليفري بنظام "عند الطلب"، ويتعهد بتوجيه أقرب طيار تابع له إلى مقر المتجر المعني خلال مدة زمنية قياسية لا تتجاوز (15 إلى 20 دقيقة) كحد أقصى من وقت إرسال الأوردر عبر السيستم.',
              'يتعهد مقدم الخدمة بتوفير الكثافة العددية اللازمة من الطيارين لتغطية طلبات التطبيق في أوقات الذروة، والمواسم، والأعياد الرسمية، ولا يحق له الاعتذار عن استقبال الطلبات طالما كانت في مواعيد العمل المتفق عليها.',
            ],
          ),
          _buildArticleCard(
            context,
            articleNumber: '3',
            title: 'المسؤولية القانونية والعمالية والمدنية',
            paragraphs: [
              'يعتبر مكتب الدليفري هو المسؤول القانوني والعمالي والفعلي الأول والوحيد عن جميع السائقين والطيارين التابعين له، ويتحمل وحده سداد أجورهم، وتأميناتهم، وضمان استخراج تراخيص قيادتهم وتراخيص مركباتهم وفقاً لقانون المرور المصري، دون أي مسؤولية تبعية على التطبيق.',
            ],
          ),
          _buildArticleCard(
            context,
            articleNumber: '4',
            title: 'سياسة إلغاء الأوردرات أثناء الرحلة',
            paragraphs: [
              'في حال إلغاء الأوردر من قِبل العميل لأي سبب خارج عن إرادة الطيار بعد قيام الطيار باستلام الشحنة والتحرك بها فعلياً، يلتزم التطبيق بدفع قيمة ماليّة رمزية محددة (حق مشوار) لمكتب الدليفري، شريطة أن يلتزم الطيار بإعادة المنتجات بحالتها الأصلية السليمة والطازجة إلى المتجر فوراً ودون أي تأخير.',
            ],
          ),
          _buildArticleCard(
            context,
            articleNumber: '5',
            title: 'سرية البيانات والأمانة التجارية (Non-Circumvention)',
            paragraphs: [
              'يتعهد مكتب الدليفري وكافة الطيارين التابعين له بالحفاظ على السرية التامة لبيانات العملاء والتجار (الأسماء، الهواتف، العناوين) التي تظهر لهم عبر التطبيق، ويُحظر تماماً استغلالها أو تخزينها أو استخدامها لمحاولة التعامل معهم بشكل شخصي أو خارجي بعيداً عن سيستم "سوق التل".',
              'أي خرق لهذا البند يؤدي إلى فسخ التعاقد فوراً مع حق التطبيق في المطالبة بالتعويضات القانونية.',
            ],
          ),
          const SizedBox(height: 16),
          _buildAcceptanceFooter(),
        ],
      ),
    );
  }

  // ── Document Header ──
  Widget _buildDocumentHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF1B4E9B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
              fontFamily: 'Cairo',
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Notice Card ──
  Widget _buildNoticeCard(String text, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.primary,
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

  // ── Article Card ──
  Widget _buildArticleCard(
    BuildContext context, {
    required String articleNumber,
    required String title,
    required List<String> paragraphs,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored side bar
            Container(
              width: 5,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Article Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'مادة ($articleNumber)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Article paragraphs
                    ...paragraphs.map(
                      (paragraph) => Padding(
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
                                paragraph,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Acceptance Footer ──
  Widget _buildAcceptanceFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
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
              fontSize: 13,
              color: Colors.grey[800],
              fontFamily: 'Cairo',
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
