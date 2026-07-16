# google_mlkit_text_recognition ships one plugin class that references every
# regional script recognizer (Chinese/Japanese/Korean/Devanagari), but we
# only depend on the Latin + Devanagari script models. R8 fails hard on the
# unresolved references to script packages we didn't pull in — tell it
# they're fine to skip.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# google_sign_in v7 uses Credential Manager. R8 must not strip the
# Google ID token request path or credential-result callbacks.
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class androidx.credentials.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.api.HasApiAvailability { *; }
-dontwarn com.google.android.gms.common.GoogleApiAvailability
