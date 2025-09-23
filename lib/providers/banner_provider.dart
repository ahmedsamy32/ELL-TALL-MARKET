// providers/banner_provider.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/banner_model.dart';

class BannerProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final List<BannerModel> _banners = [];
  bool isLoading = false;

  List<BannerModel> get banners => _banners;

  Future<void> fetchBanners() async {
    isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('banners')
          .select()
          .order('created_at', ascending: false);

      _banners.clear();
      _banners.addAll(
        (response as List).map((data) => BannerModel.fromJson(data))
      );
    } catch (e) {
      debugPrint('❌ Error fetching banners: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBanner(BannerModel banner) async {
    try {
      final response = await _supabase
          .from('banners')
          .insert(banner.toJson())
          .select()
          .single();

      _banners.add(BannerModel.fromJson(response));
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error adding banner: $e');
      rethrow;
    }
  }

  Future<void> updateBanner(BannerModel banner) async {
    try {
      await _supabase
          .from('banners')
          .update(banner.toJson())
          .eq('id', banner.id);

      final index = _banners.indexWhere((b) => b.id == banner.id);
      if (index != -1) {
        _banners[index] = banner;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error updating banner: $e');
      rethrow;
    }
  }

  Future<void> toggleBannerStatus(BannerModel banner) async {
    try {
      await _supabase
          .from('banners')
          .update({'is_active': !banner.isActive})
          .eq('id', banner.id);

      final index = _banners.indexWhere((b) => b.id == banner.id);
      if (index != -1) {
        _banners[index] = banner.copyWith(isActive: !banner.isActive);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error toggling banner status: $e');
      rethrow;
    }
  }

  Future<void> deleteBanner(String id) async {
    try {
      await _supabase
          .from('banners')
          .delete()
          .eq('id', id);

      _banners.removeWhere((b) => b.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error deleting banner: $e');
      rethrow;
    }
  }
}
