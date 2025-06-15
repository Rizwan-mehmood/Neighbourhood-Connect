import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_widget.dart'; // Replace with the actual file path

class PostListScreen extends StatefulWidget {
  @override
  _PostListScreenState createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _posts = []; // Changed to hold Map data
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(10) // Fetch 10 posts at a time
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          // Add docId to each post's data
          _posts.addAll(querySnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id; // Add document ID as 'id' in the post data
            return data;
          }).toList());
        });
      }
    } catch (e) {
      print("Error fetching posts: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts'),
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: _posts.length + 1,
        itemBuilder: (context, index) {
          if (index < _posts.length) {
            final postData = _posts[index];
            return PostWidget(
              postData: postData,
              currentUserId: FirebaseAuth.instance.currentUser!.uid,
            );
          } else if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return ElevatedButton(
              onPressed: _fetchPosts,
              child: const Text('Load More'),
            );
          }
        },
      ),
    );
  }
}
