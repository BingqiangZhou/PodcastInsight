# ProGuard rules for Personal AI Assistant
# Personal AI Assistant 的混淆规则

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn io.flutter.embedding.**

# Retrofit
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Signature
-keepattributes Exceptions

# OkHttp
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Okio
-dontwarn okio.**
-keep class okio.** { *; }

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Riverpod
-keep class androidx.compose.** { *; }

# Audio service
-keep class com.ryanheise.audioservice.** { *; }

# Just Audio
-keep class com.ryanheise.just_audio.** { *; }

# SQLite
-keep class android.database.** { *; }

# XML StAX API (added as dependency in build.gradle.kts)
-keep class javax.xml.stream.** { *; }
-keep class org.apache.tika.** { *; }
-keep class com.fasterxml.woodstox.** { *; }
-keep class org.codehaus.stax2.** { *; }
-dontwarn aQute.bnd.annotation.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
