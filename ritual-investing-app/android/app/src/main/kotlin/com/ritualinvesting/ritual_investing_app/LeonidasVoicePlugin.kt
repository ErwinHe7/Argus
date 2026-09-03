package com.ritualinvesting.ritual_investing_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class LeonidasVoicePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    TextToSpeech.OnInitListener {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var applicationContext: Context? = null
    private var textToSpeech: TextToSpeech? = null
    private var ready = false
    private var pendingText: String? = null
    private var pendingRate = 1.0f
    private var pendingPitch = 1.0f
    private var pendingUtteranceId: String? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "speak" -> {
                val text = call.argument<String>("text")?.trim().orEmpty()
                if (text.isEmpty()) {
                    result.success(false)
                    return
                }

                cancelPendingSpeech()
                pendingText = text
                pendingRate = call.argument<Number>("rate")?.toFloat() ?: 1.0f
                pendingPitch = call.argument<Number>("pitch")?.toFloat() ?: 1.0f
                pendingResult = result
                if (ready) {
                    startPendingSpeech()
                } else if (textToSpeech == null) {
                    val context = applicationContext
                    if (context == null) {
                        finishPendingSpeech(success = false)
                    } else {
                        textToSpeech = TextToSpeech(context, this)
                    }
                }
            }

            "stop" -> {
                cancelPendingSpeech()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    override fun onInit(status: Int) {
        ready = status == TextToSpeech.SUCCESS
        if (!ready) {
            textToSpeech?.shutdown()
            textToSpeech = null
            finishPendingSpeech(success = false)
            return
        }

        textToSpeech?.setOnUtteranceProgressListener(
            object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) = Unit

                override fun onDone(utteranceId: String?) {
                    finishUtterance(utteranceId, success = true)
                }

                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {
                    finishUtterance(utteranceId, success = false)
                }

                override fun onError(utteranceId: String?, errorCode: Int) {
                    finishUtterance(utteranceId, success = false)
                }
            },
        )
        startPendingSpeech()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        cancelPendingSpeech()
        textToSpeech?.shutdown()
        textToSpeech = null
        applicationContext = null
        ready = false
    }

    private fun startPendingSpeech() {
        val speech = textToSpeech ?: return finishPendingSpeech(success = false)
        val text = pendingText ?: return
        val utteranceId = UUID.randomUUID().toString()
        pendingUtteranceId = utteranceId
        speech.setSpeechRate(pendingRate.coerceIn(0.1f, 2.0f))
        speech.setPitch(pendingPitch.coerceIn(0.5f, 2.0f))
        val status = speech.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
        if (status == TextToSpeech.ERROR) finishPendingSpeech(success = false)
    }

    private fun cancelPendingSpeech() {
        textToSpeech?.stop()
        finishPendingSpeech(success = false)
    }

    private fun finishUtterance(utteranceId: String?, success: Boolean) {
        mainHandler.post {
            if (utteranceId == pendingUtteranceId) {
                finishPendingSpeech(success)
            }
        }
    }

    private fun finishPendingSpeech(success: Boolean) {
        val result = pendingResult ?: return
        pendingResult = null
        pendingText = null
        pendingUtteranceId = null
        mainHandler.post { result.success(success) }
    }

    private companion object {
        const val CHANNEL_NAME = "ritual_investing/leonidas_voice"
    }
}
