import 'package:flutter/foundation.dart';
import 'package:ell_tall_market/models/store_model.dart';

class StoreProvider with ChangeNotifier {
  List<StoreModel> _stores = [];
  List<StoreModel> _filteredStores = []; // تم إضافة هذه القائمة
  List<StoreModel> _featuredStores = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<StoreModel> get stores => _stores;
  List<StoreModel> get filteredStores => _filteredStores; // تم إضافة هذا الـGetter
  List<StoreModel> get featuredStores => _featuredStores;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // بيانات نموذجية للمتاجر
  final List<StoreModel> _demoStores = [
    StoreModel(
      id: '1',
      name: 'سوبرماركت التل',
      category: 'سوبرماركت',
      imageUrl: 'https://via.placeholder.com/300/4CAF50/FFFFFF?text=سوبرماركت+التل',
      rating: 4.5,
      reviewCount: 120,
      deliveryTime: 25,
      deliveryFee: 5.0,
      minOrder: 20.0,
      isOpen: true,
      description: 'أكبر سوبرماركت في المنطقة يقدم جميع احتياجاتك اليومية',
      address: 'الرياض، حي النرجس، شارع الملك فهد',
      phone: '+966512345678',
      openingHours: ['08:00 - 23:00', '08:00 - 23:00', '08:00 - 23:00', '08:00 - 23:00', '08:00 - 23:00', '08:00 - 24:00', '08:00 - 24:00'],
    ),
    StoreModel(
      id: '2',
      name: 'مطعم الشيف',
      category: 'مطاعم',
      imageUrl: 'https://via.placeholder.com/300/FF5722/FFFFFF?text=مطعم+الشيف',
      rating: 4.8,
      reviewCount: 85,
      deliveryTime: 35,
      deliveryFee: 8.0,
      minOrder: 15.0,
      isOpen: true,
      description: 'أشهى المأكولات العربية والعالمية بأيدي أمهر الطهاة',
      address: 'الرياض، حي الملز، شارع العليا',
      phone: '+966511234567',
      openingHours: ['12:00 - 01:00', '12:00 - 01:00', '12:00 - 01:00', '12:00 - 01:00', '12:00 - 02:00', '12:00 - 02:00', '12:00 - 02:00'],
    ),
    StoreModel(
      id: '3',
      name: 'إلكترونيات المستقبل',
      category: 'إلكترونيات',
      imageUrl: 'https://via.placeholder.com/300/2196F3/FFFFFF?text=إلكترونيات+المستقبل',
      rating: 4.7,
      reviewCount: 60,
      deliveryTime: 40,
      deliveryFee: 15.0,
      minOrder: 100.0,
      isOpen: true,
      description: 'أحدث الأجهزة الإلكترونية والهواتف الذكية.',
      address: 'الرياض، حي العليا، شارع التقنية',
      phone: '+966500000003',
      openingHours: ['09:00 - 22:00', '09:00 - 22:00', '09:00 - 22:00', '09:00 - 22:00', '09:00 - 22:00', '09:00 - 23:00', '09:00 - 23:00'],
    ),
    StoreModel(
      id: '4',
      name: 'متجر الأناقة',
      category: 'ملابس',
      imageUrl: 'https://via.placeholder.com/300/9C27B0/FFFFFF?text=متجر+الأناقة',
      rating: 4.3,
      reviewCount: 45,
      deliveryTime: 30,
      deliveryFee: 10.0,
      minOrder: 50.0,
      isOpen: true,
      description: 'أحدث صيحات الموضة والملابس الرجالية والنسائية.',
      address: 'الرياض، حي الورود، شارع الأناقة',
      phone: '+966500000004',
      openingHours: ['10:00 - 22:00', '10:00 - 22:00', '10:00 - 22:00', '10:00 - 22:00', '10:00 - 22:00', '10:00 - 23:00', '10:00 - 23:00'],
    ),
    // ... باقي المتاجر
  ];

