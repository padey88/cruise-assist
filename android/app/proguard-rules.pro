# Cruise Assist ProGuard rules.
# Flutter engine and plugin registrant are reflectively referenced.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep our platform channel + projection classes: referenced from the manifest
# and from MethodChannel lookups by name.
-keep class my.kulnem.cruise_assist.** { *; }

# AndroidX Car App is resolved reflectively when the car host is present.
-dontwarn androidx.car.**
-keep class androidx.car.app.** { *; }

# Play Core deferred components are referenced by the Flutter engine but not
# shipped by this app.
-dontwarn com.google.android.play.core.**
