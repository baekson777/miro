/// Display strings sourced from [pubspec.yaml] `version`.
abstract final class AppInfo {
  static const versionName = '1.0.0';
  static const buildNumber = '1';

  /// Shown on the home screen (also the admin preview 7-tap target).
  static const versionLabel = 'v$versionName+$buildNumber';
}
