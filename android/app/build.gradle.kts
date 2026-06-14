plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.scanswift"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // এটি ওল্ড ও নিউ সব কটলিন প্লাগইনেই পারফেক্টলি কাজ করবে
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // Your unique Application ID (use reverse-domain notation)
        applicationId = "com.example.scanswift"
        
        // গ্র্যাডল-এর লেটেস্ট রিকোয়ারমেন্ট অনুযায়ী ডিরেক্ট প্রপার্টি অ্যাসাইনমেন্ট
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
