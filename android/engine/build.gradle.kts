// Pure-JVM module: game engines live here later. NO Android dependencies,
// so this module unit-tests fast (plain `java`/`kotlin` test task, no
// emulator/instrumentation, no AGP).
plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.serialization)
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(libs.kotlinx.serialization.json)

    testImplementation(libs.junit.jupiter)
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test {
    useJUnitPlatform()
    // Golden fixtures (spec/fixtures) live one level above the android/ root
    // and are shared with the iOS test target — single source of truth for
    // engine behaviour across platforms.
    systemProperty("fixtures.dir", rootDir.resolve("../spec/fixtures").absolutePath)
}
