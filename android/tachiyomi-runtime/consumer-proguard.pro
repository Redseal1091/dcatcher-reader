# Preserve reflection metadata, generic signatures (required by Injekt & Kotlin serialization), and annotations
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod

# Keep DCatcher runtime bootstrap and Tachiyomi/Mihon extension API surfaces
-keep class com.dcatcher.runtime.** { *; }
-keep class eu.kanade.tachiyomi.** { *; }
-keep interface eu.kanade.tachiyomi.** { *; }
-keep class tachiyomi.** { *; }
-keep interface tachiyomi.** { *; }
-keep class mihon.** { *; }
-keep interface mihon.** { *; }
-keep class logcat.** { *; }

# Keep Network and Interceptor class names (KeiSource reflects simpleName)
-keepnames class eu.kanade.tachiyomi.network.interceptor.** { *; }

# Preserve HttpSource header delegate for KeiSource reflection
-keepclassmembers class eu.kanade.tachiyomi.source.online.HttpSource {
    private final kotlin.Lazy headers$delegate;
    public final okhttp3.Headers getHeaders();
}

# Injekt reads the injected type from the generic superclass of its type tokens
-keep,allowshrinking class * extends uy.kohesive.injekt.api.FullTypeReference
-keep class uy.kohesive.injekt.** { *; }
-keep interface uy.kohesive.injekt.** { *; }

# Keep common dependencies exposed to dynamically loaded Keiyoushi extensions
-keep,allowoptimization class androidx.preference.** { public protected *; }
-keep,allowoptimization class androidx.webkit.** { public protected *; }
-keep,allowoptimization class androidx.core.content.ContextCompat { public protected *; }
-keep,allowoptimization class androidx.core.net.** { public protected *; }
-keep,allowoptimization class kotlin.** { public protected *; }
-keep,allowoptimization class kotlinx.coroutines.** { public protected *; }
-keep,allowoptimization class kotlinx.serialization.** { *; }
-keep,allowoptimization class kotlin.time.** { public protected *; }

# OkHttp & Okio (including compression codecs & MultipartBody)
-keep,allowoptimization class okhttp3.** { public protected *; }
-keep,allowoptimization interface okhttp3.** { public protected *; }
-keepclasseswithmembers class okhttp3.MultipartBody$Builder { *; }
-keep class okhttp3.CompressionInterceptor { *; }
-keep class okhttp3.Gzip { *; }
-keep class okhttp3.brotli.** { *; }
-keep class okhttp3.zstd.** { *; }
-keep class com.squareup.zstd.** { *; }
-keep,allowoptimization class okio.** { public protected *; }
-keep,allowoptimization interface okio.** { public protected *; }

# HTML / JS / XML parsers
-keep,allowoptimization class org.jsoup.** { public protected *; }
-keep,allowoptimization class app.cash.quickjs.** { *; }
-keep class nl.adaptivity.xmlutil.** { *; }
-keep public enum nl.adaptivity.xmlutil.EventType { *; }

# RxJava 1.x
-keep,allowoptimization class rx.** { public protected *; }
-dontwarn sun.misc.**
-keepclassmembers class rx.internal.util.unsafe.*ArrayQueue*Field* {
    long producerIndex;
    long consumerIndex;
}
-keepclassmembers class rx.internal.util.unsafe.BaseLinkedQueueProducerNodeRef {
    rx.internal.util.atomic.LinkedQueueNode producerNode;
}
-keepclassmembers class rx.internal.util.unsafe.BaseLinkedQueueConsumerNodeRef {
    rx.internal.util.atomic.LinkedQueueNode consumerNode;
}
-dontnote rx.internal.util.PlatformDependent

# kotlinx.serialization helpers
-dontnote kotlinx.serialization.**
-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class eu.kanade.**$$serializer { *; }
-keepclassmembers class eu.kanade.** {
    *** Companion;
}
-keepclasseswithmembers class eu.kanade.** {
    kotlinx.serialization.KSerializer serializer(...);
}
