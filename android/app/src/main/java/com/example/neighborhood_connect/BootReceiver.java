package com.example.neighborhood_connect;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            // Start the service using an Intent
            Intent serviceIntent = new Intent(context, ScreenMonitorService.class);
            context.startForegroundService(serviceIntent);
        }
    }
}