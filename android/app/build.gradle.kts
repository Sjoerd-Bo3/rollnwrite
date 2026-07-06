plugins {
    alias(libs.plugins.android.application)
    // AGP 9's built-in Kotlin compiles this module — applying
    // org.jetbrains.kotlin.android alongside it is a hard error since AGP 9.0.
    // The Compose compiler plugin is still applied per-module.
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

// Release signing reads from env vars rather than a committed keystore/
// gradle.properties (the .jks never enters git). CI base64-decodes the
// PLAY_KEYSTORE_B64 secret to a temp file and passes its path here; a
// developer building locally can export the same three vars to produce a
// signed bundle by hand (see docs/PLAY.md). Both PLAY_KEYSTORE_FILE and
// PLAY_KEYSTORE_PASSWORD must be present for the signingConfig to attach —
// see the `hasReleaseSigning` gate below — so plain `./gradlew build` with no
// env vars keeps producing an unsigned build exactly as before.
val playKeystoreFile = System.getenv("PLAY_KEYSTORE_FILE")
val playKeystorePassword = System.getenv("PLAY_KEYSTORE_PASSWORD")
val hasReleaseSigning = !playKeystoreFile.isNullOrBlank() && !playKeystorePassword.isNullOrBlank()

// versionCode must strictly increase on every Play Console upload; CI passes
// PLAY_VERSION_CODE so it can auto-increment per release without a code edit.
// versionName stays hardcoded here — it's the human-facing version and only
// changes with a deliberate release decision.
val playVersionCode = (System.getenv("PLAY_VERSION_CODE") ?: "1").toInt()

android {
    namespace = "dev.bo3.rollnwrite"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.bo3.rollnwrite"
        minSdk = 26
        targetSdk = 36
        versionCode = playVersionCode
        versionName = "0.1.0"
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(playKeystoreFile!!)
                storePassword = playKeystorePassword
                keyAlias = "rollnwrite-upload"
                // Upload keystore uses one password for both store and key
                // (see docs/PLAY.md) — deliberately not a second env var.
                keyPassword = playKeystorePassword
            }
        }
    }

    buildTypes {
        release {
            // R8/minify is off for now: enabling it needs kotlinx.serialization
            // keep-rules (reflection-based serializers get stripped otherwise)
            // written and verified against a real release build first. Tracked
            // as a deliberate follow-up, not an oversight.
            isMinifyEnabled = false
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            // Without env vars, no signingConfig is attached and bundleRelease
            // produces an unsigned bundle — local ./gradlew build is unaffected.
        }
    }

    buildFeatures {
        compose = true
        // Generates BuildConfig.DEBUG, read by MainActivity to gate the
        // smokeTestGame intent-extra hook (the Android twin of iOS's
        // -smokeTestGame launch arg; CI-only, never true in release).
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    // No kotlinOptions/jvmTarget: with built-in Kotlin it defaults to
    // compileOptions.targetCompatibility (17 above).
}

dependencies {
    implementation(project(":engine"))

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons.extended)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.activity.compose)
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.kotlinx.serialization.json)

    debugImplementation(libs.compose.ui.tooling)
}
