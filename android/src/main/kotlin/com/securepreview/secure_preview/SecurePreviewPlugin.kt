package com.securepreview.secure_preview

import android.app.Activity
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.provider.Settings
import android.view.Display
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class SecurePreviewPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var screenshotProtectionEnabled = true

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "secure_preview")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "setScreenshotProtection") {
            screenshotProtectionEnabled = call.arguments as? Boolean ?: true
            applyScreenshotProtection()
            result.success(true)
            return
        }
        if (call.method != "checkSecurity") {
            result.notImplemented()
            return
        }
        val emulator = (Build.FINGERPRINT.startsWith("generic") ||
            Build.FINGERPRINT.lowercase().contains("vbox") ||
            Build.MODEL.contains("Emulator", true) ||
            Build.MODEL.contains("Android SDK built for", true) ||
            Build.MANUFACTURER.contains("Genymotion", true) ||
            (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")))
        val rooted = arrayOf(
            "/system/app/Superuser.apk", "/sbin/su", "/system/bin/su",
            "/system/xbin/su", "/data/local/xbin/su", "/data/local/bin/su",
            "/system/sd/xbin/su", "/system/bin/failsafe/su", "/data/local/su"
        ).any { File(it).exists() } || Build.TAGS?.contains("test-keys") == true
        val developerOptions = try {
            Settings.Global.getInt(context.contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) == 1
        } catch (_: Exception) { false }
        val usbDebugging = try {
            Settings.Global.getInt(context.contentResolver, Settings.Global.ADB_ENABLED, 0) == 1
        } catch (_: Exception) { false }
        val externalDisplay = try {
            val manager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
            manager.displays.any { it.displayId != Display.DEFAULT_DISPLAY && it.state != Display.STATE_OFF }
        } catch (_: Exception) { false }

        // Android does not expose a reliable public API to detect all active
        // screen recordings or wireless mirroring sessions. External displays
        // are reported separately; these two signals remain false on Android.
        result.success(mapOf(
            "rooted" to rooted,
            "emulator" to emulator,
            "developerOptions" to developerOptions,
            "usbDebugging" to usbDebugging,
            "screenMirroring" to false,
            "screenRecording" to false,
            "externalDisplay" to externalDisplay
        ))
    }

    private fun applyScreenshotProtection() {
        val window = activity?.window ?: return
        if (screenshotProtectionEnabled) {
            window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        applyScreenshotProtection()
    }

    override fun onDetachedFromActivityForConfigChanges() { activity = null }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        applyScreenshotProtection()
    }

    override fun onDetachedFromActivity() { activity = null }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        activity = null
    }
}
