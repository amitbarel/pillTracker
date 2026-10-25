package com.amitbarel.pill_tracker

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.AudioAttributes
import android.media.ExifInterface
import android.media.Ringtone
import android.media.RingtoneManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
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
    private var playing: Ringtone? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockFor(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        showOverLockFor(intent)
    }

    override fun onStop() {
        super.onStop()
        // Leaving the app, or the screen turning off: next time it opens it
        // waits behind the lock like any other app.
        showOverLock(false)
    }

    /**
     * Only a ringing reminder shows over the lock screen, like an alarm clock.
     * The notifications plugin opens the app with this action for that.
     */
    private fun showOverLockFor(intent: Intent?) {
        if (intent?.action == "SELECT_NOTIFICATION") showOverLock(true)
    }

    private fun showOverLock(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pill_tracker/sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> try {
                        play(call.argument<String>("uri"))
                        result.success(null)
                    } catch (e: Throwable) {
                        result.error("sound", e.message, null)
                    }
                    "list" -> worker.execute {
                        try {
                            val sounds = phoneSounds()
                            main.post { result.success(sounds) }
                        } catch (e: Throwable) {
                            main.post { result.error("sound", e.message, null) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pill_tracker/screen")
            .setMethodCallHandler { call, result ->
                if (call.method != "alarmClosed") return@setMethodCallHandler result.notImplemented()
                showOverLock(false)
                result.success(null)
            }
    }

    /** The phone's alarm, notification and ringtone sounds, in that order. */
    private fun phoneSounds(): List<Map<String, String>> {
        val seen = HashSet<String>()
        val sounds = ArrayList<Map<String, String>>()
        for ((type, kind) in listOf(
            RingtoneManager.TYPE_ALARM to "alarm",
            RingtoneManager.TYPE_NOTIFICATION to "notification",
            RingtoneManager.TYPE_RINGTONE to "ringtone",
        )) {
            val manager = RingtoneManager(this)
            manager.setType(type)
            val cursor = manager.cursor
            while (cursor.moveToNext()) {
                val uri = manager.getRingtoneUri(cursor.position).toString()
                val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX) ?: continue
                if (seen.add(uri)) sounds.add(mapOf("uri" to uri, "title" to title, "kind" to kind))
            }
        }
        return sounds
    }

    /**
     * Plays a reminder sound for a few seconds, as an alarm would, or the
     * phone's notification sound when no sound is given.
     */
    private fun play(uri: String?) {
        playing?.stop()
        val sound = if (uri != null) Uri.parse(uri)
            else RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val ringtone = RingtoneManager.getRingtone(this, sound) ?: return
        ringtone.audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        ringtone.play()
        playing = ringtone
        // Phone sounds can be long songs; a few seconds is enough to recognise one.
        main.postDelayed({ if (playing === ringtone) ringtone.stop() }, 5000)
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
