# google_mlkit_text_recognition ships one plugin class that references every
# regional script recognizer (Chinese/Japanese/Korean/Devanagari), but we
# only depend on the Latin + Devanagari script models. R8 fails hard on the
# unresolved references to script packages we didn't pull in — tell it
# they're fine to skip.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
