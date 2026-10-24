package com.amitbarel.pill_tracker

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Handler
import android.os.Looper
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pill_tracker/hebrew_ocr")
            .setMethodCallHandler { call, result ->
                if (call.method != "read") return@setMethodCallHandler result.notImplemented()
                val image = call.argument<String>("imagePath")!!
                val data = call.argument<String>("dataPath")!!
                worker.execute {
                    try {
                        val lines = readHebrew(image, data)
                        main.post { result.success(lines) }
                    } catch (e: Throwable) {
                        main.post { result.error("ocr", e.message, null) }
                    }
                }
            }
    }

    /**
     * Lines of Hebrew text with their print height and confidence (0 to 1).
     *
     * Tesseract copes with sideways text but not upside-down text, so the photo
     * is read both ways up and the reading with more confident text wins.
     */
    private fun readHebrew(imagePath: String, dataPath: String): List<Map<String, Any>> {
        val upright = uprightBitmap(imagePath)
        val flipped = rotated(upright, 180f)
        val api = TessBaseAPI()
        try {
            if (!api.init(dataPath, "heb")) throw IllegalStateException("Hebrew model missing")
            api.pageSegMode = TessBaseAPI.PageSegMode.PSM_AUTO
            return listOf(upright, flipped)
                .map { readLines(api, it) }
                .maxBy { lines -> lines.sumOf { score(it) } }
        } finally {
            api.recycle()
            upright.recycle()
            flipped.recycle()
        }
    }

    /** Confident characters read; misread text scores near zero. */
    private fun score(line: Map<String, Any>): Double {
        val confidence = line["confidence"] as Double
        return if (confidence < 0.6) 0.0 else (line["text"] as String).length * confidence
    }

    private fun readLines(api: TessBaseAPI, bitmap: Bitmap): List<Map<String, Any>> {
        api.setImage(bitmap)
        api.getUTF8Text() // runs recognition
        val lines = mutableListOf<Map<String, Any>>()
        val it = api.resultIterator ?: return lines
        val level = TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE
        it.begin()
        do {
            val text = it.getUTF8Text(level)?.trim().orEmpty()
            if (text.isEmpty()) continue
            val box = it.getBoundingRect(level)
            lines += mapOf(
                "text" to text,
                "height" to minOf(box.width(), box.height()).toDouble(),
                "confidence" to it.confidence(level) / 100.0,
            )
        } while (it.next(level))
        it.delete()
        return lines
    }

    /** The camera stores rotation in EXIF; Tesseract needs the pixels upright. */
    private fun uprightBitmap(path: String): Bitmap {
        val bitmap = BitmapFactory.decodeFile(path) ?: throw IllegalArgumentException("Not an image")
        val degrees = when (ExifInterface(path).getAttributeInt(
            ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        if (degrees == 0f) return bitmap
        return rotated(bitmap, degrees).also { bitmap.recycle() }
    }

    private fun rotated(bitmap: Bitmap, degrees: Float): Bitmap {
        val m = Matrix().apply { postRotate(degrees) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, m, true)
    }
}
