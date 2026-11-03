package com.clatzao.universal

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity é exigida pelo pedido de digital do cofre de senhas.
class MainActivity : FlutterFragmentActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private var pendingShortcut: String? = null
    private var channel: MethodChannel? = null

    private companion object {
        const val REQUEST_SAVE = 4101
        const val REQUEST_OPEN = 4102
        const val EXTRA_SHORTCUT = "shortcut"
    }

    // Reabrir pela lista de recentes entrega o intent antigo: não pode repetir o atalho.
    private fun shortcutIn(intent: Intent?): String? {
        if (intent == null || intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        return intent.getStringExtra(EXTRA_SHORTCUT)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val shortcut = shortcutIn(intent) ?: return
        intent.removeExtra(EXTRA_SHORTCUT)
        channel?.invokeMethod("shortcut", shortcut)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingShortcut = shortcutIn(intent)
        intent?.removeExtra(EXTRA_SHORTCUT)
        val systemChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "universal/system")
        channel = systemChannel
        systemChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeShortcut" -> {
                    result.success(pendingShortcut)
                    pendingShortcut = null
                }
                "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                "openFullScreenSettings" -> {
                    openFullScreenSettings()
                    result.success(null)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                "openBatterySettings" -> {
                    startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                    result.success(null)
                }
                "setSecure" -> {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                "saveFile" -> {
                    pendingResult = result
                    pendingBytes = call.argument<ByteArray>("bytes")
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = call.argument<String>("type") ?: "application/octet-stream"
                        putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                    }
                    startActivityForResult(intent, REQUEST_SAVE)
                }
                "openFile" -> {
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = call.argument<String>("type") ?: "*/*"
                    }
                    startActivityForResult(intent, REQUEST_OPEN)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("A API nova exige registrar o pedido antes de a tela iniciar")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_SAVE && requestCode != REQUEST_OPEN) return
        val result = pendingResult ?: return
        val bytes = pendingBytes
        pendingResult = null
        pendingBytes = null
        val uri = data?.data
        val saving = requestCode == REQUEST_SAVE
        if (resultCode != RESULT_OK || uri == null) {
            result.success(if (saving) false else null)
            return
        }
        try {
            if (saving) {
                contentResolver.openOutputStream(uri, "wt")!!.use { it.write(bytes!!) }
                result.success(true)
            } else {
                result.success(contentResolver.openInputStream(uri)!!.use { it.readBytes() })
            }
        } catch (e: Exception) {
            result.error("file", e.message, null)
        }
    }

    // Do Android 14 em diante o sistema pode negar o alarme em tela cheia a apps instalados fora da loja.
    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        return (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).canUseFullScreenIntent()
    }

    private fun openFullScreenSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName")))
    }
}
