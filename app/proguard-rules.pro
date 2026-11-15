# ProGuard rules for AI Form & Vault

# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags from
# the Android Gradle Plugin, and will be applied to release builds.

# Keep names of classes/members needed for reflection, JNI, etc.
-keep class com.aiformvault.** { *; }

# Keep ML Kit classes
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }

# Keep AndroidX classes
-keep class androidx.** { *; }

# Keep ViewModel / Compose related
-keep class androidx.lifecycle.* { *; }
-keep class androidx.compose.* { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve entry points
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

# Don't obfuscate model/data classes used with reflection (JSON, Room, etc.)
-keep class com.aiformvault.ModelKt { *; }
-keep class com.aiformvault.VaultData { *; }
-keep class com.aiformvault.Document { *; }
-keep class com.aiformvault.Person { *; }
-keep class com.aiformvault.Fact { *; }

# R8 warnings suppression (non-fatal)
-dontwarn com.google.android.gms.**
-dontwarn androidx.**
