package com.carecompanion.patient

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) so the `health` plugin can use
// registerForActivityResult for the Health Connect permission screen.
class MainActivity : FlutterFragmentActivity() {
    // Health Connect opens the app to show why it reads health data
    // (permission rationale / "view permission usage"). Route those launches to
    // the in-app health privacy screen.
    override fun getInitialRoute(): String? {
        return when (intent?.action) {
            "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE",
            "android.intent.action.VIEW_PERMISSION_USAGE" -> "/health-privacy"
            else -> super.getInitialRoute()
        }
    }
}
