buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath ("com.google.gms:google-services:4.3.15")
    }
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
    project.evaluationDependsOn(":app")
}

// Forzar compileSdk en todos los subproyectos para compatibilidad con printing plugin
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            (project.extensions.findByName("android") as? com.android.build.gradle.LibraryExtension)?.apply {
                compileSdk = 35
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
