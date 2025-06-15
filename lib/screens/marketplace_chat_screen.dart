import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/firebase_mock.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

// import 'package:dreamflow/theme.dart';
import '../models/marketplace_message.dart';
import '../services/marketplace_chat_service.dart';
import 'item_detail_screen.dart';

class MarketplaceChatScreen extends StatefulWidget {
  final String? conversationId;

  const MarketplaceChatScreen({super.key, this.conversationId});

  @override
  State<MarketplaceChatScreen> createState() => _MarketplaceChatScreenState();
}

class _MarketplaceChatScreenState extends State<MarketplaceChatScreen> {
  final MarketplaceChatService _chatService = MarketplaceChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _selectedConversationId;
  MarketplaceConversation? _currentConversation;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _selectedConversationId = widget.conversationId;
    if (_selectedConversationId != null) {
      _loadConversation(_selectedConversationId!);
    }
  }


  Future<void> _loadConversation(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('marketplace_conversations')
          .doc(id)
          .get();
      setState(() {
        _currentConversation = MarketplaceConversation.fromFirestore(doc);
      });
    } catch (e) {
      debugPrint('Failed to load conversation $id: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectConversation(MarketplaceConversation conversation) {
    setState(() {
      _selectedConversationId = conversation.id;
      _currentConversation = conversation;
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty ||
        _selectedConversationId == null ||
        _currentConversation == null) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final success = await _chatService.sendMessage(
        conversationId: _selectedConversationId!,
        itemId: _currentConversation!.itemId,
        receiverId: _currentConversation!.getOtherUserId(_currentUserId),
        message: message,
      );

      if (success) {
        _messageController.clear();
        // Scroll to bottom after sending
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _deleteConversation(String conversationId) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Conversation'),
            content: const Text(
                'Are you sure you want to delete this conversation? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      try {
        final success = await _chatService.deleteConversation(conversationId);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conversation deleted successfully')),
          );
          if (_selectedConversationId == conversationId) {
            setState(() {
              _selectedConversationId = null;
              _currentConversation = null;
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete conversation')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _selectedConversationId == null
            ? const Text('Messages')
            : _buildChatAppBarTitle(theme),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _selectedConversationId == null
              ? () => Navigator.pop(context)
              : widget.conversationId == null
                  ? () {
                      setState(() {
                        _selectedConversationId = null;
                        _currentConversation = null;
                      });
                    }
                  : () => Navigator.pop(context),
        ),
        actions: _selectedConversationId != null
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      _deleteConversation(_selectedConversationId!),
                ),
              ]
            : null,
      ),
      body: _selectedConversationId == null
          ? _buildConversationsList(theme)
          : _buildChatScreen(theme),
    );
  }

  Widget _buildChatAppBarTitle(ThemeData theme) {
    if (_currentConversation == null) {
      return const Text('Chat');
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: _currentConversation!
                  .getOtherUserAvatar(_currentUserId)
                  .isNotEmpty
              ? CachedNetworkImageProvider(
                  _currentConversation!.getOtherUserAvatar(_currentUserId),
                )
              : null,
          child:
              _currentConversation!.getOtherUserAvatar(_currentUserId).isEmpty
                  ? const Icon(Icons.person, size: 16)
                  : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentConversation!.getOtherUserName(_currentUserId),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _currentConversation!.itemTitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimary.withOpacity(0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConversationsList(ThemeData theme) {
    return StreamBuilder<List<MarketplaceConversation>>(
      stream: _chatService.getUserConversations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final conversations = snapshot.data ?? [];

        if (conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.message_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your conversations with sellers and buyers will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            return _buildConversationTile(conversation, theme);
          },
        );
      },
    );
  }

  Widget _buildConversationTile(
      MarketplaceConversation conversation, ThemeData theme) {
    final otherUserName = conversation.getOtherUserName(_currentUserId);
    final otherUserAvatar = conversation.getOtherUserAvatar(_currentUserId);

    return ListTile(
      onTap: () => _selectConversation(conversation),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: otherUserAvatar.isNotEmpty
                ? CachedNetworkImageProvider(otherUserAvatar)
                : null,
            child: otherUserAvatar.isEmpty ? const Icon(Icons.person) : null,
          ),
          if (!conversation.isRead)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              otherUserName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight:
                    !conversation.isRead ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            timeago.format(conversation.lastMessageTime),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontWeight:
                  !conversation.isRead ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conversation.lastMessage.isNotEmpty
                ? conversation.lastMessage
                : 'No messages yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: !conversation.isRead
                  ? theme.colorScheme.onSurface
                  : Colors.grey[600],
              fontWeight:
                  !conversation.isRead ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.category,
                      size: 12,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      conversation.itemTitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: conversation.itemImage.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: CachedNetworkImage(
                  imageUrl: conversation.itemImage,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.grey[200]),
                  errorWidget: (context, url, error) =>
                      Container(color: Colors.grey[200]),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildChatScreen(ThemeData theme) {
    if (_selectedConversationId == null) {
      return const Center(child: Text('No conversation selected'));
    }

    return Column(
      children: [
        // Item banner
        if (_currentConversation != null)
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ItemDetailScreen(
                    itemId: _currentConversation!.itemId,
                  ),
                ),
              );
            },
            child: Container(
              color: theme.colorScheme.surface,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  if (_currentConversation!.itemImage.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: CachedNetworkImage(
                          imageUrl: _currentConversation!.itemImage,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: Colors.grey[200]),
                          errorWidget: (context, url, error) =>
                              Container(color: Colors.grey[200]),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentConversation!.itemTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Tap to view item',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),

        // Messages list
        Expanded(
          child: StreamBuilder<List<MarketplaceMessage>>(
            stream: _chatService.getMessages(_selectedConversationId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final messages = snapshot.data ?? [];

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.message_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Send a message to start the conversation',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isCurrentUser = message.senderId == _currentUserId;
                  final showAvatar = index == 0 ||
                      messages[index - 1].senderId != message.senderId;

                  return _buildMessageBubble(
                    message,
                    isCurrentUser,
                    showAvatar,
                    theme,
                  );
                },
              );
            },
          ),
        ),

        // Message input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: theme.colorScheme.onPrimary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send),
                    color: theme.colorScheme.onPrimary,
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(
    MarketplaceMessage message,
    bool isCurrentUser,
    bool showAvatar,
    ThemeData theme,
  ) {
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
      bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser && showAvatar)
            CircleAvatar(
              radius: 16,
              backgroundImage: message.senderAvatar.isNotEmpty
                  ? CachedNetworkImageProvider(message.senderAvatar)
                  : null,
              child: message.senderAvatar.isEmpty
                  ? const Icon(Icons.person, size: 16)
                  : null,
            )
          else if (!isCurrentUser && !showAvatar)
            const SizedBox(width: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isCurrentUser
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(message.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isCurrentUser
                          ? theme.colorScheme.onPrimary.withOpacity(0.7)
                          : Colors.grey[600],
                      fontSize: 10,
                    ),
                    textAlign: isCurrentUser ? TextAlign.right : TextAlign.left,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isCurrentUser && showAvatar)
            CircleAvatar(
              radius: 16,
              backgroundImage: message.senderAvatar.isNotEmpty
                  ? CachedNetworkImageProvider(message.senderAvatar)
                  : null,
              child: message.senderAvatar.isEmpty
                  ? const Icon(Icons.person, size: 16)
                  : null,
            )
          else if (isCurrentUser && !showAvatar)
            const SizedBox(width: 32),
        ],
      ),
    );
  }
}
