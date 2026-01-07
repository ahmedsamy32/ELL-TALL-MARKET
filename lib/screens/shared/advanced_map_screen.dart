import 'dart:async';
import 'dart:math' show sqrt, asin;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/config/env.dart';
import 'package:ell_tall_market/services/google_maps_api_service.dart';
import 'package:ell_tall_market/services/order_service.dart';

/// 🗺️ Advanced Map Screen - يدعم 3 أنواع مستخدمين
///
/// الاستخدامات:
/// 1. Customer Mode: اختيار موقع التوصيل
/// 2. Merchant Mode: عرض مواقع الطلبات
/// 3. Driver Mode: التتبع الحي والتنقل
enum MapUserType {
  customer, // العميل - اختيار موقع
  merchant, // التاجر - عرض الطلبات
  driver, // الكابتن - التتبع والتنقل
}

/// 🎯 نوع العملية على الخريطة
enum MapActionType {
  pickLocation, // اختيار موقع
  viewLocation, // عرض موقع فقط
  navigation, // التنقل والتوصيل
  tracking, // التتبع الحي
}

class MapLocationDetails {
  final LatLng position;
  final String address;
  final String? street;
  final String? district;
  final String? city;
  final String? governorate;

  const MapLocationDetails({
    required this.position,
    required this.address,
    this.street,
    this.district,
    this.city,
    this.governorate,
  });
}

class AdvancedMapScreen extends StatefulWidget {
  final MapUserType userType;
  final MapActionType actionType;
  final LatLng? initialPosition;
  final LatLng? destinationPosition;
  final String? orderId;
  final String? customerName;
  final String? customerPhone;
  final Function(LatLng position, String address)? onLocationSelected;
  final void Function(MapLocationDetails details)? onLocationSelectedDetails;
  final VoidCallback? onNavigationStart;
  final VoidCallback? onDeliveryComplete;

  const AdvancedMapScreen({
    super.key,
    required this.userType,
    required this.actionType,
    this.initialPosition,
    this.destinationPosition,
    this.orderId,
    this.customerName,
    this.customerPhone,
    this.onLocationSelected,
    this.onLocationSelectedDetails,
    this.onNavigationStart,
    this.onDeliveryComplete,
  });

  @override
  State<AdvancedMapScreen> createState() => _AdvancedMapScreenState();
}

