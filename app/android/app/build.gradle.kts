import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val rootKeystorePropertiesFile = rootProject.file("key.properties")
val localKeystorePropertiesFile = project.file("key.properties")
val keystorePropertiesFile =
    if (rootKeystorePropertiesFile.exists()) rootKeystorePropertiesFile else localKeystorePropertiesFile
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.anmt2805.news_crawl"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.anmt2805.news_crawl"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Keep only app-supported locales in packaged Android resources to reduce AAB size.
        resourceConfigurations.addAll(listOf("en", "ko", "ja", "fr", "es", "ru", "ar"))
    }

    signingConfigs {
        create("release") {
            val keyAliasValue = keystoreProperties["keyAlias"] as? String
            val keyPasswordValue = keystoreProperties["keyPassword"] as? String
            val storeFileValue = keystoreProperties["storeFile"] as? String
            val storePasswordValue = keystoreProperties["storePassword"] as? String
            requireNotNull(keyAliasValue) { "keyAlias missing in key.properties" }
            requireNotNull(keyPasswordValue) { "keyPassword missing in key.properties" }
            requireNotNull(storeFileValue) { "storeFile missing in key.properties" }
            requireNotNull(storePasswordValue) { "storePassword missing in key.properties" }
            keyAlias = keyAliasValue
            keyPassword = keyPasswordValue
            storeFile = File(keystorePropertiesFile.parentFile, storeFileValue)
            storePassword = storePasswordValue
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.ads.mediation:unity:4.12.2.0")
    implementation("com.unity3d.ads:unity-ads:4.12.2")
}
