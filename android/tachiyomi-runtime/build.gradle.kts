plugins {
    id("com.android.library")
    id("kotlin-android")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "eu.kanade.tachiyomi.source"
    compileSdk = 36

    defaultConfig {
        minSdk = 26
        consumerProguardFiles("consumer-proguard.pro")
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
        freeCompilerArgs += listOf(
            "-opt-in=kotlin.RequiresOptIn",
            "-opt-in=kotlinx.serialization.ExperimentalSerializationApi",
            "-opt-in=kotlinx.coroutines.ExperimentalCoroutinesApi",
            "-Xcontext-parameters"
        )
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

dependencies {
    // Injekt Dependency Injection (Required by extensions & HttpSource)
    api("uy.kohesive.injekt:injekt-core:1.16.1")

    // Networking (OkHttp 5.4.0, Logging, DoH, Brotli, Zstd aligned with Keiyoushi KeiSource ABI)
    val okhttpVersion = "5.4.0"
    api("com.squareup.okhttp3:okhttp:$okhttpVersion")
    api("com.squareup.okhttp3:logging-interceptor:$okhttpVersion")
    api("com.squareup.okhttp3:okhttp-dnsoverhttps:$okhttpVersion")
    api("com.squareup.okhttp3:okhttp-brotli:$okhttpVersion")
    api("com.squareup.okhttp3:okhttp-zstd:$okhttpVersion")
    api("com.squareup.okio:okio:3.10.2")

    // Reactive Extensions (RxJava 1.x required by legacy Tachiyomi API bridge)
    api("io.reactivex:rxjava:1.3.8")

    // HTML / DOM Parsing
    api("org.jsoup:jsoup:1.18.1")

    // QuickJS JavaScript engine
    api("app.cash.quickjs:quickjs-android:0.9.2")

    // Coroutines
    api("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")
    api("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    // KotlinX Serialization & XML
    api("org.jetbrains.kotlinx:kotlinx-serialization-json:1.11.0")
    api("org.jetbrains.kotlinx:kotlinx-serialization-protobuf:1.11.0")
    api("org.jetbrains.kotlinx:kotlinx-serialization-json-okio:1.11.0")
    api("io.github.pdvrieze.xmlutil:core-android:0.86.3")
    api("io.github.pdvrieze.xmlutil:serialization:0.86.3")

    // AndroidX & Preferences & WebKit & Compose Runtime
    api("androidx.core:core-ktx:1.13.1")
    api("androidx.preference:preference-ktx:1.2.1")
    api("androidx.webkit:webkit:1.18.0")
    api("androidx.compose.runtime:runtime:1.6.8")

    // Testing
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlin:kotlin-test:2.2.20")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
}
