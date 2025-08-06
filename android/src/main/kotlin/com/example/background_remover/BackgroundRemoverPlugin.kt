package com.example.background_remover

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import android.app.Activity
import android.graphics.*
import android.graphics.drawable.BitmapDrawable
import androidx.core.graphics.drawable.toBitmap
import java.io.ByteArrayOutputStream

class BackgroundRemoverPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private var activity: Activity? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "background_remover")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
        "removeBackground" -> {
          val imageBytes = call.argument<ByteArray>("imageBytes")
          if (imageBytes != null) {
              removeBackground(imageBytes, result)
          } else {
              result.error("INVALID_ARGUMENT", "Image bytes are null", null)
          }
        }
        else -> result.notImplemented()
    }
  }

  private fun removeBackground(imageBytes: ByteArray, result: MethodChannel.Result) {
      try {
          val resources = activity?.resources ?: return
          val drawable = BitmapDrawable(resources, BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size))
          BackgroundRemover.bitmapForProcessing(drawable.toBitmap(), true, object : OnBackgroundChangeListener {
              override fun onSuccess(bitmap: Bitmap) {
                  val originalWidth = bitmap.width
                  val originalHeight = bitmap.height
                  val targetWidth = 256
                  val targetHeight = (originalHeight.toFloat() / originalWidth.toFloat() * targetWidth).toInt()
                  val resizedBitmap = Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, true)
                  val processedBitmapWithWhiteBackground = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
                  val canvas = Canvas(processedBitmapWithWhiteBackground)

                  canvas.drawColor(Color.WHITE)
                  val left = (targetWidth - resizedBitmap.width) / 2f
                  val top = (targetHeight - resizedBitmap.height) / 2f

                  canvas.drawBitmap(resizedBitmap, left, top, null)
                  val outputBytes = ByteArrayOutputStream()

                  processedBitmapWithWhiteBackground.compress(Bitmap.CompressFormat.PNG, 100, outputBytes)
                  val processedImageBytes = outputBytes.toByteArray()
                  result.success(processedImageBytes)
              }
              override fun onFailed(exception: Exception) {
                  result.error("PROCESSING_ERROR", "Error processing image", null)
              }
          })
      } catch (e: Exception) {
          result.error("PROCESSING_ERROR", "Error processing image", null)
      }
  }
}
