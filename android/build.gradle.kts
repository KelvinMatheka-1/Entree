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

subprojects {
    if (project.name != "app") {
        val configureSdk = {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    val method = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                    method.invoke(android, 36)
                } catch (t: Throwable) {
                    try {
                        val method = android.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                        method.invoke(android, 36)
                    } catch (t2: Throwable) {
                        // Ignore if not present
                    }
                }
            }
        }
        if (state.executed) {
            configureSdk()
        } else {
            afterEvaluate {
                configureSdk()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
