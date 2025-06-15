import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:async/async.dart';
import '../models/marketplace_message.dart';
import '../models/marketplace_item.dart';

class MarketplaceChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Reference to collections
  CollectionReference get _conversationsRef =>
      _firestore.collection('marketplace_conversations');

  CollectionReference get _messagesRef =>
      _firestore.collection('marketplace_messages');

  CollectionReference get _usersRef => _firestore.collection('users');

  CollectionReference get _marketplaceRef =>
      _firestore.collection('marketplace');

  String get _currentUserId => _auth.currentUser?.uid ?? '';

  // Get all conversations for current user
  Stream<List<MarketplaceConversation>> getUserConversations() {
    Stream<List<MarketplaceConversation>> stream1 = _conversationsRef
        .where('userId1', isEqualTo: _currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MarketplaceConversation.fromFirestore(doc))
            .toList());

    Stream<List<MarketplaceConversation>> stream2 = _conversationsRef
        .where('userId2', isEqualTo: _currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MarketplaceConversation.fromFirestore(doc))
            .toList());

    return StreamZip([stream1, stream2]).map((lists) {
      List<MarketplaceConversation> allConversations = [
        ...lists[0],
        ...lists[1]
      ];
      allConversations
          .sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return allConversations;
    });
  }

  // Get or create conversation
  Future<String?> getOrCreateConversation(
      String itemId, String otherUserId) async {
    try {
      QuerySnapshot query1 = await _conversationsRef
          .where('itemId', isEqualTo: itemId)
          .where('userId1', isEqualTo: _currentUserId)
          .where('userId2', isEqualTo: otherUserId)
          .limit(1)
          .get();

      if (query1.docs.isNotEmpty) return query1.docs.first.id;

      QuerySnapshot query2 = await _conversationsRef
          .where('itemId', isEqualTo: itemId)
          .where('userId1', isEqualTo: otherUserId)
          .where('userId2', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      if (query2.docs.isNotEmpty) return query2.docs.first.id;

      DocumentSnapshot itemDoc = await _marketplaceRef.doc(itemId).get();
      final MarketplaceItem item = MarketplaceItem.fromFirestore(itemDoc);

      DocumentSnapshot currentUserDoc =
          await _usersRef.doc(_currentUserId).get();
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;

      DocumentSnapshot otherUserDoc = await _usersRef.doc(otherUserId).get();
      final otherUserData = otherUserDoc.data() as Map<String, dynamic>?;

      if (currentUserData == null || otherUserData == null) return null;

      DocumentReference convRef = _conversationsRef.doc();
      await convRef.set({
        'itemId': itemId,
        'itemTitle': item.title,
        'itemImage': item.images.isNotEmpty ? item.images.first : '',
        'userId1': _currentUserId,
        'userName1':
            '${currentUserData['firstName'] ?? ''} ${currentUserData['lastName'] ?? ''}',
        'userAvatar1': currentUserData['profilePicture'] ?? '',
        'userId2': otherUserId,
        'userName2':
            '${otherUserData['firstName'] ?? ''} ${otherUserData['lastName'] ?? ''}',
        'userAvatar2': otherUserData['profilePicture'] ?? '',
        'lastMessageTime': Timestamp.now(),
        'lastMessage': '',
        'isRead': true,
      });

      return convRef.id;
    } catch (e) {
      debugPrint('Error getting/creating conversation: $e');
      return null;
    }
  }

  // Get messages for a specific conversation
  Stream<List<MarketplaceMessage>> getMessages(String conversationId) {
    return _messagesRef
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      snapshot.docs.forEach((doc) {
        final message = MarketplaceMessage.fromFirestore(doc);
        if (message.receiverId == _currentUserId && !message.isRead) {
          _messagesRef.doc(doc.id).update({'isRead': true});
          _conversationsRef.doc(conversationId).update({'isRead': true});
        }
      });

      return snapshot.docs
          .map((doc) => MarketplaceMessage.fromFirestore(doc))
          .toList();
    });
  }

  // Send a message
  Future<bool> sendMessage({
    required String conversationId,
    required String itemId,
    required String receiverId,
    required String message,
  }) async {
    try {
      DocumentSnapshot convDoc =
          await _conversationsRef.doc(conversationId).get();
      if (!convDoc.exists) return false;

      DocumentSnapshot currentUserDoc =
          await _usersRef.doc(_currentUserId).get();
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;

      DocumentSnapshot receiverDoc = await _usersRef.doc(receiverId).get();
      final receiverData = receiverDoc.data() as Map<String, dynamic>?;

      DocumentSnapshot itemDoc = await _marketplaceRef.doc(itemId).get();
      final itemData = itemDoc.data() as Map<String, dynamic>?;

      if (currentUserData == null || receiverData == null || itemData == null)
        return false;

      DocumentReference msgRef = _messagesRef.doc();
      final newMessage = MarketplaceMessage(
        id: msgRef.id,
        itemId: itemId,
        itemTitle: itemData['title'] ?? '',
        itemImage: (itemData['images'] as List?)?.isNotEmpty == true
            ? (itemData['images'] as List).first
            : '',
        senderId: _currentUserId,
        senderName:
            '${currentUserData['firstName'] ?? ''} ${currentUserData['lastName'] ?? ''}',
        senderAvatar: currentUserData['profilePicture'] ?? '',
        receiverId: receiverId,
        receiverName:
            '${receiverData['firstName'] ?? ''} ${receiverData['lastName'] ?? ''}',
        receiverAvatar: receiverData['profilePicture'] ?? '',
        message: message,
        timestamp: DateTime.now(),
        isRead: false,
      );

      await msgRef.set({
        ...newMessage.toFirestore(),
        'conversationId': conversationId,
      });

      await _conversationsRef.doc(conversationId).update({
        'lastMessage': message,
        'lastMessageTime': Timestamp.now(),
        'isRead': false,
      });

      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  // Delete a conversation
  Future<bool> deleteConversation(String conversationId) async {
    try {
      DocumentSnapshot convDoc =
          await _conversationsRef.doc(conversationId).get();
      if (!convDoc.exists) return false;

      final convData = convDoc.data() as Map<String, dynamic>;
      if (convData['userId1'] != _currentUserId &&
          convData['userId2'] != _currentUserId) return false;

      QuerySnapshot messages = await _messagesRef
          .where('conversationId', isEqualTo: conversationId)
          .get();

      WriteBatch batch = _firestore.batch();
      for (DocumentSnapshot doc in messages.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(_conversationsRef.doc(conversationId));
      await batch.commit();

      return true;
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      return false;
    }
  }

  // Get unread count
  Stream<int> getUnreadConversationsCount() {
    Stream<int> stream1 = _conversationsRef
        .where('userId1', isEqualTo: _currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);

    Stream<int> stream2 = _conversationsRef
        .where('userId2', isEqualTo: _currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);

    return StreamZip([stream1, stream2]).map((counts) => counts[0] + counts[1]);
  }
}
