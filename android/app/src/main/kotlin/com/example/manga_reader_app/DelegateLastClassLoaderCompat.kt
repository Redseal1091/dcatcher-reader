package com.example.manga_reader_app

import android.os.Build
import dalvik.system.DelegateLastClassLoader
import dalvik.system.PathClassLoader

object DelegateLastClassLoaderCompat {

    fun create(dexPath: String, librarySearchPath: String?, parent: ClassLoader): ClassLoader {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            DelegateLastClassLoader(dexPath, librarySearchPath, parent)
        } else {
            PathClassLoader(dexPath, librarySearchPath, parent)
        }
    }
}
