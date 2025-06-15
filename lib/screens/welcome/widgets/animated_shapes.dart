import 'package:flutter/material.dart';

class AnimatedShapes extends StatefulWidget {
  final int index;

  const AnimatedShapes({Key? key, required this.index}) : super(key: key);

  @override
  _AnimatedShapesState createState() => _AnimatedShapesState();
}

class _AnimatedShapesState extends State<AnimatedShapes> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Initialize animation controller and animation
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 4),  // Duration for one loop
      vsync: this,
    )..repeat(reverse: true); // Repeat the animation in reverse (back and forth)

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          children: [
            // Animated circles that move based on the current screen's index
            Positioned(
              top: 50 + widget.index * 20.0, // Adjust position based on screen index
              left: 50 * _animation.value,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 80 + widget.index * 20.0, // Adjust position based on screen index
              right: 40 * _animation.value,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