class _AdvancedMapScreenState extends State<AdvancedMapScreen>
    with TickerProviderStateMixin {
  // 🗺️ Map Controllers
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controller = Completer();

  // 📍 Location Data
  LatLng? _currentPosition;
  LatLng? _selectedPosition;
  String _selectedAddress = 'جاري تحديد العنوان...';
  String? _selectedStreet;
  String? _selectedDistrict;
  String? _selectedCity;
  String? _selectedGovernorate;
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = false;

  // 🎯 Markers & Polylines
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};
  List<LatLng> _polylineCoordinates = [];

  // 🚗 Navigation & Tracking
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<Map<String, dynamic>?>? _orderStreamSub;
  StreamSubscription<Map<String, dynamic>?>? _driverLocationSub;
  Map<String, dynamic>? _liveOrder;
  Map<String, dynamic>? _liveDriverLocation;
  double _distanceToDestination = 0.0;
  double _estimatedTime = 0.0; // بالدقائق
  bool _isNavigating = false;

  // 🎨 UI State
  MapType _currentMapType = MapType.normal;
  bool _isTrafficEnabled = false;
  final double _currentZoom = 15.0;
  AnimationController? _pulseAnimationController;
  Animation<double>? _pulseAnimation;

  // ⚙️ Settings
  final double _deliveryRadius = 15.0; // كم
  Timer? _debounceTimer;
  final GoogleMapsApiService _mapsApi = GoogleMapsApiService();

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _setupAnimations();
  }

  /// 🚀 تهيئة الخريطة
  Future<void> _initializeMap() async {
    // تحديد الموقع الأولي
    if (widget.initialPosition != null) {
      _currentPosition = widget.initialPosition;
      _selectedPosition = widget.initialPosition;
    } else {
      await _getCurrentLocation();
    }

    // إعداد المؤشرات حسب نوع المستخدم
    _setupMarkersBasedOnUserType();

    // رسم المسار إذا كان هناك وجهة
    if (widget.destinationPosition != null && _currentPosition != null) {
      await _drawRoute(_currentPosition!, widget.destinationPosition!);
    }

    // بدء التتبع الحي للكابتن
    if (widget.userType == MapUserType.driver &&
        widget.actionType == MapActionType.tracking) {
      _startLiveTracking();
    }

    // ✅ تتبع طلب (للعميل/التاجر/الكابتن) عبر Supabase Realtime
    if (widget.actionType == MapActionType.tracking && widget.orderId != null) {
      _startOrderTracking(widget.orderId!);
    }
  }

  void _startOrderTracking(String orderId) {
    _orderStreamSub?.cancel();
    _driverLocationSub?.cancel();

    _orderStreamSub = OrderService.streamOrder(orderId).listen((order) {
      if (!mounted) return;

      setState(() => _liveOrder = order);

      final assignedDriverId = order?['assigned_driver_id']?.toString();

      _driverLocationSub?.cancel();
      if (assignedDriverId != null && assignedDriverId.isNotEmpty) {
        _driverLocationSub = OrderService.streamDriverLocation(assignedDriverId)
            .listen((loc) {
              if (!mounted) return;
              setState(() => _liveDriverLocation = loc);
              _syncTrackingMarkers();
            });
      } else {
        setState(() => _liveDriverLocation = null);
      }

      _syncTrackingMarkers();
    });
  }

  LatLng? _extractGeoPoint(dynamic geoJson) {
    if (geoJson is Map<String, dynamic>) {
      final coords = geoJson['coordinates'];
      if (coords is List && coords.length >= 2) {
        final lng = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        return LatLng(lat, lng);
      }
    }
    return null;
  }

  void _syncTrackingMarkers() {
    final pickup = _extractGeoPoint(_liveOrder?['pickup_position']);
    final dropoff = _extractGeoPoint(_liveOrder?['dropoff_position']);
    final driver = _extractGeoPoint(_liveDriverLocation?['position']);

    _markers.removeWhere(
      (m) =>
          m.markerId.value == 'tracking_pickup' ||
          m.markerId.value == 'tracking_dropoff' ||
          m.markerId.value == 'tracking_driver',
    );

    if (pickup != null) {
      _addMarker(
        'tracking_pickup',
        pickup,
        'Pickup',
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      );
    }

    if (dropoff != null) {
      _addMarker(
        'tracking_dropoff',
        dropoff,
        'Dropoff',
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
    }

    if (driver != null) {
      _addMarker(
        'tracking_driver',
        driver,
        'Driver',
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    }

    final target = driver ?? pickup ?? dropoff;
    if (target != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLng(target));
    }

    if (mounted) setState(() {});
  }

  /// 🎭 إعداد الأنيميشن
  void _setupAnimations() {
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _pulseAnimationController!,
        curve: Curves.easeInOut,
      ),
    );
  }

  /// 📍 إعداد المؤشرات حسب نوع المستخدم
  void _setupMarkersBasedOnUserType() {
    _markers.clear();

    switch (widget.userType) {
      case MapUserType.customer:
        // العميل: مؤشر لموقعه الحالي فقط
        if (_currentPosition != null) {
          _addMarker(
            'current_location',
            _currentPosition!,
            'موقعي الحالي',
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          );
        }
        break;

      case MapUserType.merchant:
        // التاجر: مؤشر للمتجر + مؤشرات للطلبات
        if (_currentPosition != null) {
          _addMarker(
            'store_location',
            _currentPosition!,
            'المتجر',
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          );

          // رسم دائرة نطاق التوصيل
          _circles.add(
            Circle(
              circleId: const CircleId('delivery_range'),
              center: _currentPosition!,
              radius: _deliveryRadius * 1000,
              fillColor: Colors.blue.withValues(alpha: 0.1),
              strokeColor: Colors.blue.withValues(alpha: 0.5),
              strokeWidth: 2,
            ),
          );
        }
        break;

      case MapUserType.driver:
        // الكابتن: مؤشر لموقعه + مؤشر للوجهة
        if (_currentPosition != null) {
          _addMarker(
            'driver_location',
            _currentPosition!,
            'موقعي',
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          );
        }

        if (widget.destinationPosition != null) {
          _addMarker(
            'destination',
            widget.destinationPosition!,
            widget.customerName ?? 'العميل',
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          );
        }
        break;
    }

    if (mounted) setState(() {});
  }

  /// 📌 إضافة مؤشر للخريطة
  void _addMarker(
    String id,
    LatLng position,
    String title,
    BitmapDescriptor icon,
  ) {
    _markers.add(
      Marker(
        markerId: MarkerId(id),
        position: position,
        icon: icon,
        infoWindow: InfoWindow(title: title),
      ),
    );
  }

  /// 📍 الحصول على الموقع الحالي
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('تم رفض إذن الموقع');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('إذن الموقع مرفوض بشكل دائم');
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _selectedPosition = _currentPosition;
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition!, 15),
        );

        await _getAddressFromPosition(_currentPosition!);
      }
    } catch (e) {
      AppLogger.error('فشل تحديد الموقع', e);
      _showErrorSnackBar('فشل تحديد الموقع: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  /// 🏠 تحويل الإحداثيات إلى عنوان
  Future<void> _getAddressFromPosition(LatLng position) async {
    setState(() => _isLoadingAddress = true);

    try {
      // ✅ الحل الأدق لمشكلة Plus Codes: استخدام Google Geocoding API عبر HTTP
      // (حزمة geocoding لا تدعم دائماً localeIdentifier في بعض الإصدارات)
      final result = await _mapsApi.reverseGeocodeArabic(position);
      if (mounted && result != null) {
        String stripPrefix(String? v) {
          var s = (v ?? '').trim();
          if (s.isEmpty) return '';
          s = s
              .replaceFirst(RegExp(r'^\s*محافظة\s+'), '')
              .replaceFirst(RegExp(r'^\s*مركز\s+'), '')
              .replaceFirst(RegExp(r'^\s*مدينة\s+'), '')
              .replaceFirst(RegExp(r'^\s*قرية\s+'), '')
              .replaceFirst(RegExp(r'^\s*حي\s+'), '')
              .trim();
          return s;
        }

        bool looksCenter(String v) =>
            v.contains('مركز') || v.contains('مدينة') || v.contains('قسم');

        bool looksDistrict(String v) =>
            v.contains('حي') ||
            v.contains('قرية') ||
            v.contains('عزبة') ||
            v.contains('كفر') ||
            v.contains('نجع');

        String? city = result.city;
        String? district = result.neighborhood;

        // If Google swapped levels, fix it conservatively.
        if (city != null && district != null) {
          final c = city;
          final d = district;
          if (looksDistrict(c) && looksCenter(d)) {
            city = d;
            district = c;
          }
        } else if (city == null && district != null && looksCenter(district)) {
          city = district;
          district = null;
        }

        setState(() {
          _selectedAddress = result.displayAddress;
          _selectedStreet = stripPrefix(result.street);
          _selectedDistrict = stripPrefix(district);
          _selectedCity = stripPrefix(city);
          _selectedGovernorate = stripPrefix(result.governorate);
        });
        AppLogger.info(
          '📍 العنوان (Google Geocoding): ${result.displayAddress}',
        );
        return;
      }

      // 🧯 fallback: geocoding package (قد يرجع Plus Codes أحياناً)
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 10));

      if (placemarks.isNotEmpty && mounted) {
        final placemark = placemarks.first;
        final parts = <String>[];
        String canonicalForDedup(String input) {
          var s = input.trim();
          if (s.isEmpty) return '';
          s = s.replaceAll('\u0640', '');
          s = s
              .replaceFirst(RegExp(r'^\s*محافظة\s+'), '')
              .replaceFirst(RegExp(r'^\s*مركز\s+'), '')
              .replaceFirst(RegExp(r'^\s*مدينة\s+'), '')
              .replaceFirst(RegExp(r'^\s*قرية\s+'), '')
              .replaceFirst(RegExp(r'^\s*حي\s+'), '');
          s = s
              .replaceAll(RegExp(r'[\-–—‑]+'), ' ')
              .replaceAll(RegExp(r'\s*(،|,)\s*'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim()
              .toLowerCase();
          return s;
        }

        void add(String? v) {
          final cleaned = _cleanAndValidate(v);
          if (cleaned == null) return;
          final cv = canonicalForDedup(cleaned);
          if (cv.isEmpty) return;
          if (parts.any((p) => canonicalForDedup(p) == cv)) return;
          parts.add(cleaned);
        }

        add(placemark.thoroughfare);
        add(placemark.street);
        add(placemark.subLocality);
        add(placemark.locality);
        add(placemark.administrativeArea);

        const maxDisplayParts = 4;
        final displayParts = parts
            .take(maxDisplayParts)
            .toList(growable: false);
        final fallbackAddress = displayParts.isEmpty
            ? 'موقع محدد'
            : displayParts.join('، ');
        final city =
            _cleanAndValidate(placemark.locality) ??
            _cleanAndValidate(placemark.subAdministrativeArea);
        final governorate = _cleanAndValidate(placemark.administrativeArea);

        setState(() {
          _selectedAddress = fallbackAddress;
          _selectedStreet =
              _cleanAndValidate(placemark.thoroughfare) ??
              _cleanAndValidate(placemark.street);
          _selectedDistrict =
              _cleanAndValidate(placemark.subLocality) ??
              _cleanAndValidate(placemark.subAdministrativeArea);
          _selectedCity = city;
          _selectedGovernorate = governorate;
        });
        AppLogger.info('📍 العنوان (fallback): $fallbackAddress');
      }
    } catch (e) {
      AppLogger.error('فشل تحويل الإحداثيات', e);
      setState(() {
        _selectedAddress = 'فشل تحديد العنوان';
        _selectedStreet = null;
        _selectedDistrict = null;
        _selectedCity = null;
        _selectedGovernorate = null;
      });
    } finally {
      setState(() => _isLoadingAddress = false);
    }
  }

  /// 🧹 تنظيف والتحقق من صحة النص
  ///
  /// يزيل Plus Codes والرموز غير المفيدة
  String? _cleanAndValidate(String? text) {
    if (text == null || text.trim().isEmpty) return null;

    var cleaned = _stripLeadingPlusCode(text).trim();

    // ❌ رفض Plus Codes (مثل: 7PPR+J3J)
    if (RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,3}$').hasMatch(cleaned)) {
      return null;
    }

    // 🧹 إزالة أرقام البريد/الضوضاء (تظهر أحياناً داخل العنوان)
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(?<![0-9\u0660-\u0669])[0-9\u0660-\u0669]{5,7}(?![0-9\u0660-\u0669])',
      ),
      '',
    );

    // 🧹 توحيد الفواصل والمسافات
    cleaned = cleaned
        .replaceAll(RegExp(r'\s*(،|,)\s*'), '، ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'(،\s*){2,}'), '، ')
        .trim();

    // ❌ رفض النصوص التي تحتوي على رموز غريبة فقط
    if (RegExp(r'^[^\u0600-\u06FFa-zA-Z\s]+$').hasMatch(cleaned)) {
      return null;
    }

    // ❌ رفض النصوص القصيرة جداً (أقل من حرفين)
    if (cleaned.length < 2) return null;

    // ❌ رفض الأرقام فقط
    if (RegExp(r'^\d+$').hasMatch(cleaned)) return null;

    // ❌ رفض "Unnamed Road" وما شابه
    if (cleaned.toLowerCase() == 'unnamed road' ||
        cleaned.toLowerCase() == 'unnamed' ||
        cleaned == 'طريق بدون اسم') {
      return null;
    }

    return cleaned;
  }

  String _stripLeadingPlusCode(String input) {
    final s = input.trim();
    // مثال: HQ5J+JV8، ...
    return s.replaceFirst(
      RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,3}\s*(?:,|،)?\s*'),
      '',
    );
  }

  /// 🛣️ رسم المسار بين نقطتين
  ///
  /// يستخدم Google Directions API لرسم المسار الحقيقي
  Future<void> _drawRoute(LatLng origin, LatLng destination) async {
    try {
      PolylinePoints polylinePoints = PolylinePoints(
        apiKey: Env.googleMapsApiKey,
      );

      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        // ignore: deprecated_member_use
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        _polylineCoordinates.clear();
        for (var point in result.points) {
          _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }

        setState(() {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              color: Colors.blue,
              points: _polylineCoordinates,
              width: 5,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
          );
        });

        // حساب المسافة والوقت المتوقع
        _calculateRouteDetails(origin, destination);

        // تحريك الكاميرا لعرض المسار كاملاً
        _fitBounds(origin, destination);

        AppLogger.info('✅ تم رسم المسار: ${_polylineCoordinates.length} نقطة');
      } else {
        AppLogger.warning('لم يتم العثور على مسار');
        _showErrorSnackBar('لم يتم العثور على مسار');

        // حل بديل: رسم خط مستقيم
        _drawStraightLine(origin, destination);
      }
    } catch (e) {
      AppLogger.error('فشل رسم المسار', e);
      _showErrorSnackBar('فشل رسم المسار: ${e.toString()}');

      // حل بديل: رسم خط مستقيم
      _drawStraightLine(origin, destination);
    }
  }

  /// رسم خط مستقيم كحل بديل
  void _drawStraightLine(LatLng origin, LatLng destination) {
    _polylineCoordinates = [origin, destination];

    setState(() {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          points: _polylineCoordinates,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    });

    _calculateRouteDetails(origin, destination);
    _fitBounds(origin, destination);

    AppLogger.info('⚠️ تم رسم خط مستقيم كحل بديل');
  }

  /// 📏 حساب تفاصيل المسار
  void _calculateRouteDetails(LatLng origin, LatLng destination) {
    // حساب المسافة
    _distanceToDestination = _calculateDistance(origin, destination);

    // تقدير الوقت (بافتراض سرعة 40 كم/ساعة في المدن)
    _estimatedTime = (_distanceToDestination / 40) * 60; // دقيقة

    setState(() {
      // تحديث الحالة
      AppLogger.info(
        'المسافة: ${_distanceToDestination.toStringAsFixed(1)} كم, '
        'الوقت المتوقع: ${_estimatedTime.toStringAsFixed(0)} دقيقة',
      );
    });
  }

  /// 📐 حساب المسافة بين نقطتين (Haversine formula)
  double _calculateDistance(LatLng from, LatLng to) {
    const earthRadius = 6371.0; // كم
    final dLat = _toRadians(to.latitude - from.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);

    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRadians(from.latitude)) *
            cos(_toRadians(to.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2));

    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * (3.14159265359 / 180);
  double sin(double value) => (value - (value * value * value) / 6);
  double cos(double value) => 1 - (value * value) / 2;

  /// 🎯 تحريك الكاميرا لعرض نقطتين
  void _fitBounds(LatLng pos1, LatLng pos2) {
    final bounds = LatLngBounds(
      southwest: LatLng(
        pos1.latitude < pos2.latitude ? pos1.latitude : pos2.latitude,
        pos1.longitude < pos2.longitude ? pos1.longitude : pos2.longitude,
      ),
      northeast: LatLng(
        pos1.latitude > pos2.latitude ? pos1.latitude : pos2.latitude,
        pos1.longitude > pos2.longitude ? pos1.longitude : pos2.longitude,
      ),
    );

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  /// 🔴 بدء التتبع الحي (للكابتن)
  void _startLiveTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // تحديث كل 10 متر
    );

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          if (mounted) {
            final newPosition = LatLng(position.latitude, position.longitude);

            setState(() {
              _currentPosition = newPosition;

              // تحديث مؤشر الكابتن
              _markers.removeWhere(
                (m) => m.markerId.value == 'driver_location',
              );
              _addMarker(
                'driver_location',
                newPosition,
                'موقعي',
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
              );
            });

            // تحريك الكاميرا مع الكابتن
            _mapController?.animateCamera(CameraUpdate.newLatLng(newPosition));

            // إعادة رسم المسار
            if (widget.destinationPosition != null) {
              _drawRoute(newPosition, widget.destinationPosition!);
            }
          }
        });
  }

  /// 🚦 بدء التنقل
  void _startNavigation() {
    if (_currentPosition == null || widget.destinationPosition == null) {
      _showErrorSnackBar('لا يمكن بدء التنقل');
      return;
    }

    setState(() => _isNavigating = true);
    _startLiveTracking();

    widget.onNavigationStart?.call();

    _showSuccessSnackBar('تم بدء التنقل');
  }

  /// ✅ إنهاء التوصيل
  void _completeDelivery() {
    _positionStream?.cancel();
    widget.onDeliveryComplete?.call();
    Navigator.pop(context, true);
  }

  /// 📍 تأكيد اختيار الموقع (للعميل)
  void _confirmLocation() {
    if (_selectedPosition == null) {
      _showErrorSnackBar('يرجى اختيار موقع');
      return;
    }

    // استدعاء الـ callback
    try {
      widget.onLocationSelected?.call(_selectedPosition!, _selectedAddress);
      widget.onLocationSelectedDetails?.call(
        MapLocationDetails(
          position: _selectedPosition!,
          address: _selectedAddress,
          street: _selectedStreet,
          district: _selectedDistrict,
          city: _selectedCity,
          governorate: _selectedGovernorate,
        ),
      );
    } catch (e) {
      AppLogger.warning('⚠️ خطأ في callback: $e');
    }

    // إغلاق الخريطة بعد delay قصير للسماح للـ callback بالتنفيذ
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, {
          'position': _selectedPosition,
          'address': _selectedAddress,
          'street': _selectedStreet,
          'district': _selectedDistrict,
          'city': _selectedCity,
          'governorate': _selectedGovernorate,
        });
      }
    });
  }

  /// 🎨 تبديل نوع الخريطة
  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : _currentMapType == MapType.satellite
          ? MapType.hybrid
          : MapType.normal;
    });
  }

  /// 🚦 تبديل حركة المرور
  void _toggleTraffic() {
    setState(() => _isTrafficEnabled = !_isTrafficEnabled);
  }

  /// 🎯 عرض رسائل الخطأ
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// ✅ عرض رسائل النجاح
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 🗺️ الخريطة
            GoogleMap(
              onMapCreated: (controller) {
                if (!_controller.isCompleted) {
                  _controller.complete(controller);
                }
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _currentPosition ?? const LatLng(30.0444, 31.2357),
                zoom: _currentZoom,
              ),
              mapType: _currentMapType,
              markers: _markers,
              polylines: _polylines,
              circles: _circles,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              trafficEnabled: _isTrafficEnabled,
              compassEnabled: true,
              onCameraMove: widget.actionType == MapActionType.pickLocation
                  ? (position) {
                      _selectedPosition = position.target;
                      _debounceTimer?.cancel();
                      setState(() => _selectedAddress = 'جاري التحديد...');
                    }
                  : null,
              onCameraIdle: widget.actionType == MapActionType.pickLocation
                  ? () {
                      _debounceTimer = Timer(
                        const Duration(milliseconds: 500),
                        () {
                          if (_selectedPosition != null) {
                            _getAddressFromPosition(_selectedPosition!);
                          }
                        },
                      );
                    }
                  : null,
            ),

            // 📍 دبوس المركز المحسّن (للعميل فقط)
            if (widget.actionType == MapActionType.pickLocation)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation!,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation!.value,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.error.withValues(
                                    alpha: 0.4 * (_pulseAnimation!.value - 0.9),
                                  ),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.location_on,
                              size: 50,
                              color: colorScheme.error,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),

            // 🎛️ أزرار التحكم العلوية
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // زر الرجوع المحسّن
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, size: 24),
                        onPressed: () => Navigator.pop(context),
                        color: Colors.black87,
                        tooltip: 'رجوع',
                      ),
                    ),

                    // مجموعة أزرار التحكم
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // نوع الخريطة
                          IconButton(
                            icon: Icon(
                              Icons.layers,
                              size: 22,
                              color: colorScheme.primary,
                            ),
                            onPressed: _toggleMapType,
                            tooltip: 'نوع الخريطة',
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: Colors.grey[300],
                          ),
                          // حركة المرور
                          IconButton(
                            icon: Icon(
                              Icons.traffic,
                              size: 22,
                              color: _isTrafficEnabled
                                  ? colorScheme.primary
                                  : Colors.grey[600],
                            ),
                            onPressed: _toggleTraffic,
                            tooltip: 'حركة المرور',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            //  لوحة المعلومات السفلية
            _buildBottomSheet(colorScheme),
          ],
        ),
      ),
    );
  }

  /// 📊 بناء اللوحة السفلية حسب نوع المستخدم
  Widget _buildBottomSheet(ColorScheme colorScheme) {
    switch (widget.userType) {
      case MapUserType.customer:
        return _buildCustomerBottomSheet(colorScheme);
      case MapUserType.merchant:
        return _buildMerchantBottomSheet(colorScheme);
      case MapUserType.driver:
        return _buildDriverBottomSheet(colorScheme);
    }
  }

  /// 👤 لوحة العميل
  Widget _buildCustomerBottomSheet(ColorScheme colorScheme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // مؤشر السحب المحسّن
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // العنوان المختار مع تصميم محسّن
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'موقع التوصيل',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (_isLoadingAddress)
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        colorScheme.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isLoadingAddress
                                  ? 'جاري تحديد العنوان...'
                                  : _selectedAddress,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // زر الموقع الحالي
                OutlinedButton.icon(
                  onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  icon: _isLoadingLocation
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary,
                            ),
                          ),
                        )
                      : Icon(Icons.my_location, size: 20),
                  label: Text(
                    _isLoadingLocation
                        ? 'جاري تحديد الموقع...'
                        : 'تحديد موقعي الحالي',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // زر التأكيد المحسّن
                FilledButton(
                  onPressed: _isLoadingAddress ? null : _confirmLocation,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: colorScheme.primary,
                    disabledBackgroundColor: Colors.grey[300],
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 22,
                        color: _isLoadingAddress ? Colors.grey : Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isLoadingAddress ? 'جاري التحميل...' : 'تأكيد الموقع',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isLoadingAddress ? Colors.grey : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🏪 لوحة التاجر
  Widget _buildMerchantBottomSheet(ColorScheme colorScheme) {
    // إذا كان في وضع اختيار الموقع
    if (widget.actionType == MapActionType.pickLocation) {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // مؤشر السحب المحسّن
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // معلومات الموقع مع تصميم محسّن
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primaryContainer.withValues(alpha: 0.4),
                          colorScheme.primaryContainer.withValues(alpha: 0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.store_mall_directory,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'موقع المتجر',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (_isLoadingAddress)
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              colorScheme.primary,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isLoadingAddress
                                    ? 'جاري تحديد العنوان...'
                                    : _selectedAddress,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // زر الموقع الحالي
                  OutlinedButton.icon(
                    onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    icon: _isLoadingLocation
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary,
                              ),
                            ),
                          )
                        : Icon(Icons.my_location, size: 20),
                    label: Text(
                      _isLoadingLocation
                          ? 'جاري تحديد الموقع...'
                          : 'تحديد موقع المتجر الحالي',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // زر التأكيد المحسّن
                  FilledButton(
                    onPressed: _isLoadingAddress ? null : _confirmLocation,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: colorScheme.primary,
                      disabledBackgroundColor: Colors.grey[300],
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 22,
                          color: _isLoadingAddress ? Colors.grey : Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isLoadingAddress
                              ? 'جاري التحميل...'
                              : 'تأكيد الموقع',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isLoadingAddress
                                ? Colors.grey
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // الوضع العادي (عرض نطاق التوصيل)
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.store,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'نطاق التوصيل',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$_deliveryRadius كيلومتر',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (widget.orderId != null)
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('تتبع الطلب'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 🚗 لوحة الكابتن
  Widget _buildDriverBottomSheet(ColorScheme colorScheme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // معلومات العميل
                if (widget.customerName != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colorScheme.primary,
                          child: Icon(
                            Icons.person,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.customerName!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (widget.customerPhone != null)
                                Text(
                                  widget.customerPhone!,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (widget.customerPhone != null)
                          IconButton(
                            onPressed: () {
                              // Note: الاتصال بالعميل
                            },
                            icon: const Icon(Icons.phone),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // معلومات المسار
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _InfoChip(
                        icon: Icons.route,
                        label: 'المسافة',
                        value:
                            '${_distanceToDestination.toStringAsFixed(1)} كم',
                      ),
                      _InfoChip(
                        icon: Icons.schedule,
                        label: 'الوقت',
                        value: '${_estimatedTime.toStringAsFixed(0)} دقيقة',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // أزرار الإجراءات
                if (!_isNavigating)
                  FilledButton.icon(
                    onPressed: _startNavigation,
                    icon: const Icon(Icons.navigation),
                    label: const Text('بدء التنقل'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _isNavigating = false);
                            _positionStream?.cancel();
                          },
                          icon: const Icon(Icons.cancel),
                          label: const Text('إيقاف'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _completeDelivery,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('تم التوصيل'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _orderStreamSub?.cancel();
    _driverLocationSub?.cancel();
    _positionStream?.cancel();
    _pulseAnimationController?.dispose();
    _mapController?.dispose();
    _mapsApi.dispose();
    super.dispose();
  }
}

/// 📊 عنصر معلومات محسّن
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.5),
            colorScheme.primaryContainer.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
