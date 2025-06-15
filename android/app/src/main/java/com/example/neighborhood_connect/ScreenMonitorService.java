package com.example.neighborhood_connect;

import android.Manifest;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.location.Location;
import android.os.Build;
import android.os.IBinder;
import android.os.Looper;
import android.telephony.SmsManager;
import android.util.Log;

import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;

import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationCallback;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationServices;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.firestore.FirebaseFirestore;

import io.flutter.plugin.common.MethodChannel;

import java.util.List;

import com.google.firebase.firestore.DocumentReference;
import java.util.HashMap;
import java.util.Date;
import com.google.firebase.Timestamp;

@SuppressWarnings({"deprecation", "unchecked"})
public class ScreenMonitorService extends Service {
    private static final String TAG = "ScreenMonitorService";
    private ScreenReceiver screenReceiver;
    private static boolean isScreenEventEnabled = false;
    public static MethodChannel methodChannel;
    private FusedLocationProviderClient fusedLocationClient;
    private LocationCallback locationCallback;
    private static final int SMS_PERMISSION_REQUEST_CODE = 1;

    @Override
    public void onCreate() {
        super.onCreate();
        startForeground();
        registerScreenReceiver();

        // Initialize fused location provider
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this);

        Log.d(TAG, "Service created and foreground notification started.");
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // Check for a specific SOS trigger action
        if (intent != null && "ACTION_TRIGGER_SOS".equals(intent.getAction())) {
            Log.d(TAG, "Handling SOS trigger");
            onScreenEvent();
            return START_STICKY;
        }

        boolean enableMonitoring = isSOSMonitoringEnabled(this);

        if (enableMonitoring) {
            isScreenEventEnabled = true;
            Log.d(TAG, "SOS monitoring enabled.");
        } else {
            isScreenEventEnabled = false;
            Log.d(TAG, "SOS monitoring disabled. Unregistering receiver and stopping service.");
            unregisterScreenReceiver();
            stopForeground(true);
            stopSelf();
        }

