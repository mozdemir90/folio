package com.example.pdf_reader

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "folio/open_file"
    private var methodChannel: MethodChannel? = null
    private val pendingFilePaths = mutableListOf<String>()
    private var isDartReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFiles" -> {
                    isDartReady = true
                    val files = ArrayList(pendingFilePaths)
                    pendingFilePaths.clear()
                    result.success(files)
                }
                else -> result.notImplemented()
            }
        }

        // Handle the intent that launched this activity
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        if (action == Intent.ACTION_VIEW || action == Intent.ACTION_SEND) {
            val uri: Uri? = when (action) {
                Intent.ACTION_VIEW -> intent.data
                Intent.ACTION_SEND -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(Intent.EXTRA_STREAM)
                    }
                }
                else -> null
            }

            if (uri != null) {
                copyUriToCacheAndDispatch(uri)
            }
        }
    }

    private fun copyUriToCacheAndDispatch(uri: Uri) {
        Thread {
            try {
                val filePath = resolveOrCopyUri(uri)
                if (filePath != null) {
                    runOnUiThread {
                        val channel = methodChannel
                        if (isDartReady && channel != null) {
                            channel.invokeMethod("onOpenFiles", listOf(filePath))
                        } else {
                            pendingFilePaths.add(filePath)
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    private fun resolveOrCopyUri(uri: Uri): String? {
        val scheme = uri.scheme
        if (scheme == "file") {
            val path = uri.path
            if (path != null && File(path).exists()) {
                return path
            }
        }

        var fileName = "document_${System.currentTimeMillis()}.pdf"
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex != -1 && cursor.moveToFirst()) {
                    val name = cursor.getString(nameIndex)
                    if (!name.isNullOrBlank()) {
                        fileName = name
                    }
                }
            }
        } catch (_: Exception) {}

        if (!fileName.endsWith(".pdf", ignoreCase = true)) {
            fileName += ".pdf"
        }

        fileName = fileName.replace("[\\\\/:*?\"<>|]".toRegex(), "_")

        val targetDir = File(cacheDir, "opened_pdfs")
        if (!targetDir.exists()) {
            targetDir.mkdirs()
        }

        val targetFile = File(targetDir, fileName)

        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(targetFile).use { output ->
                input.copyTo(output)
            }
        }

        return if (targetFile.exists() && targetFile.length() > 0) {
            targetFile.absolutePath
        } else {
            null
        }
    }
}
