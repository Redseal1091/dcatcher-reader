package com.dcatcher.runtime

import android.app.Application
import android.content.Context
import eu.kanade.tachiyomi.network.JavaScriptEngine
import eu.kanade.tachiyomi.network.NetworkHelper
import eu.kanade.tachiyomi.network.NetworkPreferences
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json
import kotlinx.serialization.protobuf.ProtoBuf
import nl.adaptivity.xmlutil.serialization.XML
import tachiyomi.core.common.preference.AndroidPreferenceStore
import tachiyomi.core.common.preference.PreferenceStore
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.addSingleton

object RuntimeBootstrap {
    @Volatile
    private var isReady = false
    private val lock = Any()

    /**
     * Component factory seam for testability and regression tests without requiring
     * Android framework stubs or live device environment.
     */
    interface ComponentFactory {
        fun createPreferenceStore(context: Context): PreferenceStore
        fun createNetworkPreferences(store: PreferenceStore): NetworkPreferences
        fun createNetworkHelper(context: Context, preferences: NetworkPreferences): NetworkHelper
        fun createJavaScriptEngine(context: Context): JavaScriptEngine
        fun createJson(): Json
        fun createProtoBuf(): ProtoBuf
        fun createXml(): XML
    }

    internal class DefaultComponentFactory : ComponentFactory {
        override fun createPreferenceStore(context: Context): PreferenceStore =
            AndroidPreferenceStore(context)

        override fun createNetworkPreferences(store: PreferenceStore): NetworkPreferences =
            NetworkPreferences(store)

        override fun createNetworkHelper(context: Context, preferences: NetworkPreferences): NetworkHelper =
            NetworkHelper(context, preferences)

        override fun createJavaScriptEngine(context: Context): JavaScriptEngine =
            JavaScriptEngine(context)

        override fun createJson(): Json = Json {
            ignoreUnknownKeys = true
            explicitNulls = false
            isLenient = true
            coerceInputValues = true
        }

        @OptIn(ExperimentalSerializationApi::class)
        override fun createProtoBuf(): ProtoBuf = ProtoBuf {
            encodeDefaults = true
        }

        override fun createXml(): XML = XML {}
    }

    @Volatile
    internal var componentFactory: ComponentFactory = DefaultComponentFactory()

    @JvmStatic
    fun initialize(application: Application) {
        // Fast-path read without lock
        if (isReady) return

        synchronized(lock) {
            // Double-checked locking
            if (isReady) return

            try {
                val context: Context = application.applicationContext
                val factory = componentFactory

                val preferenceStore = factory.createPreferenceStore(context)
                val networkPreferences = factory.createNetworkPreferences(preferenceStore)
                val networkHelper = factory.createNetworkHelper(context, networkPreferences)
                val jsEngine = factory.createJavaScriptEngine(context)
                val json = factory.createJson()
                val protoBuf = factory.createProtoBuf()
                val xml = factory.createXml()

                with(Injekt) {
                    addSingleton<Application>(application)
                    addSingleton<Context>(context)
                    addSingleton<PreferenceStore>(preferenceStore)
                    addSingleton<NetworkPreferences>(networkPreferences)
                    addSingleton<NetworkHelper>(networkHelper)
                    addSingleton<JavaScriptEngine>(jsEngine)
                    addSingleton<Json>(json)
                    addSingleton<ProtoBuf>(protoBuf)
                    addSingleton<XML>(xml)
                }

                // Transactional commit: marked ready ONLY after all registrations succeed
                isReady = true
            } catch (t: Throwable) {
                // Ensure isReady remains false so subsequent attempts can retry
                isReady = false
                throw t
            }
        }
    }

    @JvmStatic
    val isInitialized: Boolean
        get() = isReady

    /**
     * Internal reset hook strictly for isolated test suites.
     */
    internal fun resetForTesting(factory: ComponentFactory = DefaultComponentFactory()) {
        synchronized(lock) {
            isReady = false
            componentFactory = factory
        }
    }
}
