package com.example.english_village

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "globalvillage/post-lesson-comedy",
            ComedyViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )
    }
}
