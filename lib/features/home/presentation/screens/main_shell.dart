import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom tabs: 홈 / 내정보.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        height: 52,
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, size: 20),
            selectedIcon: Icon(Icons.home, size: 20),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, size: 20),
            selectedIcon: Icon(Icons.person, size: 20),
            label: '내정보',
          ),
        ],
      ),
    );
  }
}
