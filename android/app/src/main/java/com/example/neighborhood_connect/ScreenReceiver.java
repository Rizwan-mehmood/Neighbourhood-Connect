package com.example.neighborhood_connect;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import java.util.LinkedList;
import java.util.Queue;

public class ScreenReceiver extends BroadcastReceiver {
    private static final String TAG = "ScreenReceiver";

    private static final String CHANNEL_ID = "screen_monitor_channel";
    private static final int EVENT_THRESHOLD = 5;  // Exact number of events required
    private static final long TIME_WINDOW_MS = 3000;  // Time window in milliseconds
    private final Queue<Long> eventTimestamps = new LinkedList<>();  // Circular buffer


    @Override
    public void onReceive(Context context, Intent intent) {
        boolean isEnabled = ScreenMonitorService.isSOSMonitoringEnabled(context);
        if (!isEnabled) return;

        if (Intent.ACTION_SCREEN_ON.equals(intent.getAction()) || Intent.ACTION_SCREEN_OFF.equals(intent.getAction())) {
            long currentTime = System.currentTimeMillis();

            // Remove outdated events
            while (!eventTimestamps.isEmpty() && currentTime - eventTimestamps.peek() > TIME_WINDOW_MS) {
                eventTimestamps.poll();
            }

            // Add the current event timestamp
            eventTimestamps.offer(currentTime);

            // Debugging log
            Log.d(TAG, "Event timestamp added: " + currentTime);
            Log.d(TAG, "Queue size: " + eventTimestamps.size());

            if (eventTimestamps.size() == EVENT_THRESHOLD) {
                eventTimestamps.clear();

                Intent sosIntent = new Intent(context, ScreenMonitorService.class);
                sosIntent.setAction("ACTION_TRIGGER_SOS");
                context.startService(sosIntent);
            }
        }
    }
}