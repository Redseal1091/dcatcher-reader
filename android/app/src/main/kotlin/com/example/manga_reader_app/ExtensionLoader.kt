package com.example.manga_reader_app

import android.app.Application
import android.content.Context
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.SourceFactory
import java.io.File

object ExtensionLoader {

    @Volatile
    private var isDiBootstrapped = false

    fun resetDiBootstrapForTesting() {
        isDiBootstrapped = false
    }

    fun bootstrapDi(context: Context): Result<Unit> {
        if (isDiBootstrapped) return Result.success(Unit)
        val application = context.applicationContext as? Application
            ?: return Result.failure(
                IllegalStateException("Application context is required for RuntimeBootstrap initialization")
            )

        return try {
            val bootstrapClass = Class.forName("com.dcatcher.runtime.RuntimeBootstrap")
            val method = bootstrapClass.getMethod("initialize", Application::class.java)
            method.invoke(null, application)
            isDiBootstrapped = true
            Result.success(Unit)
        } catch (e: ClassNotFoundException) {
            Result.failure(
                IllegalStateException(
                    "Required dependency 'com.dcatcher.runtime.RuntimeBootstrap' was not found in runtime classpath",
                    e
                )
            )
        } catch (e: Exception) {
            Result.failure(
                IllegalStateException("RuntimeBootstrap.initialize failed: ${e.message}", e)
            )
        } catch (e: LinkageError) {
            Result.failure(
                IllegalStateException("RuntimeBootstrap.initialize linkage error: ${e.message}", e)
            )
        }
    }

    fun loadExtension(
        context: Context,
        apkFile: File,
        metadata: ExtensionMetadata
    ): Result<List<Source>> {
        if (!apkFile.exists() || !apkFile.isFile) {
            return Result.failure(SecurityException("Extension APK file not found at ${apkFile.absolutePath}"))
        }

        // Android 14+ Dynamic Code Loading security requirement:
        // Dynamically loaded code files must be read-only BEFORE ClassLoader is invoked, fail closed!
        if (apkFile.canWrite()) {
            if (!apkFile.setReadOnly() || apkFile.canWrite()) {
                return Result.failure(
                    SecurityException("Failed to mark APK as read-only before class loading at ${apkFile.absolutePath}")
                )
            }
        }

        val diResult = bootstrapDi(context)
        if (diResult.isFailure) {
            return Result.failure(diResult.exceptionOrNull()!!)
        }

        val librarySearchPath = context.applicationInfo?.nativeLibraryDir
        val classLoader = try {
            DelegateLastClassLoaderCompat.create(
                apkFile.absolutePath,
                librarySearchPath,
                context.classLoader
            )
        } catch (e: Exception) {
            return Result.failure(
                SecurityException("Failed to create class loader for ${apkFile.absolutePath}: ${e.message}", e)
            )
        } catch (e: LinkageError) {
            return Result.failure(
                SecurityException("Failed to create class loader for ${apkFile.absolutePath} due to linkage error: ${e.message}", e)
            )
        }

        val loadedSources = mutableListOf<Source>()

        for (className in metadata.classNames) {
            try {
                val clazz = Class.forName(className, false, classLoader)
                if (metadata.isFactory || SourceFactory::class.java.isAssignableFrom(clazz)) {
                    val constructor = clazz.getDeclaredConstructor()
                    constructor.isAccessible = true
                    val factory = constructor.newInstance() as SourceFactory
                    val factorySources = factory.createSources()
                    if (factorySources.isNullOrEmpty()) {
                        return Result.failure(
                            SecurityException("SourceFactory $className produced zero sources")
                        )
                    }
                    loadedSources.addAll(factorySources)
                } else if (Source::class.java.isAssignableFrom(clazz)) {
                    val constructor = clazz.getDeclaredConstructor()
                    constructor.isAccessible = true
                    val source = constructor.newInstance() as Source
                    loadedSources.add(source)
                } else {
                    return Result.failure(
                        SecurityException("Class $className does not implement Source or SourceFactory")
                    )
                }
            } catch (e: Exception) {
                return Result.failure(
                    SecurityException("Failed to instantiate extension class $className: ${e.message}", e)
                )
            } catch (e: LinkageError) {
                return Result.failure(
                    SecurityException("Failed to instantiate extension class $className due to linkage error: ${e.message}", e)
                )
            }
        }

        if (loadedSources.isEmpty()) {
            return Result.failure(
                SecurityException("Extension APK ${metadata.packageName} contains no active sources")
            )
        }

        return Result.success(loadedSources)
    }
}
