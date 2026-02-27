package com.example.prf_plugin

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/**
 * Android native plugin for WebAuthn PRF derivation.
 *
 * Uses Chrome Custom Tabs to open the WebAuthn PRF page hosted on
 * GitHub Pages. The page performs the WebAuthn ceremony and redirects
 * back via a custom URL scheme (prfpoc://) with results.
 *
 * IMPORTANT: The example app's AndroidManifest.xml must declare:
 * - android:launchMode="singleTop" on the main Activity
 * - An intent-filter for the prfpoc:// scheme
 * - A <queries> block for Custom Tabs service discovery
 *
 * SUPPORTED: Android 14+ (API 34+) with Chrome 130+ and Google
 * Password Manager fully supports PRF. All passkeys stored in
 * Google Password Manager have PRF support by default.
 * Firefox on Android does NOT support PRF.
 */
class PrfPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
                   PluginRegistry.NewIntentListener {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingResult: Result? = null

    // --- FlutterPlugin ---

    override fun onAttachedToEngine(
        binding: FlutterPlugin.FlutterPluginBinding
    ) {
        channel = MethodChannel(
            binding.binaryMessenger,
            "com.example.prf_plugin/channel"
        )
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(
        binding: FlutterPlugin.FlutterPluginBinding
    ) {
        channel.setMethodCallHandler(null)
    }

    // --- MethodCallHandler ---

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "launchWebAuth" -> {
                val url = call.argument<String>("url")
                val callbackScheme = call.argument<String>("callbackScheme")
                if (url == null || callbackScheme == null) {
                    result.error(
                        "INVALID_ARGS",
                        "Missing url or callbackScheme",
                        null
                    )
                    return
                }
                launchWebAuth(url, callbackScheme, result)
            }
            "isPrfSupported" -> {
                // PRF is supported on Android 14+ (API 34+) with Chrome 130+
                // and Google Password Manager. All passkeys stored in Google
                // Password Manager have PRF support by default.
                // Firefox on Android does NOT support PRF.
                result.success(android.os.Build.VERSION.SDK_INT >= 34)
            }
            else -> result.notImplemented()
        }
    }

    private fun launchWebAuth(
        url: String,
        callbackScheme: String,
        result: Result
    ) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                "NO_ACTIVITY",
                "Plugin not attached to an activity",
                null
            )
            return
        }

        pendingResult = result

        val customTabsIntent = CustomTabsIntent.Builder()
            .setShowTitle(true)
            .build()

        customTabsIntent.launchUrl(currentActivity, Uri.parse(url))
    }

    // --- ActivityAware ---

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(
        binding: ActivityPluginBinding
    ) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // --- NewIntentListener ---

    override fun onNewIntent(intent: Intent): Boolean {
        val data = intent.data ?: return false

        // Only handle our callback scheme
        if (data.scheme != "prfpoc") return false

        val params = mutableMapOf<String, String>()
        data.queryParameterNames.forEach { name ->
            data.getQueryParameter(name)?.let { value ->
                params[name] = value
            }
        }

        pendingResult?.success(params)
        pendingResult = null
        return true
    }
}
