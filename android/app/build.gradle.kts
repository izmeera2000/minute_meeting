plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // Wajib selepas plugin Android & Kotlin
}

android {
    namespace = "com.example.minute_meeting"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true // Penting untuk notifikasi
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.minute_meeting"
        minSdk = 23 // Firebase_auth memerlukan min SDK 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    val kotlin_version = "1.9.0" // Ganti versi ini ikut keperluan projek anda
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
