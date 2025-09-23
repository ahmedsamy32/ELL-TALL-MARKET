import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/cart_model.dart';

class CartService {
  final _supabase = Supabase.instance.client;

  Future<CartModel> getUserCart(String userId) async {
    try {
      final response = await _supabase
          .from('carts')
          .select()
          .eq('user_id', userId)
          .single();

      return CartModel.fromMap({'id': response['id'], ...response});
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        // Create new cart if none exists (PGRST116 means no rows returned)
        final newCart = CartModel(
          id: userId,
          userId: userId,
          items: [],
          lastUpdated: DateTime.now(),
        );
        await _supabase.from('carts').insert(newCart.toMap());
        return newCart;
      }
      throw Exception('فشل تحميل سلة التسوق: ${e.toString()}');
    }
  }

  Future<void> updateUserCart(CartModel cart) async {
    try {
      await _supabase
          .from('carts')
          .update({
            'items': cart.items.map((item) => item.toMap()).toList(),
            'coupon_code': cart.couponCode,
            'coupon_discount': cart.couponDiscount,
            'last_updated': DateTime.now().toIso8601String(),
          })
          .eq('id', cart.id);
    } catch (e) {
      throw Exception('فشل تحديث سلة التسوق: ${e.toString()}');
    }
  }

  Future<void> clearUserCart(String userId) async {
    try {
      await _supabase
          .from('carts')
          .update({
            'items': [],
            'coupon_code': null,
            'coupon_discount': null,
            'last_updated': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('فشل تفريغ سلة التسوق: ${e.toString()}');
    }
  }

  Future<void> addToCart(String userId, CartItem item) async {
    try {
      final cart = await getUserCart(userId);
      cart.addItem(item);
      await updateUserCart(cart);
    } catch (e) {
      throw Exception('فشل إضافة المنتج إلى السلة: ${e.toString()}');
    }
  }

  Future<void> removeFromCart(String userId, String productId) async {
    try {
      final cart = await getUserCart(userId);
      cart.removeItem(productId);
      await updateUserCart(cart);
    } catch (e) {
      throw Exception('فشل إزالة المنتج من السلة: ${e.toString()}');
    }
  }

  Future<void> updateItemQuantity(
    String userId,
    String productId,
    int quantity,
  ) async {
    try {
      final cart = await getUserCart(userId);
      cart.updateQuantity(productId, quantity);
      await updateUserCart(cart);
    } catch (e) {
      throw Exception('فشل تحديث كمية المنتج: ${e.toString()}');
    }
  }

  Future<void> applyCoupon(
    String userId,
    String couponCode,
    double discount,
  ) async {
    try {
      final cart = await getUserCart(userId);
      final updatedCart = CartModel(
        id: cart.id,
        userId: cart.userId,
        items: cart.items,
        lastUpdated: DateTime.now(),
        couponCode: couponCode,
        couponDiscount: discount,
      );
      await updateUserCart(updatedCart);
    } catch (e) {
      throw Exception('فشل تطبيق الكوبون: ${e.toString()}');
    }
  }

  Future<void> removeCoupon(String userId) async {
    try {
      final cart = await getUserCart(userId);
      final updatedCart = CartModel(
        id: cart.id,
        userId: cart.userId,
        items: cart.items,
        lastUpdated: DateTime.now(),
        couponCode: null,
        couponDiscount: null,
      );
      await updateUserCart(updatedCart);
    } catch (e) {
      throw Exception('فشل إزالة الكوبون: ${e.toString()}');
    }
  }
}
