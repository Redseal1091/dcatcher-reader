package tachiyomi.core.common.preference

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class InMemoryPreferenceStore : PreferenceStore {

    private val values = mutableMapOf<String, Any?>()

    override fun getString(key: String, defaultValue: String): Preference<String> =
        InMemoryPreference(key, defaultValue)

    override fun getLong(key: String, defaultValue: Long): Preference<Long> =
        InMemoryPreference(key, defaultValue)

    override fun getInt(key: String, defaultValue: Int): Preference<Int> =
        InMemoryPreference(key, defaultValue)

    override fun getFloat(key: String, defaultValue: Float): Preference<Float> =
        InMemoryPreference(key, defaultValue)

    override fun getBoolean(key: String, defaultValue: Boolean): Preference<Boolean> =
        InMemoryPreference(key, defaultValue)

    override fun getStringSet(key: String, defaultValue: Set<String>): Preference<Set<String>> =
        InMemoryPreference(key, defaultValue)

    override fun <T> getObjectFromString(
        key: String,
        defaultValue: T,
        serializer: (T) -> String,
        deserializer: (String) -> T,
    ): Preference<T> = InMemoryPreference(key, defaultValue)

    override fun <T> getObjectFromInt(
        key: String,
        defaultValue: T,
        serializer: (T) -> Int,
        deserializer: (Int) -> T,
    ): Preference<T> = InMemoryPreference(key, defaultValue)

    override fun <T> getObjectSetFromStringSet(
        key: String,
        defaultValue: Set<T>,
        serializer: (T) -> String,
        deserializer: (String) -> T?,
    ): Preference<Set<T>> = InMemoryPreference(key, defaultValue)

    override fun getAll(): Map<String, *> = synchronized(values) {
        values.toMap()
    }

    private inner class InMemoryPreference<T>(
        private val key: String,
        private val defaultValue: T,
    ) : Preference<T> {
        private val flow = MutableStateFlow(get())

        override fun key(): String = key

        @Suppress("UNCHECKED_CAST")
        override fun get(): T = synchronized(values) {
            values.getOrElse(key) { defaultValue } as T
        }

        override fun set(value: T) {
            synchronized(values) {
                values[key] = value
            }
            flow.update { value }
        }

        override fun isSet(): Boolean = synchronized(values) {
            values.containsKey(key)
        }

        override fun delete() {
            synchronized(values) {
                values.remove(key)
            }
            flow.update { defaultValue }
        }

        override fun defaultValue(): T = defaultValue

        override fun changes(): Flow<T> = flow.asStateFlow()

        override fun stateIn(scope: CoroutineScope): StateFlow<T> = flow.asStateFlow()
    }
}
