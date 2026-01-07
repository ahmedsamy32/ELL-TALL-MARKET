import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ell_tall_market/screens/user/home_screen.dart';
import 'package:ell_tall_market/screens/user/order_history_screen.dart';
import 'package:ell_tall_market/screens/user/favorites_screen.dart';
import 'package:ell_tall_market/screens/user/profile_screen.dart';
import 'package:ell_tall_market/screens/shared/advanced_map_screen.dart';
import 'package:ell_tall_market/widgets/role_based_drawer.dart';
import 'package:ell_tall_market/widgets/notifications_sidebar.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/notification_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/core/logger.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  MainNavigationScreenState createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late PageController _pageController;

  // Keys للتحكم في إعادة بناء الصفحات
  final List<GlobalKey> _pageKeys = [
    GlobalKey(), // Home
    GlobalKey(), // Orders
    GlobalKey(), // Favorites
    GlobalKey(), // Profile
  ];

  // Location state
  String? _currentAddress;
  bool _isLoadingLocation = false;
  LatLng? _selectedPosition;

  // App Colors
  static const Color primaryColor = Color(0xFF6A5AE0);
  static const Color accentColor = Color(0xFFFF9E80);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _getCurrentLocation(); // تحديد الموقع عند بدء التطبيق
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _checkLoginForProtectedTabs(int index) {
    // Remove login requirement for Orders (index 1) and Favorites (index 2)
    // These screens will handle login requirements for specific actions internally
    _onTabTapped(index);
  }

  void _onTabTapped(int index) {
    // إذا الـ tab نفس اللي مفتوح، نعمل refresh
    if (_currentIndex == index) {
      // Refresh the current page
      _refreshCurrentPage();
      return;
    }

    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // دالة لعمل refresh للصفحة الحالية
  void _refreshCurrentPage() {
    // Haptic feedback للإشعار بالـ refresh
    HapticFeedback.mediumImpact();

    // إعادة بناء الصفحة الحالية بتغيير الـ key
    setState(() {
      _pageKeys[_currentIndex] = GlobalKey();
    });
  }

  // دالة تحديد الموقع الحالي من GPS
  Future<void> _getCurrentLocation() async {
    if (_isLoadingLocation) return;

    setState(() => _isLoadingLocation = true);

    try {
      // التحقق من صلاحيات الموقع
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _currentAddress = null;
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _currentAddress = null;
          _isLoadingLocation = false;
        });
        return;
      }

      // الحصول على الموقع الحالي
      Position position =
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('انتهت مهلة تحديد الموقع');
            },
          );

      // تحويل الإحداثيات إلى عنوان
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        List<String> addressParts = [];

        // إضافة الشارع أو الحي
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          addressParts.add(placemark.street!);
        } else if (placemark.thoroughfare != null &&
            placemark.thoroughfare!.isNotEmpty) {
          addressParts.add(placemark.thoroughfare!);
        } else if (placemark.subLocality != null &&
            placemark.subLocality!.isNotEmpty) {
          addressParts.add(placemark.subLocality!);
        }

        // إضافة المدينة
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          addressParts.add(placemark.locality!);
        } else if (placemark.subAdministrativeArea != null &&
            placemark.subAdministrativeArea!.isNotEmpty) {
          addressParts.add(placemark.subAdministrativeArea!);
        }

        // إضافة المحافظة
        if (placemark.administrativeArea != null &&
            placemark.administrativeArea!.isNotEmpty) {
          addressParts.add(placemark.administrativeArea!);
        }

        // بناء العنوان النهائي
        String address = addressParts.join('، ');

        setState(() {
          _currentAddress = address.isNotEmpty ? address : 'الموقع الحالي';
          _selectedPosition = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
      } else {
        setState(() {
          _currentAddress = 'الموقع الحالي';
          _selectedPosition = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = null;
          _isLoadingLocation = false;
        });
      }
    }
  }

  // عرض Bottom Sheet لاختيار العنوان
  void _showAddressBottomSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'العناوين المحفوظة',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: colorScheme.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // عناوين التوصيل
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'عناوين التوصيل',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // العنوان المحفوظ (مثال)
                    Consumer<SupabaseProvider>(
                      builder: (context, authProvider, _) {
                        // إذا كان هناك عنوان حالي من GPS
                        if (_currentAddress != null) {
                          return _buildAddressCard(
                            context,
                            title: 'الموقع الحالي',
                            address: _currentAddress!,
                            icon: Icons.my_location,
                            onTap: () {
                              Navigator.pop(context);
                            },
                          );
                        }

                        // عناوين محفوظة (يمكن تحميلها من قاعدة البيانات)
                        return _buildAddressCard(
                          context,
                          title: 'شقة',
                          address:
                              'The C House, Masaken Al Astad Street, 2\nجامعه الزقازيق',
                          icon: Icons.home,
                          onTap: () {
                            Navigator.pop(context);
                            // يمكن حفظ العنوان المختار
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // التوصيل إلى عنوان آخر
                    _buildAddressOption(
                      context,
                      title: 'التوصيل إلى عنوان آخر',
                      subtitle: 'اختر موقع على الخريطة',
                      icon: Icons.add_location_alt,
                      onTap: () async {
                        Navigator.pop(context);

                        final messenger = ScaffoldMessenger.of(context);

                        // الحصول على userId من authProvider
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdvancedMapScreen(
                              userType: MapUserType.customer,
                              actionType: MapActionType.pickLocation,
                              initialPosition: _selectedPosition,
                              onLocationSelected: (position, address) {
                                AppLogger.info('موقع محدد: $address');
                              },
                            ),
                          ),
                        );

                        if (!mounted) return;
                        if (result == null) return;

                        setState(() {
                          _selectedPosition = result['position'];
                          _currentAddress = result['address'];
                        });

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم تحديد العنوان: ${result['address']}',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // التوصيل إلى الموقع الحالي
                    _buildAddressOption(
                      context,
                      title: 'التوصيل إلى الموقع الحالي',
                      subtitle: 'السماح لتطبيق طلبات بتحديد الموقع',
                      icon: Icons.gps_fixed,
                      onTap: () {
                        Navigator.pop(context);
                        _getCurrentLocation();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(
    BuildContext context, {
    required String title,
    required String address,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.location_on, color: colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_back_ios,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const RoleBasedDrawer(),
      endDrawer: const NotificationsSidebar(),
      appBar: _buildAppBar(context, colorScheme),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          HomeScreen(key: _pageKeys[0]),
          OrderHistoryScreen(key: _pageKeys[1]),
          FavoritesScreen(key: _pageKeys[2]),
          ProfileScreen(key: _pageKeys[3]),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'الرئيسية',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'الطلبات',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.favorite_border,
                  activeIcon: Icons.favorite,
                  label: 'المفضلة',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'حسابي',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      title: Consumer<SupabaseProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUserProfile;

          // تحديد العنوان المراد عرضه
          String deliveryAddress;
          if (_isLoadingLocation) {
            deliveryAddress = 'جاري تحديد موقعك...';
          } else if (_currentAddress != null) {
            deliveryAddress = _currentAddress!;
          } else if (user != null) {
            deliveryAddress = 'اختر عنوان التوصيل';
          } else {
            deliveryAddress = 'التل الكبير، الإسماعيلية';
          }

          return InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _showAddressBottomSheet(context);
            },
            onLongPress: () {
              // إعادة تحديد الموقع عند الضغط المطول
              HapticFeedback.mediumImpact();
              _getCurrentLocation();
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isLoadingLocation
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.onPrimary.withValues(alpha: 0.7),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: colorScheme.onPrimary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                      const SizedBox(width: 4),
                      Text(
                        'التوصيل إلى',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          deliveryAddress,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: colorScheme.onPrimary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        // سلة التسوق
        Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            final itemCount = cartProvider.cartItems.length;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_rounded),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, AppRoutes.cart);
                  },
                ),
                if (itemCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        itemCount > 99 ? '99+' : itemCount.toString(),
                        style: TextStyle(
                          color: colorScheme.onError,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        // الإشعارات
        Consumer<NotificationProvider>(
          builder: (context, notificationProvider, child) {
            final unreadCount = notificationProvider.unreadCount;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_rounded),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: TextStyle(
                          color: colorScheme.onError,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => _checkLoginForProtectedTabs(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey('${index}_$isActive'),
                color: isActive ? primaryColor : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? primaryColor : Colors.grey,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
