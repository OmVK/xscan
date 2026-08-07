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
    afterEvaluate {
        val androidExt = project.extensions.findByName("android")
        if (androidExt is com.android.build.gradle.BaseExtension) {
            // AGP 8 requires a namespace on every module, but some legacy
            // pub.dev plugins (isar_flutter_libs) ship without one.
            if (androidExt.namespace.isNullOrEmpty()) {
                androidExt.namespace = "com.xscan.plugin.${project.name}"
            }
            if (androidExt.compileSdkVersion == "android-37") {
                androidExt.compileSdkVersion(36)
            }
            // Old plugins (isar_flutter_libs) default to a low compileSdk
            // (e.g. android-30), which fails AGP's AAR metadata checks against
            // modern androidx dependencies. Bump anything below 33 to 36.
            val compileSdkNumeric =
                androidExt.compileSdkVersion
                    ?.removePrefix("android-")
                    ?.toIntOrNull()
            if (compileSdkNumeric != null && compileSdkNumeric < 33) {
                androidExt.compileSdkVersion(36)
            }

            // AGP 8 also rejects the legacy `package="…"` attribute in library
            // AndroidManifest.xml files. Strip it so old plugins (isar_flutter_libs)
            // build, using the namespace assigned above.
            val mainManifest = androidExt.sourceSets.getByName("main").manifest.srcFile
            val stripManifestPackage = project.tasks.register(
                "stripManifestPackageFor${project.name.replace(Regex("[^A-Za-z0-9_]"), "")}",
            ) {
                onlyIf {
                    mainManifest.isFile &&
                        mainManifest.readText().contains(Regex("""package="[^"]*""""))
                }
                doLast {
                    val text = mainManifest.readText()
                    mainManifest.writeText(
                        text.replace(
                            Regex("""\s+package="[^"]*""""),
                            "",
                        ),
                    )
                }
            }
            project.tasks
                .matching { it is com.android.build.gradle.tasks.ProcessLibraryManifest }
                .configureEach {
                    dependsOn(stripManifestPackage)
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
