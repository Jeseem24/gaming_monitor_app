package com.example.gaming_monitor_app

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class MainApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        // ----------------------------------------------
        // PRELOAD FLUTTER ENGINE (fixes 3–5s black screen)
        // ----------------------------------------------
        val engine = FlutterEngine(this)

        // Use default entrypoint (main.dart → main())
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        // Cache engine
        FlutterEngineCache.getInstance()
            .put("preloaded_engine", engine)
    }
}
