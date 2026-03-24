package com.app.momoplus

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openStreetView" -> openStreetView(call, result)
                    "openDirections" -> openDirections(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun openStreetView(call: MethodCall, result: MethodChannel.Result) {
        val latitude = call.argument<Double>("latitude")
        val longitude = call.argument<Double>("longitude")
        val title = call.argument<String>("title").orEmpty()
        val bearing = call.argument<Double>("bearing") ?: 0.0

        if (latitude == null || longitude == null) {
            result.error("invalid_args", "Latitude and longitude are required.", null)
            return
        }

        startActivity(
            Intent(this, StreetViewActivity::class.java).apply {
                putExtra(StreetViewActivity.EXTRA_LATITUDE, latitude)
                putExtra(StreetViewActivity.EXTRA_LONGITUDE, longitude)
                putExtra(StreetViewActivity.EXTRA_TITLE, title)
                putExtra(StreetViewActivity.EXTRA_BEARING, bearing.toFloat())
            },
        )
        result.success(null)
    }

    private fun openDirections(call: MethodCall, result: MethodChannel.Result) {
        val latitude = call.argument<Double>("latitude")
        val longitude = call.argument<Double>("longitude")

        if (latitude == null || longitude == null) {
            result.error("invalid_args", "Latitude and longitude are required.", null)
            return
        }

        val navigationIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("google.navigation:q=$latitude,$longitude&mode=d"),
        ).apply {
            setPackage("com.google.android.apps.maps")
        }

        try {
            startActivity(navigationIntent)
            result.success(null)
            return
        } catch (_: ActivityNotFoundException) {
            // Fall through to the browser URL below.
        }

        val webIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse(
                "https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving",
            ),
        )

        try {
            startActivity(webIntent)
            result.success(null)
        } catch (_: ActivityNotFoundException) {
            result.error("maps_unavailable", "No app is available to open directions.", null)
        }
    }

    private companion object {
        const val MAP_CHANNEL = "momoplus/maps"
    }
}
