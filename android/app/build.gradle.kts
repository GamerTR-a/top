import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("com.google.firebase.firebase-perf")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Güvenlik: key.properties eksikse release/bundle görevleri debug anahtarına
// SESSİZCE düşmesin — CI'da imzalama secret'ı unutulursa Play Store'a
// debug-signed bir paket yüklenme riskini önlemek için build'i sert hatayla durdur.
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { task ->
        task.name.contains("Release") || task.name.contains("release")
    }
    if (buildingRelease && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "android/key.properties bulunamadı! Release/bundle derlemesi için gerekli " +
            "(bkz. android/key.properties.template). CI ortamında bu dosya secret'lardan " +
            "oluşturulmalı — aksi halde imzasız/debug-signed bir paket üretilir."
        )
    }
}

android {
    namespace = "com.Nevgenc"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (görev 1/10 — zamanlanmış hatırlatıcılar)
        // java.time tabanlı API'ler için desugaring gerektiriyor.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.Nevgenc"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // key.properties yoksa taskGraph.whenReady guard'ı zaten build'i
            // durduracak; burada artık debug anahtarına sessiz düşme yok.
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true

            ndk {
                // "NONE" hiçbir ayrı sembol tablosu üretmiyordu — bu da
                // Flutter'ın release-AAB doğrulamasının aradığı
                // libflutter.so.sym/.dbg meta verisini bulamayıp derlemeyi
                // "failed to strip debug symbols" hatasıyla durdurmasına yol
                // açıyordu (native .so'lar zaten stripli olsa bile). Ayrıca
                // "NONE" Play Console'un native çökmeleri sembolize etmesini
                // de imkansız kılıyordu. "SYMBOL_TABLE": çalışma zamanı
                // .so'ları yine stripli kalır, yalnızca ayrı/küçük bir sembol
                // tablosu Play Console'un kullanımı için pakete eklenir.
                debugSymbolLevel = "SYMBOL_TABLE"
            }
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // flutter_local_notifications için zorunlu (bkz. compileOptions yorumu).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
