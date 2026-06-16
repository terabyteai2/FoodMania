# R8/ProGuard keep rules for the Admin app.
# Flutter plugins ship their own consumer rules; these cover reflection/AIDL
# based dependencies that R8 cannot trace into.

# --- Flutter engine / embedding (defensive; harmless if already kept) ---
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# --- Built-in printer vendor SDKs (sunmi_printer_plus / imin_printer /
#     flutter_pax_printer_utility) — none of the three ship their own
#     consumer ProGuard rules, so we keep their AIDL/reflection-based
#     classes here. PAX's NeptuneLiteApi is the most reflection-heavy; if a
#     release build crashes on real PAX hardware that targeted keep rules
#     don't fix, the plugin's README falls back to disabling minification
#     entirely for that build — try widening these rules first. ---
-keep class com.sunmi.** { *; }
-keep interface com.sunmi.** { *; }
-keep class woyou.aidlservice.** { *; }
-keep interface woyou.aidlservice.** { *; }
-dontwarn com.sunmi.**
-dontwarn woyou.aidlservice.**
-keep class com.imin.** { *; }
-dontwarn com.imin.**
-keep class com.pax.** { *; }
-dontwarn com.pax.**

# --- Facebook Login SDK (reflection) ---
-keep class com.facebook.** { *; }
-dontwarn com.facebook.**

# --- flutter_local_notifications (Gson-serialized notification models) ---
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# --- Attributes needed by Gson-style reflection ---
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
