package com.example.manga_reader_app

import eu.kanade.tachiyomi.source.Source
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

object SourceAccessSessions {
    const val EXTRA_SESSION_TOKEN = "sourceAccessSession"

    data class Session(
        val source: Source,
        val homeUrl: String
    )

    private val sessions = ConcurrentHashMap<String, Session>()

    fun create(source: Source, homeUrl: String): String {
        val token = UUID.randomUUID().toString()
        sessions[token] = Session(source = source, homeUrl = homeUrl)
        return token
    }

    fun get(token: String): Session? {
        return sessions[token]
    }

    fun remove(token: String): Session? {
        return sessions.remove(token)
    }

    fun clear() {
        sessions.clear()
    }
}
