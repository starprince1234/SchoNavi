package com.example.scho_navi

import android.os.Bundle
import android.view.animation.DecelerateInterpolator
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        splashScreen.setOnExitAnimationListener { splashScreenView ->
            splashScreenView.animate()
                .alpha(0f)
                .setDuration(120L)
                .setInterpolator(DecelerateInterpolator())
                .withEndAction { splashScreenView.remove() }
                .start()
        }
    }
}
