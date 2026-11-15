plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.devtools.ksp")
}

// Release signing is opt-in: only applied when all four RELEASE_* environment
// variables are present AND the keystore file actually exists. This keeps
// `assembleDebug`/`lint`/tests working on any machine and in CI without secrets.
val releaseStoreFilePath = System.getenv("RELEASE_STORE_FILE").orEmpty()
val releaseStorePassword = System.getenv("RELEASE_STORE_PASSWORD").orEmpty()
val releaseKeyAlias = System.getenv("RELEASE_KEY_ALIAS").orEmpty()
val releaseKeyPassword = System.getenv("RELEASE_KEY_PASSWORD").orEmpty()
val hasReleaseSigning =
    releaseStoreFilePath.isNotBlank() &&
        rootProject.file(releaseStoreFilePath).exists() &&
        releaseStorePassword.isNotBlank() &&
        releaseKeyAlias.isNotBlank() &&
        releaseKeyPassword.isNotBlank()

android {
    namespace = "com.aiformvault"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.aiformvault.ai_form_vault"
        minSdk = 26
        targetSdk = 36
        versionCode = 19
        versionName = "4.3.0"
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(releaseStoreFilePath)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (hasReleaseSigning) signingConfig = signingConfigs.getByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures { compose = true }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

repositories {
    google()
    mavenCentral()
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2025.09.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.10.0")
    implementation("androidx.compose.material:material-icons-core")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.fragment:fragment-ktx:1.8.5")
    implementation("androidx.biometric:biometric:1.1.0")
    implementation("androidx.work:work-runtime-ktx:2.11.2")
    implementation("com.google.android.gms:play-services-mlkit-document-scanner:16.0.0")
    implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1")
    // Devanagari fallback (issue #8). Only invoked when the Latin pass finds no name, so it does not
    // double normal OCR cost; unbundled like the Latin model, so the download happens on first use.
    implementation("com.google.android.gms:play-services-mlkit-text-recognition-devanagari:16.0.2")
    // Vault metadata: SQLite rows behind SQLCipher (issue #12). `sqlcipher-android` is the maintained
    // successor to android-database-sqlcipher; it still needs the native library loaded once per process.
    implementation("androidx.room:room-runtime:2.7.2")
    implementation("androidx.room:room-ktx:2.7.2")
    implementation("net.zetetic:sqlcipher-android:4.6.1")
    ksp("androidx.room:room-compiler:2.7.2")
    testImplementation("junit:junit:4.13.2")
}
