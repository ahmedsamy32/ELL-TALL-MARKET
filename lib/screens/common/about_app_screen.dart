import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class AboutAppScreen extends StatefulWidget {
  const AboutAppScreen({super.key});

  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen> {
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    });
  }

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
              // ── App Bar with gradient ──
              SliverAppBar(
                expandedHeight: 260,
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
                          const SizedBox(height: 20),
                          // App Logo
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/icons/icon.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.storefront_rounded,
                                      size: 50,
                                      color: AppColors.primary,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'سوق التل',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _appVersion.isNotEmpty
                                ? 'الإصدار $_appVersion ($_buildNumber)'
                                : '...',
                            style: TextStyle(
                              fontSize: 14,
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
                      // ── About Description ──
                      _buildSectionCard(
                        context,
                        icon: Icons.info_outline_rounded,
                        title: 'عن التطبيق',
                        child: const Text(
                          'سوق التل هو تطبيقك الأمثل للتسوق الإلكتروني، يوفر لك تجربة تسوق سهلة وممتعة مع مجموعة واسعة من المنتجات من أفضل المتاجر والتجار المحليين. نقدم لك خدمة توصيل سريعة وآمنة حتى باب منزلك.',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.8,
                            color: Color(0xFF555555),
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Features ──
                      _buildSectionCard(
                        context,
                        icon: Icons.star_rounded,
                        title: 'مميزات التطبيق',
                        child: Column(
                          children: [
                            _buildFeatureItem(
                              Icons.shopping_bag_rounded,
                              'تسوق متنوع',
                              'آلاف المنتجات من مختلف الفئات والمتاجر',
                            ),
                            _buildFeatureItem(
                              Icons.local_shipping_rounded,
                              'توصيل سريع',
                              'خدمة توصيل سريعة وموثوقة لجميع المناطق',
                            ),
                            _buildFeatureItem(
                              Icons.security_rounded,
                              'دفع آمن',
                              'طرق دفع متعددة وآمنة لحماية معاملاتك',
                            ),
                            _buildFeatureItem(
                              Icons.discount_rounded,
                              'عروض مستمرة',
                              'خصومات وعروض حصرية على مدار السنة',
                            ),
                            _buildFeatureItem(
                              Icons.support_agent_rounded,
                              'دعم فني',
                              'فريق دعم متاح لمساعدتك في أي وقت',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Legal Links ──
                      _buildSectionCard(
                        context,
                        icon: Icons.gavel_rounded,
                        title: 'القانونية',
                        child: Column(
                          children: [
                            _buildLinkItem(
                              context,
                              icon: Icons.privacy_tip_outlined,
                              title: 'سياسة الخصوصية',
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.privacyPolicy,
                              ),
                            ),
                            Divider(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.3,
                              ),
                              height: 1,
                            ),
                            _buildLinkItem(
                              context,
                              icon: Icons.description_outlined,
                              title: 'الشروط والأحكام',
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.termsConditions,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Contact Info ──
                      _buildSectionCard(
                        context,
                        icon: Icons.contact_support_rounded,
                        title: 'تواصل معنا',
                        child: Column(
                          children: [
                            _buildContactItem(
                              Icons.email_outlined,
                              'البريد الإلكتروني',
                              'support@elltall.com',
                            ),
                            _buildContactItem(
                              Icons.phone_outlined,
                              'الهاتف',
                              '+20 123 456 7890',
                            ),
                            _buildContactItem(
                              Icons.language_rounded,
                              'الموقع الإلكتروني',
                              'www.elltall.com',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Copyright ──
                      Center(
                        child: Column(
                          children: [
                            Text(
                              '© 2026 سوق التل - جميع الحقوق محفوظة',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'صُنع بـ ❤️ في مصر',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                                fontFamily: 'Cairo',
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

  // ── Section Card ──
  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            height: 1,
          ),
          // Content
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  // ── Feature Item ──
  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontFamily: 'Cairo',
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Link Item ──
  Widget _buildLinkItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Contact Item ──
  Widget _buildContactItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.grey, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontFamily: 'Cairo',
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
