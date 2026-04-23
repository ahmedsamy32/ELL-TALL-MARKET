import 'package:flutter/material.dart';
import 'package:ell_tall_market/models/order_enums.dart';
import 'package:ell_tall_market/utils/app_colors.dart';

/// دوال مساعدة موحّدة لشاشات الكابتن
/// تجمع الدوال المكررة في مكان واحد بدلاً من تكرارها في كل شاشة
class CaptainOrderHelpers {
  CaptainOrderHelpers._();

  // ===== حالات فلتر شاشة الطلبات (مرتبة وبدون تكرار) =====
  static const List<OrderStatus> captainFilterStatuses = [
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.pickedUp,
    OrderStatus.inTransit,
    OrderStatus.delivered,
  ];

  /// إزالة الحالات المكررة مع الحفاظ على الترتيب
  static List<OrderStatus> filterDuplicateStatuses(
    Iterable<OrderStatus> statuses,
  ) {
    final seen = <OrderStatus>{};
    final unique = <OrderStatus>[];
    for (final status in statuses) {
      if (seen.add(status)) {
        unique.add(status);
      }
    }
    return unique;
  }

  // ===== حدود الوقت SLA (معايير الأداء) =====
  static const int slaAcceptSeconds = 90;
  static const int slaHeadingToStoreMinutes = 15;
  static const int slaWaitAtStoreMinutes = 10;
  static const int slaDeliveryMinutes = 40;

  // ===== مراحل سيناريو التوصيل الكاملة (State Machine) =====
  static const List<OrderStatus> deliveryStages = [
    OrderStatus.confirmed, // الكابتن قَبِل — في الطريق للمتجر
    OrderStatus.preparing, // وصل للمتجر — ينتظر الطلب
    OrderStatus.pickedUp, // استلم الطلب — في الطريق للعميل
    OrderStatus.inTransit, // وصل للعميل — جاهز للتسليم
    OrderStatus.delivered, // تم التسليم ✓
  ];

  /// هل الانتقال بين حالتين صحيح؟ (State Machine)
  static bool canTransition(OrderStatus from, OrderStatus to) {
    // دعم انتقالات مرنة لحالة ready لأنها قد تأتي من المتجر أو مباشرة للكابتن
    if (from == OrderStatus.ready && to == OrderStatus.pickedUp) {
      return true;
    }

    final fromIdx = deliveryStages.indexOf(from);
    final toIdx = deliveryStages.indexOf(to);
    return fromIdx != -1 && toIdx == fromIdx + 1;
  }

