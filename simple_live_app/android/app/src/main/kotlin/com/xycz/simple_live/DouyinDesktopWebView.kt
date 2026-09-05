package com.xycz.simple_live

import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebView
import androidx.webkit.UserAgentMetadata
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Applies Via's desktop client hints to the requested login WebView only. */
class DouyinDesktopWebView(private val findPlatformView: (Int) -> View?) :
    MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "readCookies") {
            try {
                result.success(readCookies())
            } catch (error: Exception) {
                result.error("COOKIE_READ_FAILED", error.message, null)
            }
            return
        }
        if (call.method != "configure") {
            result.notImplemented()
            return
        }
        val viewId = call.argument<Int>("viewId")
        val webView = viewId?.let { findWebView(findPlatformView(it)) }
        if (webView == null) {
            result.error("WEBVIEW_NOT_FOUND", "Login WebView is unavailable", null)
            return
        }
        try {
            if (WebViewFeature.isFeatureSupported(WebViewFeature.USER_AGENT_METADATA)) {
                val settings = webView.settings
                val original = WebSettingsCompat.getUserAgentMetadata(settings)
                // Preserve engine versions and other fields, as Via does.
                // The UA string alone does not override these on newer WebViews.
                val desktop = UserAgentMetadata.Builder(original)
                    .setPlatform("Windows")
                    .setMobile(false)
                    .setBrandVersionList(original.brandVersionList.filterNot {
                        it.brand.contains("Android")
                    })
                    .build()
                WebSettingsCompat.setUserAgentMetadata(settings, desktop)
            }
            result.success(null)
        } catch (error: Exception) {
            result.error("DESKTOP_MODE_FAILED", error.message, null)
        }
    }

    private fun findWebView(view: View?): WebView? {
        if (view is WebView) return view
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                findWebView(view.getChildAt(index))?.let { return it }
            }
        }
        return null
    }

    private fun readCookies(): String {
        val manager = CookieManager.getInstance()
        manager.flush()
        val values = linkedMapOf<String, String>()
        listOf(
            "https://www.douyin.com/",
            "https://live.douyin.com/",
            "https://douyin.com/",
        ).forEach { url ->
            manager.getCookie(url)
                ?.split(';')
                ?.forEach { item ->
                    val separator = item.indexOf('=')
                    if (separator > 0) {
                        val name = item.substring(0, separator).trim()
                        val value = item.substring(separator + 1).trim()
                        if (name.isNotEmpty() && value.isNotEmpty()) {
                            values.putIfAbsent(name, value)
                        }
                    }
                }
        }
        return values.entries.joinToString("; ") { "${it.key}=${it.value}" }
    }
}
