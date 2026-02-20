package com.anmt2805.news_crawl

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.anmt2805.news_crawl/app_config"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "storeFlavor" -> result.success(getString(R.string.store_flavor))
                else -> result.notImplemented()
            }
        }
    }
}
