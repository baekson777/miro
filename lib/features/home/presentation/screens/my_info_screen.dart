import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/ui/top_toast.dart';
import '../../../auth/data/game_nickname_service.dart';
import '../../../auth/data/user_firestore_repository.dart';
import '../../../auth/domain/nickname_rules.dart';
import '../../../auth/presentation/auth_session.dart';
import '../../../auth/presentation/guest_play_notice.dart';
import '../../../auth/presentation/widgets/kakao_firestore_login_button.dart';
import '../../../leaderboard/data/leaderboard_repository.dart';

/// Account + game nickname (not Kakao profile name).
class MyInfoScreen extends ConsumerStatefulWidget {
  const MyInfoScreen({super.key});

  @override
  ConsumerState<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends ConsumerState<MyInfoScreen> {
  final _nickCtrl = TextEditingController();
  final _nickService = GameNicknameService();
  bool _loadingNick = true;
  bool _savingNick = false;
  bool _withdrawing = false;

  @override
  void initState() {
    super.initState();
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    final prefs = await SharedPreferences.getInstance();
    var nick = LeaderboardRepository(prefs).nickname;

    final session = ref.read(authSessionProvider);
    if (session.isLoggedIn) {
      try {
        final remote =
            await UserFirestoreRepository().gameNicknameFor(session.user!.id);
        if (remote != null && remote.isNotEmpty) {
          nick = remote;
          await LeaderboardRepository(prefs).setNickname(remote);
        }
      } catch (e) {
        debugPrint('[MyInfo] remote nick load skipped: $e');
      }
    }

    if (!mounted) return;
    if (nick != null && nick.isNotEmpty) {
      _nickCtrl.text = nick;
    }
    setState(() => _loadingNick = false);
  }

  Future<void> _saveNickname() async {
    final raw = _nickCtrl.text;
    final formatError = NicknameRules.validate(raw);
    if (formatError != null) {
      TopToast.show(context, formatError);
      return;
    }

    final session = ref.read(authSessionProvider);
    setState(() => _savingNick = true);
    try {
      final saved = await _nickService.save(
        nickname: raw,
        kakaoId: session.isLoggedIn ? session.user!.id : null,
      );
      if (!mounted) return;
      _nickCtrl.text = saved;
      TopToast.show(context, '닉네임이 저장되었습니다.');
    } on NicknameTakenException {
      if (!mounted) return;
      TopToast.show(context, '이미 사용 중인 닉네임입니다. 다른 이름을 입력해 주세요.');
    } on ArgumentError catch (e) {
      if (!mounted) return;
      TopToast.show(context, e.message?.toString() ?? '닉네임을 확인해 주세요.');
    } catch (e) {
      if (!mounted) return;
      TopToast.show(context, '닉네임 저장 실패: $e');
    } finally {
      if (mounted) setState(() => _savingNick = false);
    }
  }

  Future<void> _confirmWithdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text(
          '카카오 연동이 해제되고, 서버에 저장된 닉네임·계정 정보가 삭제됩니다.\n'
          '이 기기의 관련 기록도 함께 정리됩니다.\n\n'
          '정말 탈퇴하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _withdrawing = true);
    try {
      await ref.read(authSessionProvider).deleteAccount();
      if (!mounted) return;
      _nickCtrl.clear();
      TopToast.show(context, '회원탈퇴가 완료되었습니다.');
    } catch (e) {
      if (!mounted) return;
      TopToast.show(context, '회원탈퇴 실패: $e');
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(authSessionProvider).isLoggedIn;

    return Scaffold(
      appBar: AppBar(title: const Text('내정보')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (loggedIn) ...[
              Text(
                '게임 닉네임',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '순위표에 표시되는 이름입니다. 다른 사람과 겹칠 수 없습니다. (${NicknameRules.minLength}~${NicknameRules.maxLength}자)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 12),
              if (_loadingNick)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                TextField(
                  controller: _nickCtrl,
                  decoration: const InputDecoration(
                    labelText: '닉네임',
                    hintText: '예: 미로고수',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: NicknameRules.maxLength,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveNickname(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _savingNick ? null : _saveNickname,
                  child: _savingNick
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('닉네임 저장'),
                ),
              ],
              const SizedBox(height: 40),
            ],
            Text(
              '약관 및 정책',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('개인정보 처리방침'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RoutePaths.privacyPolicy),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: const Text('이용약관'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RoutePaths.terms),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_off_outlined),
              title: const Text('연동 회원탈퇴 안내'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RoutePaths.accountDeletion),
            ),
            const SizedBox(height: 32),
            const KakaoFirestoreLoginButton(),
            if (loggedIn) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _withdrawing ? null : _confirmWithdraw,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _withdrawing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('회원탈퇴'),
              ),
            ],
            if (!loggedIn) ...[
              const SizedBox(height: 10),
              const GuestPlayNoticeBanner(
                message: GuestPlayNotice.home,
                compact: true,
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
