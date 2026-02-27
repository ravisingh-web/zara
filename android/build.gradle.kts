// Root build.gradle.kts — Z.A.R.A. Project
// ✅ GitHub Actions Compatible • compilerOptions DSL • No Deprecation Errors

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Custom build directory for caching
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
}

// ✅ Kotlin compiler options using NEW compilerOptions DSL (not deprecated kotlinOptions)
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        freeCompilerArgs.add("-Xskip-prerelease-check")
    }
}
