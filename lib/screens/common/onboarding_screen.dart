import 'package:flutter/material.dart';
import 'package:ell_tall_market/utils/app_routes.dart';

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
      'title': 'مرحباً بك في التل ماركت',
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

  void _goToHome() {
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
        ),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _onboardingData.length,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemBuilder: (context, index) {
                return OnboardingPage(
                  title: _onboardingData[index]['title']!,
                  description: _onboardingData[index]['description']!,
                  image: _onboardingData[index]['image']!,
                );
              },
            ),

            // الأزرار في أسفل الصفحة
            Positioned(
              bottom: 50, // المسافة من الأسفل
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // زر التخطي (يظهر في جميع الصفحات عدا الأخيرة)
                    if (_currentPage < _onboardingData.length - 1)
                      _buildCircleButton(
                        text: 'تخطي',
                        onPressed: _goToHome,
                      )
                    else
                      const SizedBox(width: 70), // مساحة فارغة للحفاظ على التنسيق

                    // نقاط التقدم
                    Row(
                      children: List.generate(
                        _onboardingData.length,
                            (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withAlpha(128), // Changed from withOpacity(0.5)
                          ),
                        ),
                      ),
                    ),

                    // زر التالي أو ابدأ الآن
                    _buildCircleButton(
                      text: _currentPage < _onboardingData.length - 1 ? 'التالي' : 'ابدأ الآن',
                      onPressed: () {
                        if (_currentPage < _onboardingData.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn,
                          );
                        } else {
                          _goToHome();
                        }
                      },
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

  // دالة لبناء الأزرار الدائرية
  Widget _buildCircleButton({required String text, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(128), // Changed from withOpacity(0.5)
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 70,
            height: 70,
            alignment: Alignment.center,
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
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
        Image.asset(
          image,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),

        // طبقة تظليل
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(51),  // Changed from withOpacity(0.2)
                Colors.black.withAlpha(153), // Changed from withOpacity(0.6)
              ],
            ),
          ),
        ),

        // المحتوى (النصوص)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}