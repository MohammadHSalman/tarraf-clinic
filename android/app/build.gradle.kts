plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
val clinicPassword = rootProject.file("../private/signing-password.txt").readText().trim()
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
        create("clinicRelease") {
            storeFile = rootProject.file("../private/clinic-release.jks")
            storePassword = clinicPassword
            keyAlias = "clinic"
            keyPassword = clinicPassword
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("clinicRelease")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}
flutter { source = "../.." }
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.appcompat:appcompat:1.7.0")
}
