package com.example.romagnago

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val executor = Executors.newSingleThreadExecutor()
    private var walkEngine: GraphHopperWalkEngine? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> executor.execute {
                    try {
                        val engine = GraphHopperWalkEngine(applicationContext)
                        val ok = engine.initialize()
                        if (ok) walkEngine = engine
                        runOnUiThread { result.success(ok) }
                    } catch (t: Throwable) {
                        android.util.Log.e("GraphHopperWalk", "initialize channel failed", t)
                        runOnUiThread {
                            result.success(false)
                        }
                    }
                }

                "routeFoot" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val fromLat = (args["fromLat"] as? Number)?.toDouble()
                    val fromLon = (args["fromLon"] as? Number)?.toDouble()
                    val toLat = (args["toLat"] as? Number)?.toDouble()
                    val toLon = (args["toLon"] as? Number)?.toDouble()
                    if (fromLat == null || fromLon == null || toLat == null || toLon == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        try {
                            val engine = walkEngine
                            if (engine == null || !engine.isReady) {
                                runOnUiThread { result.success(null) }
                                return@execute
                            }
                            val route = engine.routeFoot(fromLat, fromLon, toLat, toLon)
                            runOnUiThread { result.success(route) }
                        } catch (t: Throwable) {
                            android.util.Log.e("GraphHopperWalk", "routeFoot failed", t)
                            runOnUiThread { result.success(null) }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "com.example.romagnago/graphhopper_walk"
    }
}
