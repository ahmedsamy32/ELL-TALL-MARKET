try {
    val envClass = Class.forName("java.lang.ProcessEnvironment")
    val theEnvironmentField = envClass.getDeclaredField("theEnvironment")
    theEnvironmentField.isAccessible = true
    @Suppress("UNCHECKED_CAST")
    val env = theEnvironmentField.get(null) as MutableMap<String, String>
    env.remove("ANDROID_PREFS_ROOT")
    env.remove("ANDROID_SDK_HOME")

    val theCaseInsensitiveEnvironmentField = envClass.getDeclaredField("theCaseInsensitiveEnvironment")
    theCaseInsensitiveEnvironmentField.isAccessible = true
    @Suppress("UNCHECKED_CAST")
    val caseInsensitiveEnv = theCaseInsensitiveEnvironmentField.get(null) as MutableMap<String, String>
    caseInsensitiveEnv.remove("ANDROID_PREFS_ROOT")
    caseInsensitiveEnv.remove("ANDROID_SDK_HOME")
} catch (_: Exception) {}

pluginManagement {
    // استرجاع تحديد مسار Flutter من local.properties وربط flutter_tools
    val flutterSdkPath = run {
        val props = java.util.Properties()
        val local = file("local.properties")
        require(local.exists()) { "ملف local.properties غير موجود - أنشئه وضع flutter.sdk=<path>" }
        local.inputStream().use { props.load(it) }
        val path = props.getProperty("flutter.sdk")
        require(path != null) { "قيمة flutter.sdk غير معرفة داخل local.properties" }
        path
    }
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// الإضافات المتاحة لكل الوحدات
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.1" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

rootProject.name = "ell_tall_market"
include(":app")
