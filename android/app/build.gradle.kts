plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Activamos el plugin de Google
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.el_legendario_v2"
    compileSdk = 35 // <--- ESTABLECIDO EN 35 PARA EVITAR ERROR lStar
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // IMPORTANTE: Ponemos el ID de tu proyecto anterior para que el JSON de Firebase funcione
        applicationId = "com.example.legendarioapp" 
        
        // Forzamos mínimo 21 para Firebase
        minSdk = flutter.minSdkVersion
        targetSdk = 35 // <--- ESTABLECIDO EN 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
