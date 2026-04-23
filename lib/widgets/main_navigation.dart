import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ell_tall_market/screens/user/home_screen.dart';
import 'package:ell_tall_market/screens/user/order_history_screen.dart';
import 'package:ell_tall_market/screens/user/favorites_screen.dart';
import 'package:ell_tall_market/screens/user/profile_screen.dart';
import 'package:ell_tall_market/screens/shared/advanced_map_screen.dart';
import 'package:ell_tall_market/screens/common/notifications_screen.dart';
import 'package:ell_tall_market/widgets/role_based_drawer.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/notification_provider.dart';
import 'package:ell_tall_market/providers/location_provider.dart';
import 'package:ell_tall_market/providers/store_provider.dart';
import 'package:ell_tall_market/services/google_maps_api_service.dart';
import 'package:ell_tall_market/services/notification_service.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/utils/address_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  final GoogleMapsApiService _mapsApi = GoogleMapsApiService();

  // App Colors
  static const Color primaryColor = Color(0xFF6A5AE0);
  static const Color accentColor = Color(0xFFFF9E80);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadCachedLocation(); // عرض آخر موقع محفوظ فوراً
    _getCurrentLocation(); // تحديد الموقع عند بدء التطبيق

    // جلب الإشعارات وحفظ device token للمستخدم
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      if (authProvider.isLoggedIn && authProvider.currentUser != null) {
        Provider.of<NotificationProvider>(
          context,
          listen: false,
        ).loadUserNotifications(authProvider.currentUser!.id);

        // حفظ FCM token للعميل عند فتح الشاشة الرئيسية
        NotificationServiceEnhanced.instance.saveTokenForCurrentUser(
          role: 'client',
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mapsApi.dispose();
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

  // ━━━━━ M1: تحميل آخر موقع محفوظ فوراً (بدون GPS) ━━━━━
  Future<void> _loadCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('last_lat');
      final lng = prefs.getDouble('last_lng');
      final address = prefs.getString('last_address');

      if (lat != null && lng != null && mounted) {
        _selectedPosition = LatLng(lat, lng);
        final locationProvider = context.read<LocationProvider>();
        locationProvider.setLocation(latitude: lat, longitude: lng);

        setState(() {
          _currentAddress = address;
          _isLoadingLocation = true; // GPS لسه شغال
        });

        // جلب المتاجر فوراً من الموقع المحفوظ
        _fetchNearbyStores(lat, lng);
      }
    } catch (e) {
      AppLogger.warning('فشل تحميل الموقع المحفوظ: $e');
    }
  }

  // ━━━━━ M1: حفظ الموقع والعنوان في SharedPreferences ━━━━━
  Future<void> _cacheLocation(double lat, double lng, String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_lat', lat);
      await prefs.setDouble('last_lng', lng);
      await prefs.setString('last_address', address);
    } catch (e) {
      AppLogger.warning('فشل حفظ الموقع: $e');
    }
  }

  // ━━━━━ E2: حوار رفض صلاحية الموقع نهائياً ━━━━━
  void _showLocationDeniedForeverDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('صلاحية الموقع مطلوبة'),
        content: const Text(
          'تم رفض صلاحية الموقع نهائياً. '
          'لتفعيلها مرة أخرى، يرجى الذهاب إلى إعدادات التطبيق '
          'وتفعيل صلاحية الموقع يدوياً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('لاحقاً'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Geolocator.openAppSettings();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  // دالة تحديد الموقع الحالي من GPS — محسّنة للسرعة
  Future<void> _getCurrentLocation() async {
    if (_isLoadingLocation) return;

    setState(() => _isLoadingLocation = true);

    try {
      // ━━━━━ E1: التحقق من تفعيل خدمة الموقع ━━━━━
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isLoadingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تفعيل خدمة الموقع (GPS) من الإعدادات'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

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

      // ━━━━━ E2: إظهار حوار عند رفض الصلاحية نهائياً ━━━━━
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isLoadingLocation = false;
        });
        _showLocationDeniedForeverDialog();
        return;
      }

      // ━━━━━ الخطوة 1: آخر موقع معروف فوراً (0 ثوانٍ) ━━━━━
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null && mounted) {
        // عرض الموقع فوراً بدون انتظار GPS
        _selectedPosition = LatLng(
          lastPosition.latitude,
          lastPosition.longitude,
        );
        final locationProvider = context.read<LocationProvider>();
        locationProvider.setLocation(
          latitude: lastPosition.latitude,
          longitude: lastPosition.longitude,
        );
        // عرض "الموقع الحالي" مؤقتاً + بدء جلب المتاجر فوراً
        setState(() {
          // لا نحفظ placeholder — نبقي العنوان القديم أو null
          _isLoadingLocation = true; // نبقى في حالة تحميل للعنوان التفصيلي
        });
        _fetchNearbyStores(lastPosition.latitude, lastPosition.longitude);
        // بدء reverse geocode في الخلفية للموقع المبدئي
        _resolveAddressInBackground(
          lastPosition.latitude,
          lastPosition.longitude,
        );
      }

      // ━━━━━ الخطوة 2: GPS دقيق (سريع - 8 ثوانٍ حد أقصى) ━━━━━
      Position? accuratePosition;
      try {
        accuratePosition =
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low, // أسرع بكثير من medium/high
                timeLimit: Duration(seconds: 8),
              ),
            ).timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                AppLogger.warning('⏱️ GPS timeout after 10s');
                throw TimeoutException('GPS timeout');
              },
            );
      } on TimeoutException catch (_) {
        // لو الـ GPS بطيء، نستخدم آخر موقع معروف (اللي عرضناه فوق)
        AppLogger.info('📍 استخدام آخر موقع معروف (GPS بطيء)');
        accuratePosition = lastPosition;
      }

      // لو مفيش أي موقع خالص
      if (accuratePosition == null) {
        if (mounted) {
          setState(() {
            _currentAddress = null;
            _isLoadingLocation = false;
          });
        }
        return;
      }

      // ━━━━━ الخطوة 3: تحديث بالموقع الدقيق ━━━━━
      if (!mounted) return;

      _selectedPosition = LatLng(
        accuratePosition.latitude,
        accuratePosition.longitude,
      );
      final locationProvider = context.read<LocationProvider>();
      locationProvider.setLocation(
        latitude: accuratePosition.latitude,
        longitude: accuratePosition.longitude,
      );

      // لو الموقع الدقيق مختلف عن المبدئي، نحدث المتاجر والعنوان
      final movedSignificantly =
          lastPosition == null ||
          Geolocator.distanceBetween(
                lastPosition.latitude,
                lastPosition.longitude,
                accuratePosition.latitude,
                accuratePosition.longitude,
              ) >
              100; // أكثر من 100 متر فرق

      if (movedSignificantly) {
        _fetchNearbyStores(
          accuratePosition.latitude,
          accuratePosition.longitude,
        );
      }

      // resolve العنوان التفصيلي (بدون حجب الـ UI)
      _resolveAddressInBackground(
        accuratePosition.latitude,
        accuratePosition.longitude,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديد الموقع', e);
      if (mounted) {
        setState(() {
          // نحتفظ بالعنوان القديم كما هو (لا تغيير)
          _isLoadingLocation = false;
        });
      }
    }
  }

  /// resolve العنوان في الخلفية بدون حجب الـ UI
  Future<void> _resolveAddressInBackground(double lat, double lng) async {
    try {
      String? addressText;

      // محاولة Google Maps API أولاً (مع timeout قصير 5 ثوانٍ)
      try {
        final result = await _mapsApi
            .reverseGeocodeArabic(LatLng(lat, lng))
            .timeout(const Duration(seconds: 5));
        final display = result?.displayAddress;
        if (display != null && display.trim().isNotEmpty) {
          addressText = display.trim();
        }
      } catch (_) {
        // صامت - ننتقل للـ fallback
      }

      // Fallback: geocoding package (مع timeout قصير 5 ثوانٍ)
      if (addressText == null) {
        try {
          final fallback = await AddressUtils.fallbackAddressFromPlacemark(
            lat,
            lng,
          );
          if (fallback != null && fallback.trim().isNotEmpty) {
            addressText = fallback.trim();
          }
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        _currentAddress =
            addressText; // null لو مفيش عنوان — لا نحفظ placeholder
        _isLoadingLocation = false;
      });

      // M1: حفظ الموقع والعنوان في SharedPreferences لاستعادتهما فوراً
      if (addressText != null) {
        _cacheLocation(lat, lng, addressText);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          // نحتفظ بالعنوان القديم كما هو
          _isLoadingLocation = false;
        });
      }
    }
  }

  // جلب المتاجر القريبة من الموقع المحدد
  Future<void> _fetchNearbyStores(double latitude, double longitude) async {
    try {
      final storeProvider = context.read<StoreProvider>();
      await storeProvider.fetchNearbyStores(
        latitude: latitude,
        longitude: longitude,
        maxDistanceKm: 15,
      );
      AppLogger.info(
        '🏪 تم تحديث المتاجر القريبة: ${storeProvider.nearbyStores.length} متجر',
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب المتاجر القريبة', e);
    }
  }

  // عرض Bottom Sheet للإشعارات
  void _showNotificationsBottomSheet(BuildContext parentContext) {
    final colorScheme = Theme.of(parentContext).colorScheme;

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: NotificationsScreen(targetRole: 'client'),
        ),
      ),
    );
  }

  // عرض Bottom Sheet لاختيار العنوان
  void _showAddressBottomSheet(BuildContext parentContext) {
    final colorScheme = Theme.of(parentContext).colorScheme;

    showModalBottomSheet(
      context: parentContext,
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
                      onPressed: () => Navigator.pop(parentContext),
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
                              Navigator.pop(parentContext);
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
                            Navigator.pop(parentContext);
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
                        Navigator.pop(parentContext);

                        final messenger = ScaffoldMessenger.of(parentContext);

                        // الحصول على userId من authProvider
                        final result = await Navigator.push(
                          parentContext,
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

                        final pos = result['position'] as LatLng?;
                        setState(() {
                          _selectedPosition = pos;
                          _currentAddress = result['address'];
                        });

                        // تحديث LocationProvider وجلب المتاجر القريبة
                        if (pos != null) {
                          final locationProvider = context
                              .read<LocationProvider>();
                          locationProvider.setLocation(
                            latitude: pos.latitude,
                            longitude: pos.longitude,
                            address: result['address'],
                          );
                          _fetchNearbyStores(pos.latitude, pos.longitude);
                        }

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
                        Navigator.pop(parentContext);
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
    final isWide = MediaQuery.sizeOf(context).width >= 1200;

    final pages = [
      HomeScreen(key: _pageKeys[0]),
      OrderHistoryScreen(key: _pageKeys[1]),
      FavoritesScreen(key: _pageKeys[2]),
      ProfileScreen(key: _pageKeys[3]),
    ];

    return Scaffold(
      drawer: !isWide ? const RoleBasedDrawer() : null,
      appBar: _buildAppBar(context, colorScheme, isWide),
      body: isWide
          ? Row(
              children: [
                const RoleBasedDrawer(isSidebar: true),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      _buildNavTabBar(colorScheme),
                      Expanded(
                        child: IndexedStack(
                          index: _currentIndex,
                          children: pages,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              children: pages,
            ),
      bottomNavigationBar: !isWide
          ? Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
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
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    bool isWide,
  ) {
    return AppBar(
      automaticallyImplyLeading: !isWide,
      elevation: 0,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
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
                                  colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: colorScheme.onPrimary,
                            ),
                      const SizedBox(width: 4),
                      Text(
                        'التوصيل إلى',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onPrimary.withValues(alpha: 0.8),
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
            final unreadCount = notificationProvider.getUnreadCountForRole(
              'client',
            );
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_rounded),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showNotificationsBottomSheet(context);
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: TextStyle(
                          color: colorScheme.onError,
                          fontSize: 9,
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

  Widget _buildNavTabBar(ColorScheme colorScheme) {
    final items = [
      (Icons.home_outlined, Icons.home, 'الرئيسية'),
      (Icons.receipt_long_outlined, Icons.receipt_long, 'الطلبات'),
      (Icons.favorite_border, Icons.favorite, 'المفضلة'),
      (Icons.person_outline, Icons.person, 'حسابي'),
    ];
    return Container(
      color: colorScheme.surface,
      child: Row(
        children: List.generate(items.length, (index) {
          final isActive = _currentIndex == index;
          return Expanded(
            child: InkWell(
              onTap: () => _checkLoginForProtectedTabs(index),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive
                          ? colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isActive ? items[index].$2 : items[index].$1,
                      color: isActive ? colorScheme.primary : Colors.black,
                      size: 18,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[index].$3,
                      style: TextStyle(
                        fontSize: 11,
                        color: isActive ? colorScheme.primary : Colors.black,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
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
