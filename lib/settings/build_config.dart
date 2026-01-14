class BuildConfig {
  // Настройки GitHub репозитория для автообновлений
  // Можно переопределить через --dart-define при сборке
  static const String githubOwner =
      String.fromEnvironment('GITHUB_OWNER', defaultValue: 'denchicka');
  static const String githubRepo =
      String.fromEnvironment('GITHUB_REPO', defaultValue: 'AiChatFlutter');

  static bool get hasGithubRepo =>
      githubOwner.trim().isNotEmpty && githubRepo.trim().isNotEmpty;

  static String get githubFull =>
      hasGithubRepo ? '$githubOwner/$githubRepo' : 'не настроено';

  // ВАЖНО: const, чтобы это было compile-time
  static const String creatorTelegramUrl = 'https://t.me/denchicka213';
}
