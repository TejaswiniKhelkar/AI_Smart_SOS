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

// Workaround: With android.builtInKotlin=false, AGP 9 does not provide built-in
// Kotlin. Some plugins (e.g. file_picker) skip applying org.jetbrains.kotlin.android
// when AGP >= 9, expecting built-in Kotlin. This ensures the Kotlin plugin is applied
// to any Android library subproject that still needs it, with a matching JVM target.
subprojects {
    project.plugins.withId("com.android.library") {
        if (!project.plugins.hasPlugin("org.jetbrains.kotlin.android")) {
            project.plugins.apply("org.jetbrains.kotlin.android")
            project.extensions.findByType(
                org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java
            )?.compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
