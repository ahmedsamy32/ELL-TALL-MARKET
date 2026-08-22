# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class org.chromium.** { *; }

# Prevent obfuscating GSON serialized fields (often used in plugins)
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.google.gson.** { *; }

# Supabase / Postgrest model classes mapping from JSON
-keep class com.supabase.** { *; }
-keep class io.github.jan.supabase.** { *; }

# Ignore missing Google Play Core classes referenced by Flutter's deferred components
-dontwarn com.google.android.play.core.**
