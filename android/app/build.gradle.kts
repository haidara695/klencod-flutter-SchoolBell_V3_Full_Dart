plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "com.haidara.schoolbell"
    compileSdk = 35
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }
    defaultConfig {
        applicationId = "com.haidara.schoolbell"
        minSdk = 23
        targetSdk = 35
        versionCode = 3
        versionName = "3.0.0"
    }
}
dependencies {
    implementation("androidx.core:core:1.15.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
flutter { source = "../.." }
