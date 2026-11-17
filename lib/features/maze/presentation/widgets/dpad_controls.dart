import 'package:flutter/material.dart';

class DpadControls extends StatelessWidget {
  const DpadControls({
    super.key,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
  });

  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, VoidCallback onTap) {
      return IconButton.filledTonal(
        onPressed: onTap,
        iconSize: 32,
        style: IconButton.styleFrom(
          minimumSize: const Size(64, 64),
        ),
        icon: Icon(icon),
      );
    }

    return Column(
      children: [
        btn(Icons.keyboard_arrow_up, onUp),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            btn(Icons.keyboard_arrow_left, onLeft),
            const SizedBox(width: 64),
            btn(Icons.keyboard_arrow_right, onRight),
          ],
        ),
        btn(Icons.keyboard_arrow_down, onDown),
      ],
    );
  }
}
