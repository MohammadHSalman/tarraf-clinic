import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
// Signing secrets are read from android/key.properties (git-ignored) when present,
// otherwise from the legacy private/ folder. If neither exists (CI, a fresh clone, a
// debug-only machine) the release build falls back to the debug key instead of failing.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val legacyPasswordFile = rootProject.file("../private/signing-password.txt")
val clinicPassword: String? = keyProps.getProperty("storePassword")
    ?: if (legacyPasswordFile.exists()) legacyPasswordFile.readText().trim() else null
val clinicStore = keyProps.getProperty("storeFile")?.let { rootProject.file(it) }
    ?: rootProject.file("../private/clinic-release.jks")
val hasClinicKey = clinicPassword != null && clinicStore.exists()
android {
    namespace = "com.tarraf.tarraf_clinic"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }
    defaultConfig {
        applicationId = "com.tarraf.clinic"
        minSdk = 24
        targetSdk = 35
        versionCode = 4
        versionName = "0.4.0"
    }
    signingConfigs {
        if (hasClinicKey) {
            create("clinicRelease") {
                storeFile = clinicStore
                storePassword = clinicPassword
                keyAlias = keyProps.getProperty("keyAlias") ?: "clinic"
                keyPassword = keyProps.getProperty("keyPassword") ?: clinicPassword
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (hasClinicKey) signingConfigs.getByName("clinicRelease")
                            else signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}
flutter { source = "../.." }
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.appcompat:appcompat:1.7.0")
}
