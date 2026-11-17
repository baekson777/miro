# =============================================================================
# Blind Weekly Maze — R8 / ProGuard keep rules
# Base file: proguard-android-optimize.txt (obfuscation + optimize maximized)
# =============================================================================

# ----- Flutter engine / embedding -----
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ----- Flutter JNI / deferred components -----
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ----- Google Mobile Ads (AdMob / GMA) -----
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.internal.ads.** { *; }
-keep class com.google.android.gms.ads.identifier.** { *; }

-dontwarn com.google.android.gms.**
-dontwarn com.google.ads.**
-dontwarn com.google.android.gms.ads.**

# ----- Firebase / Firestore -----
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ----- Kakao Flutter SDK (pigeon / AuthCodeHandler) -----
-keep class com.kakao.** { *; }
-keep class com.kakao.sdk.** { *; }
-keep class com.kakao.sdk.flutter.** { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
-dontwarn com.kakao.**
-dontwarn com.kakao.sdk.**

# Mediation adapters (safe if unused — prevents missing-class warnings)
-dontwarn com.google.ads.mediation.**
-keep class com.google.ads.mediation.** { *; }

# ----- screen_protector -----
-keep class com.prongbang.screenprotect.** { *; }
-keep class com.prongbang.screen_protector.** { *; }
-keep class **.ScreenProtectorPlugin { *; }
-keepclassmembers class **.ScreenProtectorPlugin {
    public <methods>;
    public <init>(...);
}

# ----- Play Core / multidex (referenced by Flutter tooling) -----
-dontwarn com.google.android.play.core.**
-keep class androidx.multidex.** { *; }

# ----- Kotlin / coroutines metadata -----
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-keepattributes SourceFile, LineNumberTable
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ----- Gson / reflection-friendly models (if Ads mediation uses them) -----
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ----- Keep native methods -----
-keepclasseswithmembernames class * {
    native <methods>;
}

# ----- Enums -----
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ----- Parcelable -----
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# ----- Serializables -----
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
