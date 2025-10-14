allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Expose commonly used SDK versions for older plugin templates reading from rootProject.ext
extra["compileSdkVersion"] = 36
extra["targetSdkVersion"] = 36

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Force all Android modules to use compileSdk 36 using reflection to avoid type issues
    afterEvaluate {
        val androidExtension = extensions.findByName("android")
        if (androidExtension != null) {
            try {
                // Set compileSdk using reflection
                val compileSdkMethod = androidExtension.javaClass.methods.find {
                    it.name == "setCompileSdk" && it.parameterTypes.size == 1 && it.parameterTypes[0] == Int::class.java
                }
                compileSdkMethod?.invoke(androidExtension, 36)

                // Fallback for older AGP versions
                val compileSdkVersionMethod = androidExtension.javaClass.methods.find {
                    it.name == "setCompileSdkVersion" && it.parameterTypes.size == 1 && it.parameterTypes[0] == Int::class.java
                }
                compileSdkVersionMethod?.invoke(androidExtension, 36)

                // Set targetSdk in defaultConfig
                val defaultConfigMethod = androidExtension.javaClass.methods.find { it.name == "getDefaultConfig" }
                val defaultConfig = defaultConfigMethod?.invoke(androidExtension)
                if (defaultConfig != null) {
                    val targetSdkMethod = defaultConfig.javaClass.methods.find {
                        it.name == "setTargetSdk" && it.parameterTypes.size == 1 && it.parameterTypes[0] == Int::class.java
                    }
                    targetSdkMethod?.invoke(defaultConfig, 36)

                    // Fallback for older versions
                    val targetSdkVersionMethod = defaultConfig.javaClass.methods.find {
                        it.name == "setTargetSdkVersion" && it.parameterTypes.size == 1 && it.parameterTypes[0] == Int::class.java
                    }
                    targetSdkVersionMethod?.invoke(defaultConfig, 36)
                }
            } catch (e: Exception) {
                // Silently ignore errors to avoid breaking non-Android subprojects
                println("Warning: Could not set compileSdk for ${project.name}: ${e.message}")
            }
        }
    }
}

// مهمة clean لمسح الملفات المؤقتة
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
