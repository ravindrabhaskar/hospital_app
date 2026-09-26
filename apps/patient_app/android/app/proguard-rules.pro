# ---- Flutter ------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
# Deferred components / Play Core are referenced by the engine but unused.
-dontwarn com.google.android.play.core.**

# ---- Razorpay (https://razorpay.com/docs/payments/payment-gateway/android-integration/standard/) ----
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-optimizations !method/inlining/
-keepclasseswithmembers class * {
    public void onPayment*(...);
}
# Razorpay's proguard notes also ask to keep these.
-dontwarn proguard.annotation.Keep
-dontwarn proguard.annotation.KeepClassMembers

# ---- Firebase / Google Play services ------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ---- flutter_local_notifications (uses Gson for scheduled notifications) --
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ---- Kotlin / AndroidX misc ---------------------------------------------
-dontwarn kotlin.**
-dontwarn javax.annotation.**
