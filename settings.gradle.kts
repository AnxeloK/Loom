pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenLocal()
        maven("https://repo.papermc.io/repository/maven-public/")
    }
}

plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

rootProject.name = "loom"
include("loom-api")
include("loom-server")

gradle.lifecycle.beforeProject {
    val mcVersion = providers.gradleProperty("mcVersion").get().trim()
    // Keep Bukkit API version parsing compatible with the canonical Paper/Spigot format.
    val versionString = "$mcVersion-R0.1-SNAPSHOT"
    version = versionString
}
