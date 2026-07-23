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
// Old plugins (fijkplayer_plus) declare a compileSdk below 31, which breaks
// resource linking against modern AndroidX (android:attr/lStar). Raise every
// library module to the app's compileSdk. Registered before the
// evaluationDependsOn block below, which is what triggers project evaluation.
subprojects {
    if (name != "app") {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
                ?.let { androidExt ->
                    // Raise every library module to the app's compileSdk.
                    val appCompileSdk = project(":app")
                        .extensions
                        .getByType(com.android.build.gradle.BaseExtension::class.java)
                        .compileSdkVersion
                    if (appCompileSdk != null) {
                        androidExt.compileSdkVersion(appCompileSdk)
                    }
                    // Force Kotlin JVM target to match Java target compatibility.
                    // Fixes "Inconsistent JVM-target compatibility" errors in plugins like tflite_flutter.
                    androidExt.compileOptions.apply {
                        sourceCompatibility = JavaVersion.VERSION_17
                        targetCompatibility = JavaVersion.VERSION_17
                    }
                    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                        compilerOptions {
                            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                        }
                    }
                }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}