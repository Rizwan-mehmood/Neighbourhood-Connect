import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('notification')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();

      if (notificationsSnapshot.docs.isEmpty) {
        setState(() {
          notifications = [];
          isLoading = false;
        });
        return;
      }

      final fetchedNotifications = notificationsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'message': data['message'] ?? '',
          'isRead': data['isRead'] ?? false,
          'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
        };
      }).toList();

      setState(() {
        notifications = fetchedNotifications;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching notifications: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          notifications = notifications.map((notification) {
            if (notification['id'] == notificationId) {
              notification['isRead'] = true;
            }
            return notification;
          }).toList();
        });

        await FirebaseFirestore.instance
            .collection('notification')
            .doc(user.uid)
            .collection('notifications')
            .doc(notificationId)
            .update({'isRead': true});
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          notifications.removeWhere(
              (notification) => notification['id'] == notificationId);
        });

        await FirebaseFirestore.instance
            .collection('notification')
            .doc(user.uid)
            .collection('notifications')
            .doc(notificationId)
            .delete();
      }
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          notifications = notifications.map((notification) {
            notification['isRead'] = true;
            return notification;
          }).toList();
        });

        final batch = FirebaseFirestore.instance.batch();
        final notificationsSnapshot = await FirebaseFirestore.instance
            .collection('notification')
            .doc(user.uid)
            .collection('notifications')
            .get();

        for (var doc in notificationsSnapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteAllNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          notifications.clear();
        });

        final batch = FirebaseFirestore.instance.batch();
        final notificationsSnapshot = await FirebaseFirestore.instance
            .collection('notification')
            .doc(user.uid)
            .collection('notifications')
            .get();

        for (var doc in notificationsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Mark All as Read') {
                markAllAsRead();
              } else if (value == 'Delete All') {
                deleteAllNotifications();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 'Mark All as Read', child: Text('Mark All as Read')),
              PopupMenuItem(value: 'Delete All', child: Text('Delete All')),
            ],
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? RefreshIndicator(
                  onRefresh: fetchNotifications, // Trigger refresh
                  child: ListView(
                    physics: AlwaysScrollableScrollPhysics(),
                    // Allow scroll even when list is empty
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        // Vertically center the content
                        crossAxisAlignment: CrossAxisAlignment.center,
                        // Horizontally center the content
                        children: [
                          Text(
                            'No Notifications',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchNotifications, // Trigger refresh
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final isRead = notification['isRead'];
                      final timestamp = notification['timestamp'];
                      final timeAgo = formatTimeAgo(timestamp);

                      return Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 5,
                            ),
                            leading: CircleAvatar(
                              backgroundColor:
                                  isRead ? Colors.grey[300] : Colors.blue,
                              child: Icon(
                                isRead
                                    ? Icons.notifications_none
                                    : Icons.notifications,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              notification['title'],
                              style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification['message'],
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  timeAgo,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.done, color: Colors.green),
                                  onPressed: () =>
                                      markAsRead(notification['id']),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () =>
                                      deleteNotification(notification['id']),
                                ),
                              ],
                            ),
                          ),
                          // Divider after each notification, except for the last one
                          if (index != notifications.length - 1)
                            Divider(color: Colors.grey[300], height: 1),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  String formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
