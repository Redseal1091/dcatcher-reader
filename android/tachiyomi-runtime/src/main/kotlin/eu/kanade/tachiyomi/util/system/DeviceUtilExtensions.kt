package eu.kanade.tachiyomi.util.system

import android.os.Build

val DeviceUtil.isDynamicColorAvailable by lazy {
    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
}
