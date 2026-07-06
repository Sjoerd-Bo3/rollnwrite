// Root build file: declares plugin versions once via the catalog so every
// module applies them without re-resolving versions (keeps :engine and :app
// in lockstep). No plugin is actually applied here — each module opts in.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}
