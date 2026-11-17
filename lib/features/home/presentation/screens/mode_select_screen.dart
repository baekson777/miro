import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/navigation/navigation_manager.dart';
import '../../../maze/data/weekly_seed_service.dart';
import '../../../maze/domain/difficulty.dart';
import '../../../maze/domain/game_mode.dart';
import '../../../maze/presentation/controllers/game_controller.dart';

class ModeSelectScreen extends StatelessWidget {
  const ModeSelectScreen({super.key});

  void _startPractice(BuildContext context, Difficulty difficulty) {
    final mode = PracticeMode(
      difficulty: difficulty,
      seed: GameController.randomSeed(Random()),
    );
    NavigationManager.replace(context, '/game', extra: mode);
  }

  void _startWeekly(BuildContext context) {
    final weekId = WeeklySeedService.weekIdFor();
    final mode = WeeklyChallengeMode(
      weekId: weekId,
      seed: WeeklySeedService.seedFromWeekId(weekId),
    );
    NavigationManager.replace(context, '/game', extra: mode);
  }

  void _startFixed(BuildContext context, FixedChallengeMode mode) {
    NavigationManager.replace(context, '/game', extra: mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('모드 선택'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationManager.toHome(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            '랭킹 챌린지',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            '고정 미로 · 공정 경쟁',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 12),
          for (final d in Difficulty.values) ...[
            FilledButton(
              onPressed: () => _startFixed(
                context,
                switch (d) {
                  Difficulty.veryEasy => FixedChallengeMode.veryEasy(),
                  Difficulty.easy => FixedChallengeMode.easy(),
                  Difficulty.normal => FixedChallengeMode.normal(),
                  Difficulty.hard => FixedChallengeMode.hard(),
                  Difficulty.veryHard => FixedChallengeMode.veryHard(),
                },
              ),
              child: Text('${d.label} (${d.size}×${d.size})'),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 24),
          Text(
            '주간 챌린지',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '매주 월요일 00:00(KST) 동일 미로 · ${WeeklySeedService.weekIdFor()}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => _startWeekly(context),
            child: const Text('Weekly Challenge (21×21)'),
          ),
          const SizedBox(height: 32),
          Text(
            '연습 모드',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            '매 판 랜덤 시드',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 12),
          for (final d in Difficulty.values) ...[
            OutlinedButton(
              onPressed: () => _startPractice(context, d),
              child: Text('${d.label} (${d.size}×${d.size})'),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
