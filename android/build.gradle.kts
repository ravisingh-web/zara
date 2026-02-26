// Root build.gradle.kts — Z.A.R.A. Project
// ✅ GitHub Actions Compatible • Repository Config • Build Dir Setup

allprojects {
    repositories {
        google()
        mavenCentral()
        // Optional: JitPack for third-party libs
        // maven { url = uri("https://jitpack.io") }
    }
}

// ✅ Custom build directory (helps with GitHub Actions caching)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// ✅ Clean task for CI/CD
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
    delete(fileTree(mapOf("dir" to "build", "include" to "**/*.apk")))
}

// ✅ Cache-friendly configuration for GitHub Actions
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    kotlinOptions {
        // Faster compilation for CI
        freeCompilerArgs += "-Xskip-prerelease-check"
    }
}
