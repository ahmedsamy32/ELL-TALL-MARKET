import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Expose commonly used SDK versions for older plugin templates reading from rootProject.ext
extra["compileSdkVersion"] = 36
extra["targetSdkVersion"] = 36
extra["ndkVersion"] = "27.0.12077973"

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    plugins.withId("com.android.library") {
        val androidExt = extensions.findByName("android")
        if (androidExt is org.gradle.api.plugins.ExtensionAware) {
            if (androidExt.extensions.findByName("flutter") == null) {
                androidExt.extensions.add(
                    FlutterExtension::class.java,
                    "flutter",
                    FlutterExtension()
                )
            }
        }

        // Clean, type-safe configuration for all Android library subprojects (Flutter plugins)
        (androidExt as? BaseExtension)?.apply {
            compileSdkVersion(36)
            ndkVersion = "27.0.12077973"
            defaultConfig {
                targetSdkVersion(36)
            }
        }
    }

    val projectDir = project.projectDir.absolutePath
    val buildDir = newBuildDir.asFile.absolutePath
    val projectDrive = if (projectDir.contains(":\\")) projectDir.substringBefore(":\\").uppercase() else ""
    val buildDrive = if (buildDir.contains(":\\")) buildDir.substringBefore(":\\").uppercase() else ""

    if (projectDrive == buildDrive) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}

// Clean task to clear temporary build artifacts
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
