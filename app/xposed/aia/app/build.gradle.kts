plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.hereisderek.aia.xposed"
    compileSdk = 34

    signingConfigs {
        create("release") {
            storeFile = file("../../../../key.keystore")
            storePassword = "mypassword123"
            keyAlias = "key"
            keyPassword = "mypassword123"
        }
    }

    defaultConfig {
        applicationId = "com.hereisderek.aia.xposed"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    compileOnly("de.robv.android.xposed:api:82")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.9.0")
    implementation("androidx.preference:preference-ktx:1.2.1")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
}
