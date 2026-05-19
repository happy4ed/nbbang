package com.example.receipt_splitter

import android.util.Log
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout

class GeminiNanoPlugin(flutterEngine: FlutterEngine) {

    private val client by lazy { Generation.getClient() }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    init {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkStatus" -> scope.launch {
                        try {
                            val status = client.checkStatus()
                            withContext(Dispatchers.Main) { result.success(status) }
                        } catch (e: Exception) {
                            Log.e(TAG, "checkStatus failed", e)
                            withContext(Dispatchers.Main) {
                                result.error("CHECK_STATUS_ERROR", e.message, null)
                            }
                        }
                    }
                    "prepareIfNeeded" -> scope.launch {
                        try {
                            if (client.checkStatus() == FeatureStatus.DOWNLOADABLE) {
                                client.download().collect { }
                            }
                            withContext(Dispatchers.Main) { result.success(null) }
                        } catch (e: Exception) {
                            Log.e(TAG, "prepareIfNeeded failed", e)
                            withContext(Dispatchers.Main) {
                                result.error("PREPARE_ERROR", e.message, null)
                            }
                        }
                    }
                    "generateText" -> {
                        val prompt = call.argument<String>("prompt")
                        if (prompt == null) {
                            result.error("INVALID_ARGUMENT", "prompt is required", null)
                            return@setMethodCallHandler
                        }
                        scope.launch {
                            try {
                                val sb = StringBuilder()
                                withTimeout(30_000L) {
                                    client.generateContentStream(prompt).collect { response ->
                                        response.candidates.firstOrNull()?.text?.let { text ->
                                            if (text.isNotEmpty()) sb.append(text)
                                        }
                                    }
                                }
                                withContext(Dispatchers.Main) { result.success(sb.toString()) }
                            } catch (e: Exception) {
                                Log.e(TAG, "generateText failed", e)
                                withContext(Dispatchers.Main) {
                                    result.error("GENERATE_ERROR", e.message, null)
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val CHANNEL = "com.happy4ed.nbbang/gemini_nano"
        private const val TAG = "GeminiNanoPlugin"
    }
}
