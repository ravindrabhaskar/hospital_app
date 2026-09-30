# R8 keep rules for the CareCompanion All-in-One demo build: the union of the
# patient, provider and doctor apps' rules.

# ---- Flutter engine + plugin registrant ---------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
# Deferred components reference Play Core, which this app doesn't ship.
-dontwarn com.google.android.play.core.**

# ---- Razorpay (patient app) ----------------------------------------------
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
-dontwarn proguard.annotation.Keep
-dontwarn proguard.annotation.KeepClassMembers

# ---- Firebase / FCM / Google Play services -------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-keep class io.flutter.plugins.firebase.** { *; }

# ---- flutter_local_notifications (Gson for scheduled notifications) ------
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ---- flutter_secure_storage (Keystore/Tink) ------------------------------
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.google.errorprone.annotations.**

# ---- record (doctor AI scribe) and pdfx (in-app PDF viewer) ---------------
-keep class com.llfbandit.record.** { *; }
-keep class io.scer.pdfx.** { *; }
-dontwarn io.scer.pdfx.**

# ---- Entry activity (referenced from the manifest) -----------------------
-keep class com.carecompanion.allinone.MainActivity { *; }

# ---- Kotlin / AndroidX misc -----------------------------------------------
-dontwarn kotlin.**
-dontwarn javax.annotation.**