  // ===== لون الحالة =====
  static Color getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.blueGrey;
      case OrderStatus.confirmed:
        return AppColors.info;
      case OrderStatus.preparing:
        return Colors.deepOrange;
      case OrderStatus.ready:
        return Colors.purple;
      case OrderStatus.pickedUp:
        return Colors.teal;
      case OrderStatus.inTransit:
        return AppColors.primary;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.danger;
    }
  }

  // ===== أيقونة المرحلة في مؤشر التقدم =====
  static IconData getStageIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return Icons.directions_bike_rounded;
      case OrderStatus.preparing:
        return Icons.store_rounded;
      case OrderStatus.pickedUp:
        return Icons.inventory_2_rounded;
      case OrderStatus.inTransit:
        return Icons.location_on_rounded;
      case OrderStatus.delivered:
        return Icons.verified_rounded;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  // ===== نص الحالة بالعربي =====
  static String getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'في الانتظار';
      case OrderStatus.confirmed:
        return 'في الطريق للمتجر';
      case OrderStatus.preparing:
        return 'في المتجر';
      case OrderStatus.ready:
        return 'جاهز للاستلام';
      case OrderStatus.pickedUp:
        return 'تم الاستلام';
      case OrderStatus.inTransit:
        return 'وصل للعميل';
      case OrderStatus.delivered:
        return 'تم التوصيل';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }

  // ===== الحالة التالية للكابتن =====
  static OrderStatus getNextStatus(OrderStatus currentStatus) {
    switch (currentStatus) {
      case OrderStatus.confirmed:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.pickedUp;
      case OrderStatus.ready:
        return OrderStatus.pickedUp;
      case OrderStatus.pickedUp:
        return OrderStatus.inTransit;
      case OrderStatus.inTransit:
        return OrderStatus.delivered;
      default:
        return currentStatus;
    }
  }

  // ===== نص زر الإجراء الوحيد Single CTA (شاشة التوصيل) =====
  static String getDeliveryActionText(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return 'وصلت للمتجر 🏪';
      case OrderStatus.preparing:
        return 'استلمت الطلب 📦';
      case OrderStatus.ready:
        return 'استلمت الطلب وانطلقت 🚚';
      case OrderStatus.pickedUp:
        return 'وصلت للعميل 📍';
      case OrderStatus.inTransit:
        return 'تأكيد التسليم ✅';
      case OrderStatus.delivered:
        return 'تم التوصيل بنجاح ✓';
      default:
        return 'تحديث الحالة';
    }
  }

  // ===== نص الإجراء في لوحة التحكم =====
  static String getDashboardActionText(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return 'توجه للمتجر';
      case OrderStatus.preparing:
        return 'استلام الطلب';
      case OrderStatus.ready:
        return 'استلام وانطلاق';
      case OrderStatus.pickedUp:
        return 'وصلت للعميل';
      case OrderStatus.inTransit:
        return 'تأكيد التسليم';
      case OrderStatus.delivered:
        return 'مكتمل ✓';
      default:
        return 'تحديث الحالة';
    }
  }

  // ===== نص الإجراء في قائمة الطلبات =====
  static String getOrdersActionText(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return 'في الطريق للمتجر';
      case OrderStatus.preparing:
        return 'استلام وبدء التوصيل';
      case OrderStatus.ready:
        return 'قبول الطلب';
      case OrderStatus.pickedUp:
        return 'وصلت للعميل';
      case OrderStatus.inTransit:
        return 'تم التسليم للعميل';
      default:
        return 'تحديث الحالة';
    }
  }

  // ===== أيقونة الإجراء =====
  static IconData getActionIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return Icons.directions_bike_rounded;
      case OrderStatus.preparing:
        return Icons.inventory_2_rounded;
      case OrderStatus.ready:
        return Icons.local_shipping_rounded;
      case OrderStatus.pickedUp:
        return Icons.location_on_rounded;
      case OrderStatus.inTransit:
        return Icons.check_circle_rounded;
      case OrderStatus.delivered:
        return Icons.verified_rounded;
      default:
        return Icons.update_rounded;
    }
  }

  // ===== اسم المرحلة في مؤشر التقدم =====
  static String getStageName(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return 'للمتجر';
      case OrderStatus.preparing:
        return 'في المتجر';
      case OrderStatus.pickedUp:
        return 'الاستلام';
      case OrderStatus.inTransit:
        return 'عند العميل';
      case OrderStatus.delivered:
        return 'تم التسليم';
      default:
        return '';
    }
  }

  // ===== هل يحتاج تأكيد قبل الإجراء؟ =====
  static bool requiresConfirmation(OrderStatus nextStatus) =>
      nextStatus == OrderStatus.delivered;

  // ===== رسالة تأكيد الإجراء =====
  static String getConfirmationMessage(OrderStatus nextStatus) {
    if (nextStatus == OrderStatus.delivered) {
      return 'هل تأكد أنك سلّمت الطلب للعميل بشكل كامل؟\nهذا الإجراء لا يمكن التراجع عنه.';
    }
    return 'هل تريد الاستمرار؟';
  }

  // ===== هل يمكن للكابتن الذهاب أوفلاين؟ =====
  static bool canGoOffline(List<dynamic> activeOrders) => activeOrders.isEmpty;

  // ===== نسبة عمولة الكابتن الثابتة =====
  static const double commissionRate = 0.10;

  // ===== حساب عمولة الكابتن =====
  static double calculateCommission(double orderTotal) =>
      orderTotal * commissionRate;
}
