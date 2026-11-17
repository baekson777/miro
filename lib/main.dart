import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'app.dart';
import 'core/constants/kakao_app_keys.dart';
import 'features/maze/data/weekly_seed_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase first so later auth/sync can use it immediately.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[Firebase] initialized');
  } catch (e) {
    debugPrint('[Firebase] init skipped: $e');
  }

  // Kakao native channel can fail if plugins are not ready yet (esp. release).
  // Never block app launch on Kakao init failure.
  try {
    await KakaoSdk.init(nativeAppKey: KakaoAppKeys.nativeAppKey);
    debugPrint('[Kakao] initialized');
  } catch (e) {
    debugPrint('[Kakao] init failed (will retry after first frame): $e');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await KakaoSdk.init(nativeAppKey: KakaoAppKeys.nativeAppKey);
        debugPrint('[Kakao] initialized on retry');
      } catch (e2) {
        debugPrint('[Kakao] retry failed: $e2');
      }
    });
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  WeeklySeedService.ensureInitialized();

  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint('MobileAds init skipped: $e');
  }

  runApp(const ProviderScope(child: BlindWeeklyMazeApp()));
}
