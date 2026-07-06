plugins {
    alias(libs.plugins.android.application)
    // AGP 9's built-in Kotlin compiles this module — applying
    // org.jetbrains.kotlin.android alongside it is a hard error since AGP 9.0.
    // The Compose compiler plugin is still applied per-module.
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "dev.bo3.rollnwrite"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.bo3.rollnwrite"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }

    buildFeatures {
        compose = true
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
