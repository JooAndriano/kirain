package id.jivottama.kirain

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kirain/vibration")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "vibrate" -> {
                        vibrate((call.argument<Int>("ms") ?: 400).toLong())
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Getar dengan kekuatan maksimum selama [ms] milidetik. */
    private fun vibrate(ms: Long) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager)
                .defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (!vibrator.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(ms, 255))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(ms)
        }
    }
}
