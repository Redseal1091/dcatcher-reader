package tachiyomi.core.common.util.system

import android.util.Log

enum class LogPriority(val priorityInt: Int) {
    VERBOSE(Log.VERBOSE),
    DEBUG(Log.DEBUG),
    INFO(Log.INFO),
    WARN(Log.WARN),
    ERROR(Log.ERROR),
    ASSERT(Log.ASSERT);

    companion object {
        val VERBOSE = LogPriority.VERBOSE
        val DEBUG = LogPriority.DEBUG
        val INFO = LogPriority.INFO
        val WARN = LogPriority.WARN
        val ERROR = LogPriority.ERROR
        val ASSERT = LogPriority.ASSERT
    }
}

inline fun Any.logcat(
    priority: LogPriority = LogPriority.DEBUG,
    throwable: Throwable? = null,
    message: () -> String = { "" },
) {
    val tag = this::class.java.simpleName.ifEmpty { "DCatcher" }.take(23)
    val msg = message()
    when (priority) {
        LogPriority.VERBOSE -> Log.v(tag, msg, throwable)
        LogPriority.DEBUG -> Log.d(tag, msg, throwable)
        LogPriority.INFO -> Log.i(tag, msg, throwable)
        LogPriority.WARN -> Log.w(tag, msg, throwable)
        LogPriority.ERROR -> Log.e(tag, msg, throwable)
        LogPriority.ASSERT -> Log.wtf(tag, msg, throwable)
    }
}

fun logcat(
    priority: LogPriority = LogPriority.DEBUG,
    throwable: Throwable? = null,
    message: () -> String = { "" },
) {
    val tag = "DCatcher"
    val msg = message()
    when (priority) {
        LogPriority.VERBOSE -> Log.v(tag, msg, throwable)
        LogPriority.DEBUG -> Log.d(tag, msg, throwable)
        LogPriority.INFO -> Log.i(tag, msg, throwable)
        LogPriority.WARN -> Log.w(tag, msg, throwable)
        LogPriority.ERROR -> Log.e(tag, msg, throwable)
        LogPriority.ASSERT -> Log.wtf(tag, msg, throwable)
    }
}
