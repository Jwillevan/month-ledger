package com.monthledger.month_ledger

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var payload: String? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "monthledger/storage").setMethodCallHandler { call, result ->
            try {
                val prefs = getSharedPreferences("ledger", MODE_PRIVATE)
                when (call.method) {
                    "load" -> result.success(prefs.getString("data", null))
                    "save" -> {
                        val ok = prefs.edit().putString("data", call.arguments as String).commit()
                        if (ok) result.success(true) else result.error("SAVE", "Unable to save", null)
                    }
                    "export", "import" -> {
                        if (pending != null) { result.error("BUSY", "File chooser already open", null) }
                        else {
                            pending = result
                            payload = call.arguments as? String
                            val export = call.method == "export"
                            val intent = Intent(if (export) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = if (export) "application/json" else "*/*"
                                if (export) putExtra(Intent.EXTRA_TITLE, "Month-Ledger-backup.json")
                            }
                            startActivityForResult(intent, if (export) 701 else 702)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                pending = null; payload = null
                result.error("STORAGE", e.message, null)
            }
        }
    }
    @Deprecated("Legacy activity result used for Flutter file bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 701 && requestCode != 702) return
        val result = pending ?: return
        pending = null
        try {
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return }
            if (requestCode == 701) {
                contentResolver.openOutputStream(uri, "wt").use { stream ->
                    requireNotNull(stream).write(requireNotNull(payload).toByteArray(Charsets.UTF_8))
                }
                result.success(true)
            } else {
                val bytes = contentResolver.openInputStream(uri).use { input ->
                    val stream = requireNotNull(input)
                    val output = java.io.ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = stream.read(buffer)
                        if (count < 0) break
                        require(output.size() + count <= 10000000) { "Backup too large" }
                        output.write(buffer, 0, count)
                    }
                    output.toByteArray()
                }
                require(bytes.size <= 10000000) { "Backup too large" }
                result.success(bytes.toString(Charsets.UTF_8))
            }
        } catch (e: Exception) { result.error("FILE", e.message, null) }
        finally { payload = null }
    }
}
