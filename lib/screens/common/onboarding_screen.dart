import 'package:flutter/material.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  OnboardingScreenState createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'مرحباً بك في سوق التل',
      'description': 'منصة تسوق متكاملة تقدم لك أفضل المنتجات بأفضل الأسعار',
      'image': 'assets/images/onboarding1.jpg',
    },
    {
      'title': 'تسوق بسهولة',
      'description': 'تصفح الآلاف من المنتجات وأضفها إلى سلة التسوق بضغطة زر',
      'image': 'assets/images/onboarding2.jpg',
    },
    {
      'title': 'توصيل سريع',
      'description': 'استلم طلباتك في أسرع وقت مع خدمة التوصيل المميزة',
      'image': 'assets/images/onboarding3.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    // تحميل الصور مسبقاً لتسريع العرض
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var data in _onboardingData) {
        precacheImage(AssetImage(data['image']!), context);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToHome() {
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // ويب layout للشاشات الكبيرة
    if (screenWidth > 800) {
      return _buildWebLayout();
    }

    // موبايل layout
    return _buildMobileLayout();
  }

  // =====================================================
  // Web Layout - Two Column
  // =====================================================
  Widget _buildWebLayout() {
    final title = _onboardingData[_currentPage]['title']!;
    final description = _onboardingData[_currentPage]['description']!;
    final image = _onboardingData[_currentPage]['image']!;
    return Scaffold(
      body: Row(
        children: [
          // الصورة - اليسار
          Expanded(child: Image.asset(image, fit: BoxFit.cover)),
          // النص والأزرار - اليمين
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 60),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A237E),
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Color(0xFF718096),
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // نقاط التقدم والأزرار
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // زر السابق
                          if (_currentPage > 0)
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _currentPage--;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFF1A237E),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'السابق',
                                    style: TextStyle(
                                      color: Color(0xFF1A237E),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 80),
                          const SizedBox(width: 24),
                          // نقاط التقدم
                          Row(
                            children: List.generate(
                              _onboardingData.length,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentPage == index
                                      ? const Color(0xFF1A237E)
                                      : const Color(
                                          0xFF1A237E,
                                        ).withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          // زر التالي أو ابدأ الآن
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                if (_currentPage < _onboardingData.length - 1) {
                                  setState(() {
                                    _currentPage++;
                                  });
                                } else {
                                  _goToHome();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A237E),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _currentPage < _onboardingData.length - 1
                                      ? 'التالي'
                                      : 'ابدأ الآن',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
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
    );
  }

  // =====================================================
  // Mobile Layout - PageView
  // =====================================================
  Widget _buildMobileLayout() {
    return Scaffold(
      body: Stack(
        children: [
          // صور الـ PageView
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _onboardingData.length,
            itemBuilder: (context, index) => OnboardingPage(
              title: _onboardingData[index]['title']!,
              description: _onboardingData[index]['description']!,
              image: _onboardingData[index]['image']!,
            ),
          ),
          // الأزرار والنقاط
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // زر التخطي
                    if (_currentPage < _onboardingData.length - 1)
                      GestureDetector(
                        onTap: _goToHome,
                        child: const Text(
                          'تخطي',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    // نقاط التقدم
                    Row(
                      children: List.generate(
                        _onboardingData.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                    // زر التالي
                    GestureDetector(
                      onTap: () {
                        if (_currentPage < _onboardingData.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn,
                          );
                        } else {
                          _goToHome();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _currentPage < _onboardingData.length - 1
                              ? 'التالي'
                              : 'ابدأ الآن',
                          style: const TextStyle(
                            color: Color(0xFF1A237E),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // دالة لبناء الأزرار الدائرية
}

class OnboardingPage extends StatelessWidget {
  final String title;
  final String description;
  final String image;

  const OnboardingPage({
    super.key,
    required this.title,
    required this.description,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // الصورة الخلفية
        Positioned.fill(child: Image.asset(image, fit: BoxFit.cover)),

        // طبقة تظليل
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(51), // Changed from withOpacity(0.2)
                Colors.black.withAlpha(153), // Changed from withOpacity(0.6)
              ],
            ),
          ),
        ),

        // المحتوى (النصوص)
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.responsive(
                    mobile: 20.0,
                    tablet: 40.0,
                    wide: 60.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.responsive(
                          mobile: 32.0,
                          tablet: 40.0,
                          wide: 48.0,
                        ),
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.responsive(
                          mobile: 18.0,
                          tablet: 22.0,
                          wide: 24.0,
                        ),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
