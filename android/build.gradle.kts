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
    // Algunos plugins (file_picker, flutter_plugin_android_lifecycle...) compilan
    // contra un compileSdk antiguo (35) y exigen >= 36. Forzamos 36 en todos los
    // módulos Android para alinearlos con la app. Registrar antes de que el
    // subproyecto se evalúe (evaluationDependsOn solo evalúa :app).
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
            compileSdkVersion(36)
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
