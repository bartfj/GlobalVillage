package com.example.english_village

import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.json.JSONObject
import java.io.ByteArrayInputStream

/** A renderer for this app's one bundled document, with no network/navigation. */
class ComedyViewFactory(
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: throw IllegalArgumentException("Missing comedy config")
        val loader = io.flutter.FlutterInjector.instance().flutterLoader()
        val catalogAsset = loader.getLookupKeyForAsset("assets/dialogues/post_lesson_comedy_catalog.json")
        val catalog = context.assets.open(catalogAsset).bufferedReader().use { JSONObject(it.readText()) }
        val episodes = catalog.getJSONArray("episodes")
        val sceneIds = (0 until episodes.length()).map { episodes.getJSONObject(it).getString("id") }.toSet()
        val scene = params["scene"] as? String
        require(scene in sceneIds && params["english"] is Boolean &&
            params["reducedMotion"] is Boolean && params["chinese"] is Boolean) { "Invalid comedy config" }
        val config = JSONObject().put("scene", scene).put("english", params["english"])
            .put("reducedMotion", params["reducedMotion"]).put("chinese", params["chinese"])
        val asset = loader.getLookupKeyForAsset("assets/dialogues/post_lesson_comedy.html")
        val textZoom = (params["textZoom"] as? Number)?.toInt()?.coerceIn(80, 250) ?: 100
        val startPaused = params["startPaused"] as? Boolean ?: false
        return ComedyView(context, viewId, messenger, "file:///android_asset/$asset", config, textZoom, startPaused)
    }
}

@Suppress("SetJavaScriptEnabled", "DEPRECATION")
private class ComedyView(
    context: Context, id: Int, messenger: BinaryMessenger,
    private val assetUrl: String, private val config: JSONObject, textZoom: Int, startPaused: Boolean
) : PlatformView {
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "globalvillage/comedy/$id")
    private var destroyed = false
    private var initialized = false
    private var hidden = false
    private var pausedUntilPlay = startPaused
    private val webView = object : WebView(context) {
        override fun onWindowVisibilityChanged(visibility: Int) {
            super.onWindowVisibilityChanged(visibility)
            hidden = visibility != View.VISIBLE
            if (hidden) pausePlayback() else if (!destroyed) onResume()
        }
    }

    init {
        webView.setBackgroundColor(Color.TRANSPARENT)
        with(webView.settings) {
            javaScriptEnabled = true
            domStorageEnabled = false
            allowContentAccess = false
            allowFileAccess = true // Android asset URLs only; every other request is rejected below.
            allowFileAccessFromFileURLs = false
            allowUniversalAccessFromFileURLs = false
            blockNetworkLoads = true
            blockNetworkImage = true
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            mediaPlaybackRequiresUserGesture = false
            this.textZoom = textZoom
        }
        webView.addJavascriptInterface(object {
            @JavascriptInterface
            fun notify(status: String) {
                if (status !in setOf("ready", "completed", "error")) return
                main.post {
                    if (!destroyed && initialized) channel.invokeMethod("event", status)
                }
            }
        }, "ComedyBridge")
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
                request.url.toString() != assetUrl

            override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean = url != assetUrl

            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                if (request.url.toString() == assetUrl) return null
                if (request.url.toString().startsWith("data:audio/mpeg;base64,")) return null
                return WebResourceResponse("text/plain", "utf-8", 403, "Blocked", emptyMap(),
                    ByteArrayInputStream(ByteArray(0)))
            }

            override fun onPageFinished(view: WebView, url: String) {
                if (destroyed || url != assetUrl || initialized) return
                view.evaluateJavascript("window.ComedyPlayer.configure($config)") { result ->
                    if (destroyed) return@evaluateJavascript
                    if (result != "true") {
                        channel.invokeMethod("event", "error")
                        return@evaluateJavascript
                    }
                    initialized = true
                    if (!hidden && !pausedUntilPlay) view.evaluateJavascript("window.ComedyPlayer.play()", null)
                    channel.invokeMethod("event", "ready")
                }
            }

            override fun onReceivedError(view: WebView, request: WebResourceRequest,
                error: android.webkit.WebResourceError) {
                if (request.isForMainFrame && !destroyed) channel.invokeMethod("event", "error")
            }
        }
        channel.setMethodCallHandler { call, result ->
            if (destroyed) { result.success(null); return@setMethodCallHandler }
            when (call.method) {
                "play", "replay" -> {
                    if (!hidden) {
                        pausedUntilPlay = false
                        webView.onResume()
                        if (initialized) webView.evaluateJavascript("window.ComedyPlayer.${call.method}()", null)
                    }
                    result.success(null)
                }
                "pause", "stop" -> { pausePlayback(); result.success(null) }
                else -> result.notImplemented()
            }
        }
        webView.loadUrl(assetUrl)
    }

    private fun pausePlayback() {
        if (destroyed) return
        pausedUntilPlay = true
        if (!initialized) return
        webView.evaluateJavascript("window.ComedyPlayer && window.ComedyPlayer.pause()", null)
        webView.onPause()
    }

    override fun getView(): View = webView

    override fun dispose() {
        if (destroyed) return
        pausePlayback()
        destroyed = true
        channel.setMethodCallHandler(null)
        main.removeCallbacksAndMessages(null)
        webView.stopLoading()
        webView.removeJavascriptInterface("ComedyBridge")
        webView.clearHistory()
        webView.removeAllViews()
        webView.destroy()
    }
}
