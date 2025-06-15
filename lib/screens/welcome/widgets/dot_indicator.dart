import 'package:flutter/material.dart';

class DotIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalDots;

  const DotIndicator({
    Key? key,
    required this.currentIndex,
    required this.totalDots,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalDots,
            (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5.0),
          height: 10.0,
          width: 10.0,
          decoration: BoxDecoration(
            color: currentIndex == index ? Colors.blue : Colors.blue.shade100,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
