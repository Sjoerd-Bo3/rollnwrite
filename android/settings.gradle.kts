pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// :engine pins jvmToolchain(17); without a resolver Gradle can only use a
// locally auto-detected JDK 17, so builds break on machines/CI images that
// ship a different JDK. Foojay auto-provisions the toolchain anywhere.
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "rollnwrite"

include(":engine")
include(":app")
