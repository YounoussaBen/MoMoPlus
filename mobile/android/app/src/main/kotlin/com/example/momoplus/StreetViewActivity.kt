package com.app.momoplus

import android.os.Bundle
import android.widget.ImageButton
import android.widget.TextView
import androidx.fragment.app.FragmentActivity
import com.google.android.gms.maps.OnStreetViewPanoramaReadyCallback
import com.google.android.gms.maps.StreetViewPanorama
import com.google.android.gms.maps.StreetViewPanoramaView
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.StreetViewPanoramaCamera

class StreetViewActivity : FragmentActivity(), OnStreetViewPanoramaReadyCallback {
    private lateinit var panoramaView: StreetViewPanoramaView
    private var target: LatLng? = null
    private var initialBearing: Float = 0f

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_street_view)

        val latitude = intent.getDoubleExtra(EXTRA_LATITUDE, 0.0)
        val longitude = intent.getDoubleExtra(EXTRA_LONGITUDE, 0.0)
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
        initialBearing = intent.getFloatExtra(EXTRA_BEARING, 0f)
        target = LatLng(latitude, longitude)

        panoramaView = findViewById(R.id.street_view_panorama)
        panoramaView.onCreate(savedInstanceState)
        panoramaView.getStreetViewPanoramaAsync(this)

        findViewById<ImageButton>(R.id.street_view_close_button).setOnClickListener {
            finish()
        }
        findViewById<TextView>(R.id.street_view_title).text =
            if (title.isBlank()) "Street View" else title
        findViewById<TextView>(R.id.street_view_subtitle).text =
            "Pan, zoom, and move around the area"
    }

    override fun onStreetViewPanoramaReady(panorama: StreetViewPanorama) {
        val streetViewTarget = target ?: return

        panorama.setPosition(streetViewTarget, 50)
        panorama.isStreetNamesEnabled = true
        panorama.isUserNavigationEnabled = true
        panorama.isZoomGesturesEnabled = true
        panorama.isPanningGesturesEnabled = true
        panorama.animateTo(
            StreetViewPanoramaCamera.Builder()
                .bearing(initialBearing)
                .tilt(0f)
                .zoom(0.8f)
                .build(),
            800L,
        )
    }

    override fun onResume() {
        super.onResume()
        panoramaView.onResume()
    }

    override fun onPause() {
        panoramaView.onPause()
        super.onPause()
    }

    override fun onDestroy() {
        panoramaView.onDestroy()
        super.onDestroy()
    }

    override fun onLowMemory() {
        super.onLowMemory()
        panoramaView.onLowMemory()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        panoramaView.onSaveInstanceState(outState)
    }

    companion object {
        const val EXTRA_LATITUDE = "latitude"
        const val EXTRA_LONGITUDE = "longitude"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BEARING = "bearing"
    }
}
