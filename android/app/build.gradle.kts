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
    // Kotlin standard library (JDK7)
    val kotlin_version = "1.9.0" // Replace with the version you need
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version")

    // Core desugaring for using Java 8+ APIs
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase BoM: Keeps all Firebase versions aligned
    implementation(platform("com.google.firebase:firebase-bom:33.12.0"))

    // Firebase SDKs (Version is determined by BoM, no version specified here)
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-appcheck-playintegrity") // Optional: for App Check

    // Google Play Services (for Auth, SafetyNet, etc.)
    implementation("com.google.android.gms:play-services-auth:20.5.0")
}
