package com.example.gaming_monitor_app

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class MainApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        // Preload Flutter engine → removes startup black screen
        val engine = FlutterEngine(this)

        // Use default Dart entrypoint (main)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        // Cache engine so MainActivity can reuse it instantly
        FlutterEngineCache.getInstance().put("preloaded_engine", engine)
    }
}
