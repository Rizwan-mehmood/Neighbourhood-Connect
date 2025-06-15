package com.example.neighborhood_connect;

import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Bundle;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private ScreenReceiver screenReceiver;
    ScreenMonitorService screenMonitorService = new ScreenMonitorService();

    private static final String CHANNEL = "com.example.neighborhood_connect/screen_events";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Initialize the screen receiver
        screenReceiver = new ScreenReceiver();

        // Check if monitoring is enabled and start the screen monitor service if so
        boolean isScreenMonitoringEnabled = ScreenMonitorService.isSOSMonitoringEnabled(this);
        Intent screenServiceIntent = new Intent(this, ScreenMonitorService.class);
        if (isScreenMonitoringEnabled) {
            startService(screenServiceIntent);
        }

        // Start the NotificationListenerService so it runs continuously in the background.
        // For API 26+ use startForegroundService.
        Intent notificationServiceIntent = new Intent(this, NotificationListenerService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(notificationServiceIntent);
        } else {
            startService(notificationServiceIntent);
        }
    }

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        MethodChannel channel = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        );
        ScreenMonitorService.methodChannel = channel; // Initialize static channel

        channel.setMethodCallHandler((call, result) -> {
            if (call.method.equals("toggleScreenEvent")) {
                boolean enable = call.argument("enable");
                // Update SharedPreferences when toggling the screen event monitoring
                ScreenMonitorService.setSOSMonitoringStatus(this, enable);
                // Start or stop the service based on the toggle
                Intent serviceIntent = new Intent(this, ScreenMonitorService.class);
                serviceIntent.putExtra("enable", enable);
                if (enable) {
                    startService(serviceIntent);
                } else {
                    stopService(serviceIntent);
                }
                result.success(null);
            } else if (call.method.equals("isScreenEventEnabled")) {
                // Logic to check if screen event monitoring is enabled
                boolean isEnabled = ScreenMonitorService.isScreenEventEnabled();
                result.success(isEnabled);
            } else {
                result.notImplemented();
            }
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        // Register the receiver to listen for screen on/off events
        IntentFilter filter = new IntentFilter();
        filter.addAction(Intent.ACTION_SCREEN_ON);
        filter.addAction(Intent.ACTION_SCREEN_OFF);
        registerReceiver(screenReceiver, filter);
    }

    @Override
    protected void onPause() {
        super.onPause();
        // Unregister the receiver
        if (screenReceiver != null) {
            unregisterReceiver(screenReceiver);
        }
    }
}
