class AppSettings {
  // Notifications
  final bool notifyTelegramEnabled;
  final bool notifyEmailEnabled;

  // NEW: notify on assistant answer
  final bool notifyOnAnswer;

  // Telegram
  final String telegramBotToken;
  final String telegramChatId;

  // Email (SMTP)
  final String smtpHost;
  final int smtpPort;
  final bool smtpUseTls;
  final String smtpUsername;
  final String smtpPassword;
  final String emailTo;

  // Updates
  final bool checkUpdatesOnStartup;
  final String githubOwner;
  final String githubRepo;

  final bool showTokensInChat;
  final bool showCostInChat;
  final bool showModelInfoInChat;

  const AppSettings({
    this.notifyTelegramEnabled = false,
    this.notifyEmailEnabled = false,
    this.notifyOnAnswer = true, // разумный дефолт

    this.telegramBotToken = '',
    this.telegramChatId = '',
    this.smtpHost = '',
    this.smtpPort = 587,
    this.smtpUseTls = true,
    this.smtpUsername = '',
    this.smtpPassword = '',
    this.emailTo = '',
    this.checkUpdatesOnStartup = true,
    this.githubOwner = '',
    this.githubRepo = '',
    this.showTokensInChat = true,
    this.showCostInChat = true,
    this.showModelInfoInChat = true,
  });

  AppSettings copyWith({
    bool? notifyTelegramEnabled,
    bool? notifyEmailEnabled,
    bool? notifyOnAnswer,
    String? telegramBotToken,
    String? telegramChatId,
    String? smtpHost,
    int? smtpPort,
    bool? smtpUseTls,
    String? smtpUsername,
    String? smtpPassword,
    String? emailTo,
    bool? checkUpdatesOnStartup,
    String? githubOwner,
    String? githubRepo,
    bool? showTokensInChat,
    bool? showCostInChat,
    bool? showModelInfoInChat,
  }) {
    return AppSettings(
      notifyTelegramEnabled:
          notifyTelegramEnabled ?? this.notifyTelegramEnabled,
      notifyEmailEnabled: notifyEmailEnabled ?? this.notifyEmailEnabled,
      notifyOnAnswer: notifyOnAnswer ?? this.notifyOnAnswer,
      telegramBotToken: telegramBotToken ?? this.telegramBotToken,
      telegramChatId: telegramChatId ?? this.telegramChatId,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      smtpUseTls: smtpUseTls ?? this.smtpUseTls,
      smtpUsername: smtpUsername ?? this.smtpUsername,
      smtpPassword: smtpPassword ?? this.smtpPassword,
      emailTo: emailTo ?? this.emailTo,
      checkUpdatesOnStartup:
          checkUpdatesOnStartup ?? this.checkUpdatesOnStartup,
      githubOwner: githubOwner ?? this.githubOwner,
      githubRepo: githubRepo ?? this.githubRepo,
      showTokensInChat: showTokensInChat ?? this.showTokensInChat,
      showCostInChat: showCostInChat ?? this.showCostInChat,
      showModelInfoInChat: showModelInfoInChat ?? this.showModelInfoInChat,
    );
  }
}
