import com.android.build.gradle.BaseExtension
import com.android.build.api.dsl.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}

// Expose commonly used SDK versions for older plugin templates reading from rootProject.ext
extra["compileSdkVersion"] = 36
extra["targetSdkVersion"] = 36
extra["ndkVersion"] = "27.0.12077973"

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val projectDir = project.projectDir.absolutePath
    val buildDir = newBuildDir.asFile.absolutePath
    val projectDrive = if (projectDir.contains(":\\")) projectDir.substringBefore(":\\").uppercase() else ""
    val buildDrive = if (buildDir.contains(":\\")) buildDir.substringBefore(":\\").uppercase() else ""

    if (projectDrive == buildDrive) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }

    val applyConfig = Action<Project> {
        plugins.withId("com.android.library") {
            val androidExt = extensions.findByName("android")
            if (androidExt is LibraryExtension) {
                androidExt.compileSdk = 36
                androidExt.ndkVersion = "27.0.12077973"
            } else if (androidExt is BaseExtension) {
                androidExt.compileSdkVersion(36)
                androidExt.ndkVersion = "27.0.12077973"
                androidExt.defaultConfig.targetSdkVersion(36)
            }
        }
    }

    if (state.executed) {
        applyConfig.execute(this)
    } else {
        afterEvaluate {
            applyConfig.execute(this)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Clean task to clear temporary build artifacts
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
