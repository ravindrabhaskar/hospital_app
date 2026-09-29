# R8 keep rules for the CareCompanion Doctor release build.

# Flutter engine + plugin registrant
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
# Deferred components reference Play Core, which this app doesn't ship.
-dontwarn com.google.android.play.core.**

# Firebase / FCM / Google Play services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-keep class io.flutter.plugins.firebase.** { *; }

# flutter_local_notifications serialises scheduled notifications with Gson.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# flutter_secure_storage (Keystore/Tink)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**

# Keep the entry activity (referenced from the manifest).
-keep class com.carecompanion.doctor.MainActivity { *; }

# record (audio capture for the AI scribe) and pdfx (in-app PDF viewer)
-keep class com.llfbandit.record.** { *; }
-keep class io.scer.pdfx.** { *; }
-dontwarn io.scer.pdfx.**
