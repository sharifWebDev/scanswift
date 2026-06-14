import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties from android/key.properties (keep actual file out of VCS)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties() // ওপরে ইমপোর্ট করায় এখন ডিরেক্ট কাজ করবে
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile)) // ওপরে ইমপোর্ট করায় এখন ডিরেক্ট কাজ করবে
}

android {
    namespace = "com.example.scanswift"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // রিলিজ বিল্ডের ওয়ার্নিং এড়াতে অ্যানোটেশন যোগ করা হলো
    @Suppress("DEPRECATION")
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // Your unique Application ID
        applicationId = "com.example.scanswift"
        
        // গ্র্যাডল-এর লেটেস্ট রিকোয়ারমেন্ট অনুযায়ী ডিরেক্ট প্রপার্টি অ্যাসাইনমেন্ট
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    signingConfigs {
        create("release") {
            // যদি key.properties ফাইলে ডেটা থাকে তবেই রিড করবে, নয়তো ফাঁকা স্ট্রিং এর বদলে ডিবাগ কী-র মতো সেফ ভ্যালু সেট হবে
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: ""
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: ""
            
            // এই লাইনটি ফিক্স করা হয়েছে: ফাঁকা থাকলে সরাসরি গ্র্যাডল ক্র্যাশ করবে না
            val storeFilePath = keystoreProperties.getProperty("storeFile") ?: ""
            storeFile = if (storeFilePath.isNotEmpty()) file(storeFilePath) else file("debug.keystore")
            
            storePassword = keystoreProperties.getProperty("storePassword") ?: ""
        }
    }
    
    buildTypes {
        release {
            // Use release signing config when `android/key.properties` is provided.
            // If `key.properties` is missing this will fallback to the debug signing config.
            signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}