import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/app_router.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';

class BlindWeeklyMazeApp extends ConsumerWidget {
  const BlindWeeklyMazeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Blind Weekly Maze',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
    );
  }
}
