import com.android.build.api.variant.AndroidComponentsExtension
import com.android.build.api.dsl.LibraryExtension

val androidLibraryCompileSdk = 36
val posTerminalMinSdk = 22
val isPosTerminalBuild =
    providers.gradleProperty("posTerminalBuild").orNull.toBoolean() ||
        System.getenv("POS_TERMINAL_BUILD").orEmpty().let {
            it.equals("true", ignoreCase = true) || it == "1"
        }

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    configurations.configureEach {
        if (isPosTerminalBuild) {
            resolutionStrategy.force(
                "androidx.activity:activity:1.8.1",
                "androidx.activity:activity-ktx:1.8.1",
                "androidx.core:core:1.13.1",
                "androidx.core:core-ktx:1.13.1",
            )
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Older Flutter plugins can lack `android.namespace` required by AGP 8+.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<LibraryExtension>("android") {
            if (namespace.isNullOrBlank()) {
                val manifest = project.file("src/main/AndroidManifest.xml")
                if (manifest.exists()) {
                    val match =
                        Regex("""package\s*=\s*["']([^"']+)["']""")
                            .find(manifest.readText())
                    if (match != null) {
                        namespace = match.groupValues[1]
                    }
                }
            }
        }

        extensions.configure<AndroidComponentsExtension<LibraryExtension, *, *>>("androidComponents") {
            finalizeDsl { extension ->
                if ((extension.compileSdk ?: 0) < androidLibraryCompileSdk) {
                    extension.compileSdk = androidLibraryCompileSdk
                }
                if (isPosTerminalBuild && (extension.defaultConfig.minSdk ?: 1) > posTerminalMinSdk) {
                    extension.defaultConfig.minSdk = posTerminalMinSdk
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
