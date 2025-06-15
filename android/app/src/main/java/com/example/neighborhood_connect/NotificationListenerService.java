package com.example.neighborhood_connect;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.firestore.DocumentChange;
import com.google.firebase.firestore.EventListener;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.FirebaseFirestoreException;
import com.google.firebase.firestore.ListenerRegistration;
import com.google.firebase.firestore.QuerySnapshot;

public class NotificationListenerService extends Service {

    private static final String TAG = "NotificationListener";
    private static final String CHANNEL_ID = "notification_listener_channel";
    private static final int FOREGROUND_NOTIFICATION_ID = 1;

    private FirebaseFirestore firestore;
    private ListenerRegistration listenerRegistration;
    private String currentUserId;

    @Override
    public void onCreate() {
        super.onCreate();
        // Initialize Firestore and notification channel
        firestore = FirebaseFirestore.getInstance();
        createNotificationChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // 1) Immediately go foreground to satisfy Android O+ requirements
        startForeground(FOREGROUND_NOTIFICATION_ID, getForegroundNotification());

        // 2) Now check for authenticated user
        FirebaseUser user = FirebaseAuth.getInstance().getCurrentUser();
        if (user != null) {
            currentUserId = user.getUid();
        } else {
            Log.e(TAG, "No authenticated user found. Stopping service.");
            stopSelf();
            return START_NOT_STICKY;
        }

        // 3) Listen to Firestore for new notifications
        if (listenerRegistration == null) {
            listenerRegistration = firestore.collection("notifications")
                    .whereEqualTo("userId", currentUserId)
                    .whereEqualTo("read", false)
                    .addSnapshotListener(new EventListener<QuerySnapshot>() {
                        @Override
                        public void onEvent(@Nullable QuerySnapshot snapshots,
                                            @Nullable FirebaseFirestoreException e) {
                            if (e != null) {
                                Log.w(TAG, "Listen failed.", e);
                                return;
                            }
                            if (snapshots != null && !snapshots.isEmpty()) {
                                for (DocumentChange dc : snapshots.getDocumentChanges()) {
                                    if (dc.getType() == DocumentChange.Type.ADDED) {
                                        String title = dc.getDocument().getString("title");
                                        String message = dc.getDocument().getString("message");
                                        Log.d(TAG, "New notification: " + dc.getDocument().getData());
                                        triggerLocalNotification(title, message);
                                    }
                                }
                            }
                        }
                    });
        }

        return START_STICKY;
    }

    // Builds the persistent notification for the foreground service.
    private Notification getForegroundNotification() {
        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Notification Listener Active")
                .setContentText("Listening for new notifications...")
                .setSmallIcon(android.R.drawable.ic_dialog_info);
        return builder.build();
    }

    // Triggers a local notification and opens notification_screen.dart when clicked
    private void triggerLocalNotification(@Nullable String title, @Nullable String message) {
        NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

        Intent intent = new Intent(this, MainActivity.class);
        intent.putExtra("screen", "notification_screen");
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);

        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(title != null ? title : "New Notification")
                .setContentText(message != null ? message : "You have a new notification!")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent);

        notificationManager.notify((int) System.currentTimeMillis(), builder.build());
    }

    // Creates a notification channel (required for Android O and above).
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            CharSequence name = "Notification Listener Channel";
            String description = "Channel for background notification listener";
            int importance = NotificationManager.IMPORTANCE_HIGH;
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, name, importance);
            channel.setDescription(description);
            NotificationManager notificationManager = getSystemService(NotificationManager.class);
            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
            }
        }
    }

    @Override
    public void onDestroy() {
        if (listenerRegistration != null) {
            listenerRegistration.remove();
            listenerRegistration = null;
        }
        super.onDestroy();
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