        return START_STICKY;
    }

    private void unregisterScreenReceiver() {
        try {
            if (screenReceiver != null) {
                unregisterReceiver(screenReceiver);
                screenReceiver = null;
                Log.d(TAG, "Screen event monitoring stopped.");
            }
        } catch (Exception e) {
            String errorMsg = "Error unregistering receiver: " + e.getMessage();
            Log.e(TAG, errorMsg);
        }
    }

    private void startForeground() {
        String channelId = "screen_monitor_service";
        String channelName = "Screen Monitor Service";
        int notificationId = 1;

        NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    channelId,
                    channelName,
                    NotificationManager.IMPORTANCE_LOW
            );
            notificationManager.createNotificationChannel(channel);
        }

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, channelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("SOS is enabled")
                .setContentText("Monitoring SOS enabled!")
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setAutoCancel(true);

        startForeground(notificationId, builder.build());
        Log.d(TAG, "Foreground notification started.");
    }

    private void registerScreenReceiver() {
        screenReceiver = new ScreenReceiver();
        IntentFilter filter = new IntentFilter();
        filter.addAction(Intent.ACTION_SCREEN_ON);
        filter.addAction(Intent.ACTION_SCREEN_OFF);
        registerReceiver(screenReceiver, filter);
        Log.d(TAG, "ScreenReceiver registered.");
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        try {
            unregisterReceiver(screenReceiver);
            // Also remove any pending location updates
            if (fusedLocationClient != null && locationCallback != null) {
                fusedLocationClient.removeLocationUpdates(locationCallback);
            }
            Log.d(TAG, "Service destroyed and receiver unregistered.");
        } catch (Exception e) {
            String errorMsg = "Error during service destruction: " + e.getMessage();
            Log.e(TAG, errorMsg);
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    public static boolean isScreenEventEnabled() {
        return isScreenEventEnabled;
    }

    public static MethodChannel getMethodChannel() {
        return methodChannel;
    }

    public static boolean isSOSMonitoringEnabled(Context context) {
        SharedPreferences preferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
        return preferences.getBoolean("flutter.isSOSEnabled", false);
    }

    public static void setSOSMonitoringStatus(Context context, boolean status) {
        SharedPreferences preferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = preferences.edit();
        editor.putBoolean("flutter.isSOSEnabled", status);
        editor.apply();
        Log.d(TAG, "SOS monitoring status set to: " + status);
    }

    /**
     * This method now initiates the SMS sending flow first and then, once done,
     * sends the SOS notification.
     */
    private void onScreenEvent() {
        Log.d(TAG, "Handling screen event for SOS");
        sendSMSAndThenNotify();
    }

    /**
     * Sends the SMS messages by retrieving the phone numbers from Firebase.
     * Once the process (or attempted process) is complete, the SOS notification is sent.
     */
    private void sendSMSAndThenNotify() {
        sendNotification("SOS Alert", "Generating SOS alert!");
        FirebaseAuth auth = FirebaseAuth.getInstance();
        FirebaseFirestore firestore = FirebaseFirestore.getInstance();

        String userId = auth.getCurrentUser() != null ? auth.getCurrentUser().getUid() : null;
        if (userId != null) {
            Log.d(TAG, "Fetching phone numbers for user ID: " + userId);

            firestore.collection("phone_numbers")
                    .document(userId)
                    .get()
                    .addOnSuccessListener(documentSnapshot -> {
                        if (documentSnapshot.exists()) {
                            List<String> phoneNumbers = (List<String>) documentSnapshot.get("numbers");
                            if (phoneNumbers != null && !phoneNumbers.isEmpty()) {
                                Log.d(TAG, "Phone numbers fetched: " + phoneNumbers);
                                getCurrentLocationAndSendSMS(phoneNumbers, (locationUrl) -> {
                                    sendNotification("SOS Alert", "SOS alert generated successfully!");
                                    saveNotificationsForUsers(userId, locationUrl);
                                });
                            } else {
                                Log.d(TAG, "No phone numbers found.");
                            }
                        } else {
                            Log.d(TAG, "No document found for user ID: " + userId);
                        }
                    })
                    .addOnFailureListener(e -> Log.e(TAG, "Error fetching phone numbers: " + e.getMessage()));
        } else {
            Log.d(TAG, "No logged-in user found.");
        }
    }

    /**
     * Requests the current location using FusedLocationProviderClient and then sends SMS to each phone number.
     * Once the SMS process is triggered (or if location permissions are missing), the provided callback is invoked.
     */
    private void getCurrentLocationAndSendSMS(List<String> phoneNumbers, LocationCallbackInterface callback) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            Intent intent = new Intent(this, MainActivity.class);
            intent.putExtra("request_permission", true);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
            Log.e(TAG, "Required permissions (Location/SMS) not granted. Cannot send SMS.");
            return;
        }

        LocationRequest locationRequest = LocationRequest.create();
        locationRequest.setPriority(LocationRequest.PRIORITY_HIGH_ACCURACY);
        locationRequest.setInterval(5000);
        locationRequest.setFastestInterval(3000);
        locationRequest.setNumUpdates(1);

        locationCallback = new LocationCallback() {
            @Override
            public void onLocationResult(LocationResult locationResult) {
                if (locationResult == null) {
                    callback.onLocationReceived(null);
                    return;
                }
                Location location = locationResult.getLastLocation();
                String locationUrl = "https://www.google.com/maps?q=" + location.getLatitude() + "," + location.getLongitude();
                Log.d(TAG, "Location received: " + locationUrl);

                for (String phoneNumber : phoneNumbers) {
                    sendSMSToNumber(phoneNumber, locationUrl);
                }
                callback.onLocationReceived(locationUrl);
            }
        };

        fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, Looper.getMainLooper());
    }

    private void sendSMSToNumber(String phoneNumber, String locationUrl) {
        try {
            SmsManager smsManager = SmsManager.getDefault();
            String message = "SOS Alert! Please help. Current location: " + locationUrl;
            smsManager.sendTextMessage(phoneNumber, null, message, null, null);
            Log.d(TAG, "Message sent to: " + phoneNumber);
        } catch (SecurityException e) {
            String errorMsg = "SMS permission not granted for " + phoneNumber + ": " + e.getMessage();
            Log.e(TAG, errorMsg);
        } catch (Exception e) {
            String errorMsg = "Failed to send SMS to " + phoneNumber + ": " + e.getMessage();
            Log.e(TAG, errorMsg);
        }
    }

    /**
     * Simple callback interface to notify when an asynchronous task is complete.
     */
    private interface Callback {
        void onComplete();
    }

    private void saveNotificationsForUsers(String currentUserId, String locationUrl) {
        FirebaseFirestore firestore = FirebaseFirestore.getInstance();

        firestore.collection("app_notify").document(currentUserId)
                .get()
                .addOnSuccessListener(documentSnapshot -> {
                    if (documentSnapshot.exists()) {
                        List<String> userIds = (List<String>) documentSnapshot.get("user_ids");
                        if (userIds != null && !userIds.isEmpty()) {
                            for (String userId : userIds) {
                                createNotificationForUser(firestore, userId, locationUrl);
                            }
                        } else {
                            Log.d(TAG, "No users found in app_notify for: " + currentUserId);
                        }
                    } else {
                        Log.d(TAG, "No app_notify document found for user: " + currentUserId);
                    }
                })
                .addOnFailureListener(e -> Log.e(TAG, "Error fetching app_notify users: " + e.getMessage()));
    }

    private void createNotificationForUser(FirebaseFirestore firestore, String userId, String locationUrl) {
        DocumentReference notificationRef = firestore.collection("notifications").document();

        HashMap<String, Object> notificationData = new HashMap<>();
        notificationData.put("read", false);
        notificationData.put("message", "SOS Alert! Please help. Current location: " + locationUrl);
        notificationData.put("timestamp", new Timestamp(new Date()));
        notificationData.put("title", "SOS Alert!");
        notificationData.put("userId", userId);

        notificationRef.set(notificationData)
                .addOnSuccessListener(aVoid -> Log.d(TAG, "Notification saved for user: " + userId))
                .addOnFailureListener(e -> Log.e(TAG, "Error saving notification: " + e.getMessage()));
    }

    private interface LocationCallbackInterface {
        void onLocationReceived(String locationUrl);
    }

    /**
     * Helper method to send a notification with a given title and message.
     */
    private void sendNotification(String title, String message) {
        int notificationId = (int) System.currentTimeMillis();
        NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        String channelId = "sos_alerts";
        String channelName = "SOS Alerts";

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH);
            notificationManager.createNotificationChannel(channel);
        }

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, channelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(message)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true);

        notificationManager.notify(notificationId, builder.build());
    }
}