  // جلب جميع المتاجر
  Future<void> fetchStores() async {
    _setLoading(true);
    _error = null;

    try {
      // محاكاة جلب البيانات من API
      await Future.delayed(Duration(seconds: 2));

      _stores = _demoStores;
      _filteredStores = _stores; // تهيئة القائمة المُصفاة
      _featuredStores = _stores.where((store) => store.rating >= 4.5).toList();

    } catch (e) {
      _setError('فشل في تحميل المتاجر: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // تصفية المتاجر
  void filterStores(String query, String category) {
    _filteredStores = _stores.where((store) {
      final matchesSearch = store.name.toLowerCase().contains(query.toLowerCase()) ||
          store.description.toLowerCase().contains(query.toLowerCase());
      final matchesCategory = category == 'الكل' || store.category == category;
      return matchesSearch && matchesCategory;
    }).toList();
    notifyListeners();
  }

  // البحث عن متاجر بالاسم
  void searchStores(String query) {
    if (query.isEmpty) {
      _filteredStores = _stores;
    } else {
      _filteredStores = _stores.where((store) {
        return store.name.toLowerCase().contains(query.toLowerCase()) ||
            store.category.toLowerCase().contains(query.toLowerCase()) ||
            store.description.toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
    notifyListeners();
  }

  // الحصول على متجر بواسطة ID
  StoreModel? getStoreById(String id) {
    try {
      return _stores.firstWhere((store) => store.id == id);
    } catch (e) {
      return null;
    }
  }

  // الحصول على متاجر حسب التصنيف
  List<StoreModel> getStoresByCategory(String category) {
    if (category == 'الكل') return _stores;
    return _stores.where((store) => store.category == category).toList();
  }

  // الحصول على المتاجر المفتوحة فقط
  List<StoreModel> getOpenStores() {
    return _stores.where((store) => store.isOpen).toList();
  }

  // الحصول على المتاجر التي تقدم توصيل مجاني
  List<StoreModel> getFreeDeliveryStores() {
    return _stores.where((store) => store.deliveryFee == 0).toList();
  }

  // الحصول على المتاجر ذات التوصيل السريع (أقل من 30 دقيقة)
  List<StoreModel> getFastDeliveryStores() {
    return _stores.where((store) => store.deliveryTime <= 30).toList();
  }

  // الحصول على أفضل المتاجر تقييماً
  List<StoreModel> getTopRatedStores() {
    return _stores.where((store) => store.rating >= 4.0).toList();
  }

  // إضافة متجر جديد (للوحة التحكم)
  void addStore(StoreModel store) {
    _stores.add(store);
    _filteredStores = _stores;
    notifyListeners();
  }

  // تحديث متجر
  void updateStore(StoreModel updatedStore) {
    final index = _stores.indexWhere((store) => store.id == updatedStore.id);
    if (index != -1) {
      _stores[index] = updatedStore;
      _filteredStores = _stores;
      notifyListeners();
    }
  }

  // حذف متجر
  void deleteStore(String storeId) {
    _stores.removeWhere((store) => store.id == storeId);
    _filteredStores = _stores;
    notifyListeners();
  }

  // الحصول على جميع التصنيفات المتاحة
  List<String> getAvailableCategories() {
    final categories = _stores.map((store) => store.category).toSet().toList();
    categories.insert(0, 'الكل');
    return categories;
  }

  // تحديث حالة المتجر (فتح/غلق)
  void toggleStoreStatus(String storeId, bool isOpen) {
    final store = getStoreById(storeId);
    if (store != null) {
      final updatedStore = store.copyWith(isOpen: isOpen);
      updateStore(updatedStore);
    }
  }

  // State handlers
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String value) {
    _error = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // تحميل البيانات الأولية
  void loadInitialData() {
    if (_stores.isEmpty) {
      fetchStores();
    }
  }

  // إعادة تعيين الفلتر
  void resetFilter() {
    _filteredStores = _stores;
    notifyListeners();
  }

  // الحصول على المتاجر القريبة (محاكاة)
  List<StoreModel> getNearbyStores() {
    return _stores.take(5).toList(); // أول 5 متاجر كمثال
  }

  // الحصول على المتاجر الموصى بها
  List<StoreModel> getRecommendedStores() {
    return _stores.where((store) => store.rating >= 4.3).toList();
  }
}