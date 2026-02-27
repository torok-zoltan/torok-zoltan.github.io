package com.example.prf_plugin

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.util.Log
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

    companion object {
        private const val TAG = "PrfPlugin"
    }

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
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

        // If there's already a pending operation, fail fast rather than
        // silently overwriting the old result (which would hang forever).
        if (pendingResult != null) {
            Log.w(TAG, "Previous pending result exists, cancelling it")
            pendingResult?.error(
                "CANCELLED",
                "Operation cancelled by a new request",
                null
            )
            pendingResult = null
        }

        pendingResult = result
        Log.d(TAG, "Launching Custom Tab: $url")

        val customTabsIntent = CustomTabsIntent.Builder()
            .setShowTitle(true)
            .build()

        customTabsIntent.launchUrl(currentActivity, Uri.parse(url))
    }

    // --- ActivityAware ---

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "onAttachedToActivity")
        activity = binding.activity
        activityBinding = binding
        binding.addOnNewIntentListener(this)

        // If the activity was killed and recreated by the system while the
        // Custom Tab was open, the callback intent ends up as the activity's
        // launch intent rather than being delivered via onNewIntent.
        handleCallbackIntent(binding.activity.intent)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "onDetachedFromActivityForConfigChanges")
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(
        binding: ActivityPluginBinding
    ) {
        Log.d(TAG, "onReattachedToActivityForConfigChanges")
        activity = binding.activity
        activityBinding = binding
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "onDetachedFromActivity")
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
        activity = null
    }

    // --- NewIntentListener ---

    override fun onNewIntent(intent: Intent): Boolean {
        Log.d(TAG, "onNewIntent: ${intent.data}")
        return handleCallbackIntent(intent)
    }

    /**
     * Parse a prfpoc:// callback intent and resolve the pending result.
     *
     * Returns true if the intent was consumed, false otherwise.
     */
    private fun handleCallbackIntent(intent: Intent?): Boolean {
        val data = intent?.data ?: return false

        // Only handle our callback scheme
        if (data.scheme != "prfpoc") return false

        Log.d(TAG, "Handling callback: $data")

        val params = mutableMapOf<String, String>()
        data.queryParameterNames.forEach { name ->
            data.getQueryParameter(name)?.let { value ->
                params[name] = value
            }
        }

        Log.d(TAG, "Callback params: $params")

        if (pendingResult != null) {
            pendingResult?.success(params)
            pendingResult = null
        } else {
            Log.w(TAG, "Callback received but no pending result. " +
                    "Activity may have been recreated.")
        }

        // Clear the intent data so we don't re-process it on config changes.
        intent?.data = null
        return true
    }
}
