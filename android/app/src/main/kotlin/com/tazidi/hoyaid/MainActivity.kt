package com.tazidi.hoyaid

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Debug
import android.os.Process
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Collections
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    companion object {
        private const val PERFORMANCE_CHANNEL = "com.tazidi.hoyaid/performance_monitor"
    }

    private var resourceMonitor: ResourceMonitor? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERFORMANCE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceInfo" -> result.success(readDeviceInfo())
                    "start" -> {
                        val interval = call.argument<Int>("sampleIntervalMs") ?: 100
                        resourceMonitor?.stop()
                        resourceMonitor = ResourceMonitor(applicationContext, interval.coerceAtLeast(50))
                        resourceMonitor?.start()
                        result.success(null)
                    }
                    "stop" -> {
                        val monitor = resourceMonitor
                        resourceMonitor = null
                        if (monitor == null) {
                            result.error("not_running", "Monitor sumber daya belum dimulai.", null)
                        } else {
                            result.success(monitor.stop())
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        resourceMonitor?.stop()
        resourceMonitor = null
        super.onDestroy()
    }

    private fun readDeviceInfo(): Map<String, Any> {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        val chipset = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(Build.SOC_MANUFACTURER, Build.SOC_MODEL)
                .filter { it.isNotBlank() }
                .joinToString(" ")
                .ifBlank { Build.HARDWARE }
        } else {
            Build.HARDWARE
        }

        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "androidVersion" to Build.VERSION.RELEASE,
            "androidApiLevel" to Build.VERSION.SDK_INT,
            "chipset" to chipset,
            "processorCount" to Runtime.getRuntime().availableProcessors(),
            "totalRamMb" to memoryInfo.totalMem.toDouble() / BYTES_PER_MEBIBYTE,
        )
    }
}

private const val BYTES_PER_MEBIBYTE = 1024.0 * 1024.0
private const val KILOBYTES_PER_MEBIBYTE = 1024.0

/**
 * Mengambil penggunaan proses aplikasi sendiri. CPU dihitung sebagai persen
 * dari seluruh inti logis perangkat agar nilainya berada pada rentang 0–100.
 */
private class ResourceMonitor(
    private val context: Context,
    private val sampleIntervalMs: Int,
) {
    private data class Sample(
        val elapsedMs: Long,
        val cpuTimeMs: Long,
        val totalPssMb: Double,
        val nativePssMb: Double,
    )

    private val samples = Collections.synchronizedList(mutableListOf<Sample>())
    private val processorCount = Runtime.getRuntime().availableProcessors().coerceAtLeast(1)
    private var executor: ScheduledExecutorService? = null

    fun start() {
        takeSample()
        executor = Executors.newSingleThreadScheduledExecutor().also { scheduler ->
            scheduler.scheduleAtFixedRate(
                { takeSample() },
                sampleIntervalMs.toLong(),
                sampleIntervalMs.toLong(),
                TimeUnit.MILLISECONDS,
            )
        }
    }

    fun stop(): Map<String, Any> {
        executor?.shutdownNow()
        executor = null
        takeSample()

        val captured = synchronized(samples) { samples.toList() }
        val first = captured.firstOrNull()
        val last = captured.lastOrNull()
        val cpuPercents = captured.zipWithNext { previous, current ->
            val wallDelta = (current.elapsedMs - previous.elapsedMs).coerceAtLeast(1L)
            val cpuDelta = (current.cpuTimeMs - previous.cpuTimeMs).coerceAtLeast(0L)
            (cpuDelta.toDouble() / wallDelta / processorCount * 100.0)
                .coerceIn(0.0, 100.0)
        }
        val meanCpu = if (cpuPercents.isEmpty()) 0.0 else cpuPercents.average()
        val peakCpu = cpuPercents.maxOrNull() ?: 0.0
        val pssValues = captured.map { it.totalPssMb }
        val nativePssValues = captured.map { it.nativePssMb }

        return mapOf(
            "meanCpuPercent" to meanCpu,
            "peakCpuPercent" to peakCpu,
            "initialPssMb" to (first?.totalPssMb ?: 0.0),
            "peakPssMb" to (pssValues.maxOrNull() ?: 0.0),
            "finalPssMb" to (last?.totalPssMb ?: 0.0),
            "peakNativePssMb" to (nativePssValues.maxOrNull() ?: 0.0),
            "sampleCount" to captured.size,
        )
    }

    private fun takeSample() {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo: Debug.MemoryInfo = activityManager
            .getProcessMemoryInfo(intArrayOf(Process.myPid()))
            .firstOrNull() ?: return
        samples.add(
            Sample(
                elapsedMs = SystemClock.elapsedRealtime(),
                cpuTimeMs = Process.getElapsedCpuTime(),
                totalPssMb = memoryInfo.totalPss.toDouble() / KILOBYTES_PER_MEBIBYTE,
                nativePssMb = memoryInfo.nativePss.toDouble() / KILOBYTES_PER_MEBIBYTE,
            ),
        )
    }
}
