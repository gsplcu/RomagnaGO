package com.example.romagnago

import android.content.Context
import com.graphhopper.GHRequest
import com.graphhopper.GraphHopper
import com.graphhopper.config.CHProfile
import com.graphhopper.config.Profile
import com.graphhopper.routing.WeightingFactory
import com.graphhopper.routing.ev.VehicleAccess
import com.graphhopper.routing.ev.VehiclePriority
import com.graphhopper.routing.ev.VehicleSpeed
import com.graphhopper.routing.weighting.TurnCostProvider
import com.graphhopper.routing.weighting.custom.CustomWeighting
import com.graphhopper.util.CustomModel
import com.graphhopper.util.PMap
import com.graphhopper.util.Parameters
import com.graphhopper.util.PointList
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipInputStream

/**
 * Routing a piedi offline (profilo foot) con grafo GraphHopper pre-importato.
 * Il grafo va generato sul PC e incluso come asset `graphhopper/romagna.ghz`.
 *
 * GH 8.0 usa Janino per compilare il custom weighting a runtime, ma Janino non
 * funziona su Android (produce bytecode JVM, non DEX). Per aggirare il problema
 * costruiamo il CustomWeighting a mano, senza Janino, come consigliato in
 * https://github.com/graphhopper/graphhopper/issues/2717
 */
class GraphHopperWalkEngine(private val context: Context) {

    private var hopper: GraphHopper? = null

    val isReady: Boolean
        get() = hopper != null

    fun initialize(): Boolean {
        if (hopper != null) return true

        val graphDir = graphDirectory()
        android.util.Log.i(TAG, "graphDir=$graphDir exists=${graphDir.exists()}")
        if (!isGraphPresent(graphDir)) {
            android.util.Log.i(TAG, "Graph not present, extracting from assets...")
            if (!extractGraphFromAssets(graphDir)) {
                android.util.Log.e(TAG, "Extraction failed")
                return false
            }
        }
        if (!isGraphPresent(graphDir)) {
            android.util.Log.e(TAG, "Graph still not present after extraction")
            return false
        }

        android.util.Log.i(TAG, "Loading GraphHopper from ${graphDir.absolutePath}")
        try {
            val gh = createHopper(graphDir)
            gh.load()
            hopper = gh
            android.util.Log.i(TAG, "GraphHopper loaded successfully")
            return true
        } catch (e: Exception) {
            android.util.Log.w(TAG, "Load failed, retrying with fresh extract...", e)
            graphDir.deleteRecursively()
            if (!extractGraphFromAssets(graphDir)) return false
            if (!isGraphPresent(graphDir)) return false
            try {
                val gh = createHopper(graphDir)
                gh.load()
                hopper = gh
                android.util.Log.i(TAG, "GraphHopper loaded successfully (after re-extract)")
                return true
            } catch (e2: Exception) {
                android.util.Log.e(TAG, "GraphHopper load failed after re-extract", e2)
                return false
            }
        }
    }

    fun routeFoot(
        fromLat: Double,
        fromLon: Double,
        toLat: Double,
        toLon: Double,
    ): Map<String, Any>? {
        if (!isWithinRomagnaBounds(fromLat, fromLon) ||
            !isWithinRomagnaBounds(toLat, toLon)
        ) {
            return null
        }
        val gh = hopper ?: return null
        val rsp = gh.route(
            GHRequest(fromLat, fromLon, toLat, toLon)
                .setProfile("foot")
                .putHint(Parameters.Routing.INSTRUCTIONS, false),
        )
        if (rsp.hasErrors()) return null
        val path = rsp.best ?: return null
        val points = path.points ?: return null
        if (points.size() < 2) return null

        return mapOf(
            "distanceMeters" to path.distance,
            "timeMs" to path.time,
            "points" to pointListToMaps(points),
        )
    }

    /**
     * Build a Profile whose version hash matches the graph built with
     * `{ name: foot, vehicle: foot, custom_model_files: [] }` in YAML.
     *
     * The YAML parser creates the Profile via its private default constructor,
     * then Jackson's @JsonAnySetter adds custom_model_files to hints BEFORE
     * resolveCustomModelFiles adds the CustomModel. We replicate this exact
     * insertion order via reflection so the hash matches.
     */
    private fun createFootProfile(): Profile {
        val ctor = Profile::class.java.getDeclaredConstructor()
        ctor.isAccessible = true
        return ctor.newInstance().apply {
            setName("foot")
            setVehicle("foot")
            putHint("custom_model_files", ArrayList<String>())
            setCustomModel(CustomModel())
        }
    }

