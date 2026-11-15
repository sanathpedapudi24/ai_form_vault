plugins {
    id("com.android.application") version "8.13.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.20" apply false
    // Room's annotation processor, kept on a version that matches the Kotlin compiler exactly.
    id("com.google.devtools.ksp") version "2.2.20-2.0.4" apply false
}
