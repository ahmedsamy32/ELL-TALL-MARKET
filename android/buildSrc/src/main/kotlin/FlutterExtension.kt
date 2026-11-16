/**
 * FlutterExtension - يُعرِّف خصائص Flutter SDK المطلوبة في Kotlin DSL
 *
 * المكتبات الحديثة (مثل device_info_plus 13.x) تستخدم Kotlin DSL وتبحث عن
 * خاصية `flutter` على مستوى android extension. هذا الـ class يُتيح الوصول
 * الآمن من خلال Kotlin DSL في Compile-time.
 */
open class FlutterExtension {
    var compileSdkVersion: Int = 36
    var minSdkVersion: Int = 24
    var targetSdkVersion: Int = 36
    var ndkVersion: String = "27.0.12077973"
}
