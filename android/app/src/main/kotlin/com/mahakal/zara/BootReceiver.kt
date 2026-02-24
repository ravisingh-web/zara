package com.mahakal.zara

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            
            Log.d("ZaraBoot", "Z.A.R.A. System Rebooted. Ready for duty, Sir.")
            
            // In the future, you can launch your background service from here
            // so Z.A.R.A. stays alive even if the app is closed.
        }
    }
}