    /**
     * GH 8.0 only supports `weighting=custom`, which compiles expressions via
     * Janino at runtime. Janino emits JVM bytecode that Android's ART cannot load.
     * We subclass GraphHopper and override createWeightingFactory() to build the
     * CustomWeighting ourselves — equivalent to an empty custom model (default
     * foot speeds, priority 1.0 everywhere).
     */
    private fun createHopper(graphDir: File): GraphHopper =
        object : GraphHopper() {
            override fun createWeightingFactory(): WeightingFactory {
                val em = encodingManager
                return WeightingFactory { profile, requestHints, _ ->
                    val vehicle = profile.vehicle
                    val accessEnc = em.getBooleanEncodedValue(VehicleAccess.key(vehicle))
                    val speedEnc = em.getDecimalEncodedValue(VehicleSpeed.key(vehicle))
                    val priorityEnc =
                        if (em.hasEncodedValue(VehiclePriority.key(vehicle)))
                            em.getDecimalEncodedValue(VehiclePriority.key(vehicle))
                        else null

                    val cm = profile.customModel ?: CustomModel()
                    val distInf = cm.distanceInfluence ?: 0.0
                    val headPen = cm.headingPenalty
                        ?: Parameters.Routing.DEFAULT_HEADING_PENALTY

                    val maxSpeed = speedEnc.getMaxOrMaxStorableDecimal()
                    val maxPriority =
                        if (priorityEnc != null) priorityEnc.getMaxStorableDecimal() else 1.0

                    CustomWeighting(
                        accessEnc, speedEnc, TurnCostProvider.NO_TURN_COST_PROVIDER,
                        CustomWeighting.Parameters(
                            CustomWeighting.EdgeToDoubleMapping { edge, reverse ->
                                if (reverse) edge.getReverse(speedEnc)
                                else edge.get(speedEnc)
                            },
                            CustomWeighting.EdgeToDoubleMapping { _, _ -> 1.0 },
                            maxSpeed, maxPriority, distInf, headPen,
                        ),
                    )
                }
            }
        }.apply {
            setGraphHopperLocation(graphDir.absolutePath)
            setProfiles(createFootProfile())
            getCHPreparationHandler().setCHProfiles(CHProfile("foot"))
        }

    private fun graphDirectory(): File =
        File(File(context.filesDir, "graphhopper"), "romagna-gh")

    private fun isGraphPresent(graphDir: File): Boolean =
        File(graphDir, "properties").exists()

    private fun extractGraphFromAssets(graphDir: File): Boolean {
        return try {
            context.assets.open("flutter_assets/assets/graphhopper/romagna.ghz").use { raw ->
                graphDir.parentFile?.mkdirs()
                if (graphDir.exists()) {
                    graphDir.deleteRecursively()
                }
                graphDir.mkdirs()
                ZipInputStream(raw).use { zis ->
                    var entry = zis.nextEntry
                    while (entry != null) {
                        val out = File(graphDir, entry.name)
                        if (entry.isDirectory) {
                            out.mkdirs()
                        } else {
                            out.parentFile?.mkdirs()
                            FileOutputStream(out).use { fos ->
                                zis.copyTo(fos)
                            }
                        }
                        zis.closeEntry()
                        entry = zis.nextEntry
                    }
                }
            }
            android.util.Log.i(TAG, "Extraction completed. Files: ${graphDirectory().listFiles()?.map { it.name }}")
            true
        } catch (e: Exception) {
            android.util.Log.e(TAG, "extractGraphFromAssets failed", e)
            false
        }
    }

    private fun pointListToMaps(points: PointList): List<Map<String, Double>> {
        val out = ArrayList<Map<String, Double>>(points.size())
        for (i in 0 until points.size()) {
            out.add(
                mapOf(
                    "lat" to points.getLat(i),
                    "lng" to points.getLon(i),
                ),
            )
        }
        return out
    }

    companion object {
        private const val TAG = "GraphHopperWalk"

        fun isWithinRomagnaBounds(lat: Double, lon: Double): Boolean =
            lat in 43.62..44.48 && lon in 11.70..12.75
    }
}
