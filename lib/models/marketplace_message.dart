import 'package:cloud_firestore/cloud_firestore.dart';

class MarketplaceMessage {
  final String id;
  final String itemId;
  final String itemTitle;
  final String itemImage;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  MarketplaceMessage({
    required this.id,
    required this.itemId,
    required this.itemTitle,
    required this.itemImage,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.receiverId,
    required this.receiverName,
    required this.receiverAvatar,
    required this.message,
    required this.timestamp,
    required this.isRead,
  });

  factory MarketplaceMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MarketplaceMessage(
      id: doc.id,
      itemId: data['itemId'] ?? '',
      itemTitle: data['itemTitle'] ?? '',
      itemImage: data['itemImage'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderAvatar: data['senderAvatar'] ?? '',
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? '',
      receiverAvatar: data['receiverAvatar'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'itemTitle': itemTitle,
      'itemImage': itemImage,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverAvatar': receiverAvatar,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }
}

class MarketplaceConversation {
  final String id;
  final String itemId;
  final String itemTitle;
  final String itemImage;
  final String userId1;
  final String userName1;
  final String userAvatar1;
  final String userId2;
  final String userName2;
  final String userAvatar2;
  final DateTime lastMessageTime;
  final String lastMessage;
  final bool isRead;

  MarketplaceConversation({
    required this.id,
    required this.itemId,
    required this.itemTitle,
    required this.itemImage,
    required this.userId1,
    required this.userName1,
    required this.userAvatar1,
    required this.userId2,
    required this.userName2,
    required this.userAvatar2,
    required this.lastMessageTime,
    required this.lastMessage,
    required this.isRead,
  });

  factory MarketplaceConversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MarketplaceConversation(
      id: doc.id,
      itemId: data['itemId'] ?? '',
      itemTitle: data['itemTitle'] ?? '',
      itemImage: data['itemImage'] ?? '',
      userId1: data['userId1'] ?? '',
      userName1: data['userName1'] ?? '',
      userAvatar1: data['userAvatar1'] ?? '',
      userId2: data['userId2'] ?? '',
      userName2: data['userName2'] ?? '',
      userAvatar2: data['userAvatar2'] ?? '',
      lastMessageTime:
          (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: data['lastMessage'] ?? '',
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'itemTitle': itemTitle,
      'itemImage': itemImage,
      'userId1': userId1,
      'userName1': userName1,
      'userAvatar1': userAvatar1,
      'userId2': userId2,
      'userName2': userName2,
      'userAvatar2': userAvatar2,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastMessage': lastMessage,
      'isRead': isRead,
    };
  }

  String getOtherUserName(String currentUserId) {
    return currentUserId == userId1 ? userName2 : userName1;
  }

  String getOtherUserAvatar(String currentUserId) {
    return currentUserId == userId1 ? userAvatar2 : userAvatar1;
  }

  String getOtherUserId(String currentUserId) {
    return currentUserId == userId1 ? userId2 : userId1;
  }
}
