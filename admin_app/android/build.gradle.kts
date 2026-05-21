import com.android.build.gradle.LibraryExtension

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
    project.evaluationDependsOn(":app")
}

// Older Flutter plugins (e.g. flutter_bluetooth_serial) lack `android.namespace` required by AGP 8+.
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
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
