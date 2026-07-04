# R8/ProGuard keep rules for the Terminal POS app.
# Flutter plugins ship their own consumer rules; these cover reflection/AIDL
# based dependencies that R8 cannot trace into.

# --- Flutter engine / embedding (defensive; harmless if already kept) ---
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# --- Sunmi built-in printer SDK (AIDL service + reflection) ---
-keep class com.sunmi.** { *; }
-keep interface com.sunmi.** { *; }
-keep class woyou.aidlservice.** { *; }
-keep interface woyou.aidlservice.** { *; }
-dontwarn com.sunmi.**
-dontwarn woyou.aidlservice.**

# --- flutter_local_notifications (Gson-serialized notification models) ---
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# --- Attributes needed by Gson-style reflection ---
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
