# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# flutter_local_notifications (uses reflection for notification details)
-keep class com.dexterous.** { *; }

# Keep generic signatures for Gson/serialization used by plugins
-keepattributes Signature
-keepattributes *Annotation*

# Google Play Core (deferred components) — not used, silence R8 missing-class warnings
-dontwarn com.google.android.play.core.**
