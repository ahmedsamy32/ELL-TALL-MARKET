# User Screens - Fixes Needed Summary

## Overview
Multiple user screens have compilation errors due to:
1. ProfileModel doesn't have `address` field
2. Missing methods in SupabaseProvider
3. OrderStatus enum conflicts
4. Product Model field mismatches

## Critical Fixes Needed

### 1. checkout_screen.dart
**Errors:**
- ProfileModel has no `address` field (lines 39, 40)
- OrderModel missing required parameters: `storeId`, `deliveryFee`, `taxAmount`, `paymentMethod`, `paymentStatus`
- OrderModel has no `merchantId` or `notes` parameters
- OrderStatus conflict between two files

**Fix:**
```dart
// Remove address references from ProfileModel
// Use address from addresses table instead

// Fix OrderModel constructor:
import 'package:ell_tall_market/models/order_model.dart' hide OrderStatus;

final order = OrderModel(
  id: '',
  userId: authProvider.currentUser!.id,
  storeId: cartProvider.cartItems.first.product.storeId, // Get from cart
  totalAmount: cartProvider.totalPrice,
  deliveryFee: 0.0, // Calculate or set
  taxAmount: 0.0, // Calculate or set
  deliveryAddress: fullAddress,
  status: OrderStatus.pending, // Use enum from order_enums.dart
  paymentMethod: PaymentMethod.cash, // Default
  paymentStatus: PaymentStatus.pending, // Default
  createdAt: DateTime.now(),
);
```

### 2. edit_profile_screen.dart
**Errors:**
- ProfileModel constructor doesn't exist as method
- No `address` field in ProfileModel
- Missing methods: `updateUser`, `updatePassword`, `deleteUser` in SupabaseProvider

**Fix:**
```dart
// Remove address field:
final updatedUser = ProfileModel(
  id: authProvider.currentUserProfile!.id,
  fullName: _nameController.text.trim(),
  email: authProvider.currentUserProfile!.email,
  phone: _phoneController.text.trim(),
  avatarUrl: _pickedImage?.path ?? authProvider.currentUserProfile!.avatarUrl,
  role: authProvider.currentUserProfile!.role,
  isActive: authProvider.currentUserProfile!.isActive,
  createdAt: authProvider.currentUserProfile!.createdAt,
  updatedAt: DateTime.now(),
);

// Use updateProfile instead of updateUser
final result = await authProvider.updateProfile(updatedUser);

// For password update, use:
await authProvider.updatePasswordWithSupabase(_newPasswordController.text);

// For delete, user needs to implement or remove feature
```

### 3. home_screen.dart
**Errors:**
- ProfileModel has no `address` field (lines 187-190)

**Fix:**
```dart
// Remove address display or fetch from addresses table
// Replace with:
String deliveryAddress = 'أضف عنوان التوصيل';
// Or fetch from addresses provider
```

### 4. order_tracking_screen.dart
**Errors:**
- OrderStatus conflict
- `order.status` is already OrderStatus, not string
- `deliveryAddress` is non-nullable

**Fix:**
```dart
import 'package:ell_tall_market/models/order_model.dart' hide OrderStatus;

// Use order.status.value to convert to string:
final status = OrderStatusExtension.fromDbValue(order.status.value);

// Remove ?? 'غير متوفر' from deliveryAddress:
_buildDetailRow('العنوان', order.deliveryAddress),
```

### 5. payment_methods_screen.dart
**Errors:**
- Missing method: `updatePreferredPayment` in SupabaseProvider

**Fix:**
```dart
// Either implement the method in SupabaseProvider or remove the feature
// For now, comment out or remove:
// await authProvider.updatePreferredPayment(selectedMethod);
```

### 6. product_detail_screen.dart
**Errors:**
- ProductModel has no `isInStock` field

**Fix:**
```dart
// Use isAvailable or inStock:
color: widget.product.isAvailable ? Colors.green : Colors.red,
```

### 7. store_detail_Screen.dart & stores_screen.dart
**Errors:**
- SafeNetworkImage expects non-nullable String but store.imageUrl is nullable

**Fix:**
```dart
// Add null check:
imageUrl: store.imageUrl ?? '',
// Or use:
imageUrl: store.imageUrl!,  // if you're sure it's not null
```

## Methods Needed in SupabaseProvider

Add these methods to `lib/providers/supabase_provider.dart`:

```dart
/// Update user profile
Future<ProfileModel?> updateProfile(ProfileModel profile) async {
  try {
    await Supabase.instance.client
        .from('profiles')
        .update(profile.toMap())
        .eq('id', profile.id);
    
    _currentProfile = profile;
    notifyListeners();
    return profile;
  } catch (e) {
    _error = 'Update profile error: $e';
    AppLogger.error('Update profile error', e);
    return null;
  }
}

/// Delete user account
Future<({bool success, String? message})> deleteUser(String userId) async {
  try {
    await Supabase.instance.client.auth.admin.deleteUser(userId);
    await signOut();
    return (success: true, message: null);
  } catch (e) {
    return (success: false, message: e.toString());
  }
}

/// Update preferred payment method
Future<void> updatePreferredPayment(String paymentMethod) async {
  try {
    await Supabase.instance.client
        .from('profiles')
        .update({'preferred_payment': paymentMethod})
        .eq('id', _currentUser!.id);
    notifyListeners();
  } catch (e) {
    _error = 'Update payment error: $e';
    AppLogger.error('Update payment error', e);
  }
}
```

## Priority Order

1. **HIGH PRIORITY**: Fix OrderStatus conflicts (add `hide OrderStatus` to imports)
2. **HIGH PRIORITY**: Remove all `address` field references from ProfileModel
3. **MEDIUM PRIORITY**: Fix ProductModel field references (`isInStock` → `isAvailable`)
4. **MEDIUM PRIORITY**: Add missing methods to SupabaseProvider
5. **LOW PRIORITY**: Fix nullable/non-nullable String issues

## Quick Fix Commands

To quickly fix OrderStatus conflicts in all files:
```dart
// Add this to all files with OrderStatus errors:
import 'package:ell_tall_market/models/order_model.dart' hide OrderStatus;
```

To fix Product model issues:
```dart
// Replace isInStock with:
product.isAvailable  // or product.inStock
```

## Testing After Fixes

After applying fixes:
1. Run `flutter pub get`
2. Run `flutter analyze` to check for remaining errors
3. Test each screen individually
4. Focus on auth flows first (profile, edit profile)
5. Then test ordering flows (checkout, tracking)

## Notes

- The codebase has multiple OrderStatus definitions (one in order_model.dart, one in order_enums.dart)
- ProfileModel structure changed - address field was removed
- ProductModel uses `inStock` and `stockQuantity`, not `isInStock` and `stock`
- OrderModel structure is complex with many required fields
