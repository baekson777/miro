import 'package:flutter/material.dart';

/// Copy for guest (not logged in) vs logged-in ranking behavior.
abstract final class GuestPlayNotice {
  static const home =
      '로그인하지 않으면 순위표에 기록이 남지 않고, 이 기기에만 저장됩니다.';

  static const resultGuest =
      '비로그인 상태입니다. 순위표에는 등록되지 않으며, 기록은 이 기기에만 저장됩니다.';

  static const resultLoggedIn =
      '카카오 연동 계정으로 순위표에 등록됩니다. 닉네임은 직접 입력하세요.';

  static const leaderboard =
      '카카오 로그인 후 등록한 기록만 순위표에 표시됩니다. 비로그인 기록은 각 기기에만 저장됩니다.';

  static const savedDeviceOnly = '이 기기에만 저장되었습니다. (순위표 미등록)';

  static const savedRanking = '순위표에 기록되었습니다.';
}

/// Compact informational banner used on home / result / leaderboard.
class GuestPlayNoticeBanner extends StatelessWidget {
  const GuestPlayNoticeBanner({
    super.key,
    required this.message,
    this.compact = false,
  });

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 8 : 10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: compact ? 16 : 18,
              color: scheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
