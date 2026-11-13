package com.folio.pdfreader

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
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
    private var isResolvingIntent = false
    private var pendingGetInitialFilesResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFiles" -> {
                    isDartReady = true
                    if (isResolvingIntent) {
                        // Cold start: file is actively being copied in background thread.
                        // Hold the result until copying is finished instead of returning empty list!
                        pendingGetInitialFilesResult = result

                        // Safety fallback: if stream takes longer than 6 seconds, resolve with whatever we have
                        mainHandler.postDelayed({
                            pendingGetInitialFilesResult?.let { pending ->
                                isResolvingIntent = false
                                val files = ArrayList(pendingFilePaths)
                                pendingFilePaths.clear()
                                pending.success(files)
                                pendingGetInitialFilesResult = null
                            }
                        }, 6000)
                    } else {
                        val files = ArrayList(pendingFilePaths)
                        pendingFilePaths.clear()
                        result.success(files)
                    }
                }
                "shareFile" -> {
                    val filePath = call.argument<String>("path")
                    val title = call.argument<String>("title") ?: "PDF Paylaş"
                    if (filePath != null) {
                        sharePdfFile(filePath, title, result)
                    } else {
                        result.error("INVALID_ARGS", "File path is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Handle the intent that launched this activity
        handleIntent(intent)
    }

    private fun sharePdfFile(filePath: String, title: String, result: MethodChannel.Result) {
        try {
            val sourceFile = File(filePath)
            if (!sourceFile.exists()) {
                result.error("FILE_NOT_FOUND", "Dosya bulunamadı: $filePath", null)
                return
            }

            // Copy to cache/shared_pdfs to ensure FileProvider can always serve it safely
            val shareDir = File(cacheDir, "shared_pdfs")
            if (!shareDir.exists()) {
                shareDir.mkdirs()
            }
            val targetFile = File(shareDir, sourceFile.name)
            if (sourceFile.absolutePath != targetFile.absolutePath) {
                sourceFile.copyTo(targetFile, overwrite = true)
            }

            val uri = androidx.core.content.FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                targetFile
            )

            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, sourceFile.name)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            val chooser = Intent.createChooser(shareIntent, title)
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(chooser)
            result.success(true)
        } catch (e: Exception) {
            e.printStackTrace()
            result.error("SHARE_ERROR", e.localizedMessage, null)
        }
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
        isResolvingIntent = true
        Thread {
            try {
                val filePath = resolveOrCopyUri(uri)
                mainHandler.post {
                    isResolvingIntent = false
                    val pendingResult = pendingGetInitialFilesResult
                    if (pendingResult != null) {
                        // Dart called getInitialFiles during cold start: resolve it directly!
                        pendingGetInitialFilesResult = null
                        if (filePath != null) {
                            pendingResult.success(listOf(filePath))
                        } else {
                            pendingResult.success(emptyList<String>())
                        }
                    } else {
                        // Dart already initialized earlier or app was in background
                        if (filePath != null) {
                            val channel = methodChannel
                            if (isDartReady && channel != null) {
                                channel.invokeMethod("onOpenFiles", listOf(filePath))
                            } else {
                                pendingFilePaths.add(filePath)
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
                mainHandler.post {
                    isResolvingIntent = false
                    pendingGetInitialFilesResult?.let {
                        it.success(emptyList<String>())
                        pendingGetInitialFilesResult = null
                    }
                }
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
                output.flush()
                try {
                    output.fd.sync()
                } catch (_: Exception) {}
            }
        }

        return if (targetFile.exists() && targetFile.length() > 0) {
            targetFile.absolutePath
        } else {
            null
        }
    }
}
