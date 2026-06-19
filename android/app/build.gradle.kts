plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.romagnago"
    compileSdk = flutter.compileSdkVersion
    // Allineato a geolocator_android / package_info_plus / path_provider_android (NDK 27).
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.romagnago"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // firebase_auth richiede minSdk 23 (API non disponibili sotto 21).
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
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

dependencies {
  implementation("com.graphhopper:graphhopper-core:8.0") {
    exclude(group = "org.codehaus.janino", module = "janino")
    exclude(group = "org.codehaus.janino", module = "commons-compiler")
    exclude(group = "org.codehaus.janino", module = "commons-compiler-jdk")
  }
  implementation("androidx.multidex:multidex:2.0.1")
  implementation("org.slf4j:slf4j-android:1.7.36")
}
