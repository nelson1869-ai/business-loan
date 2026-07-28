package com.nelson.lending

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val securityChannel = "com.nelson.lending/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            securityChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecureWindow" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                "isPotentiallyRooted" -> result.success(isPotentiallyRooted())
                else -> result.notImplemented()
            }
        }
    }

    private fun isPotentiallyRooted(): Boolean {
        val suspiciousPaths = listOf(
            "/system/app/Superuser.apk",
            "/system/xbin/su",
            "/system/bin/su",
            "/sbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
        )
        val testKeys = Build.TAGS?.contains("test-keys") == true
        return testKeys || suspiciousPaths.any { File(it).exists() }
    }
}
