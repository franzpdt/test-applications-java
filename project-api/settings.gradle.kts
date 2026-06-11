pluginManagement {
    repositories {
        maven("https://artifactory.lab.dynatrace.org/artifactory/gradle-plugins")
    }
}

dependencyResolutionManagement {
    repositoriesMode = RepositoriesMode.FAIL_ON_PROJECT_REPOS
    repositories {
        maven("https://artifactory.lab.dynatrace.org/artifactory/libs-release")
    }
}

rootProject.name = "project-api"
