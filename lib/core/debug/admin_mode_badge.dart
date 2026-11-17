import 'package:flutter/material.dart';

/// Red corner badge shown only while admin mode is active.
class AdminModeBadge extends StatelessWidget {
  const AdminModeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0x33FF1744),
        borderRadius: BorderRadius.all(Radius.circular(4)),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0xFFFF1744), width: 1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          '[관리자 모드]',
          style: TextStyle(
            color: Color(0xFFFF1744),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
