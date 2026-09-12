# Flutter Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Supabase & Ktor / OkHttp
-keep class com.supabase.** { *; }
-keep class io.ktor.** { *; }
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn io.ktor.**

# Sqflite & SQLite
-keep class com.tekartik.sqflite.** { *; }

# Cached Network Image & Glide
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**

# Preserve annotations and Kotlin attributes
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
