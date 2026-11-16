# Keep Tachiyomi extension source interfaces and models
-keep class eu.kanade.tachiyomi.source.** { *; }
-keep interface eu.kanade.tachiyomi.source.** { *; }

# Keep Network and Interceptor class names (KeiSource reflects simpleName)
-keepnames class eu.kanade.tachiyomi.network.interceptor.** { *; }
-keep class eu.kanade.tachiyomi.network.** { *; }
-keep interface eu.kanade.tachiyomi.network.** { *; }

# Keep OkHttp compression interceptor and codecs required by KeiSource
-keep class okhttp3.CompressionInterceptor { *; }
-keep class okhttp3.Gzip { *; }
-keep class okhttp3.brotli.** { *; }
-keep class okhttp3.zstd.** { *; }
-keep class com.squareup.zstd.** { *; }

# Keep Injekt injection points
-keep class uy.kohesive.injekt.** { *; }
-keep interface uy.kohesive.injekt.** { *; }

# Preserve HttpSource header delegate for KeiSource reflection
-keepclassmembers class eu.kanade.tachiyomi.source.online.HttpSource {
    private final kotlin.Lazy headers$delegate;
    public final okhttp3.Headers getHeaders();
}

# Preserve serializers and QuickJS
-keep class kotlinx.serialization.** { *; }
-keep class app.cash.quickjs.** { *; }
-keep class nl.adaptivity.xmlutil.** { *; }
