buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
        classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    configurations.configureEach {
        resolutionStrategy {
            force("org.tensorflow:tensorflow-lite:2.16.1")
            force("org.tensorflow:tensorflow-lite-gpu:2.16.1")
            force("org.tensorflow:tensorflow-lite-api:2.16.1")
            force("org.tensorflow:tensorflow-lite-support:0.4.4")
        }
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
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android")
            try {
                android::class.java.getMethod("setCompileSdk", Int::class.javaPrimitiveType).invoke(android, 36)
            } catch (e: Exception) {
                try {
                    android::class.java.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType).invoke(android, 36)
                } catch (e2: Exception) {
                    // Ignore
                }
            }
        }
        
        project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            val javaCompileTask = project.tasks.findByName(name.replace("Kotlin", "JavaWithJavac")) as? JavaCompile
            if (javaCompileTask != null) {
                val javaTarget = javaCompileTask.targetCompatibility
                val target = when (javaTarget) {
                    "1.8", "8" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                    "11" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                    "17" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                    "21" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
                    else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                }
                compilerOptions.jvmTarget.set(target)
            } else {
                compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
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
