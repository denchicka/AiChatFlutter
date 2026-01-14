import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_settings.dart';

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _sec = FlutterSecureStorage();

  // prefs keys
  static const kNotifyTelegram = 'notify_telegram';
  static const kNotifyEmail = 'notify_email';
  static const kTelegramChatId = 'telegram_chat_id';
  static const kSmtpHost = 'smtp_host';
  static const kSmtpPort = 'smtp_port';
  static const kSmtpUseTls = 'smtp_tls';
  static const kSmtpUsername = 'smtp_user';
  static const kEmailTo = 'email_to';
  static const kCheckUpdatesOnStartup = 'upd_on_start';
  static const kGithubOwner = 'gh_owner';
  static const kGithubRepo = 'gh_repo';
  static const kNotifyOnAnswer = 'notify_on_answer';
  static const kShowTokensInChat = 'chat_show_tokens';
  static const kShowCostInChat = 'chat_show_cost';
  static const kShowModelInfoInChat = 'chat_show_model_info';
  // secure keys
  static const kTelegramBotTokenSec = 'sec_telegram_bot_token';
  static const kSmtpPasswordSec = 'sec_smtp_password';

  Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();

    final telegramBotToken = (await _sec.read(key: kTelegramBotTokenSec)) ?? '';
    final smtpPassword = (await _sec.read(key: kSmtpPasswordSec)) ?? '';

    return AppSettings(
      notifyTelegramEnabled: p.getBool(kNotifyTelegram) ?? false,
      notifyEmailEnabled: p.getBool(kNotifyEmail) ?? false,
      telegramBotToken: telegramBotToken,
      telegramChatId: p.getString(kTelegramChatId) ?? '',
      smtpHost: p.getString(kSmtpHost) ?? '',
      smtpPort: p.getInt(kSmtpPort) ?? 587,
      smtpUseTls: p.getBool(kSmtpUseTls) ?? true,
      smtpUsername: p.getString(kSmtpUsername) ?? '',
      smtpPassword: smtpPassword,
      emailTo: p.getString(kEmailTo) ?? '',
      checkUpdatesOnStartup: p.getBool(kCheckUpdatesOnStartup) ?? true,
      githubOwner: p.getString(kGithubOwner) ?? '',
      githubRepo: p.getString(kGithubRepo) ?? '',
      notifyOnAnswer: p.getBool(kNotifyOnAnswer) ?? true,

      // NEW: chat meta
      showTokensInChat: p.getBool(kShowTokensInChat) ?? true,
      showCostInChat: p.getBool(kShowCostInChat) ?? true,
      showModelInfoInChat: p.getBool(kShowModelInfoInChat) ?? true,
    );
  }

  Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();

    await p.setBool(kNotifyTelegram, s.notifyTelegramEnabled);
    await p.setBool(kNotifyEmail, s.notifyEmailEnabled);
    await p.setBool(kNotifyOnAnswer, s.notifyOnAnswer);

    await p.setString(kTelegramChatId, s.telegramChatId);

    await p.setString(kSmtpHost, s.smtpHost);
    await p.setInt(kSmtpPort, s.smtpPort);
    await p.setBool(kSmtpUseTls, s.smtpUseTls);
    await p.setString(kSmtpUsername, s.smtpUsername);
    await p.setString(kEmailTo, s.emailTo);

    await p.setBool(kCheckUpdatesOnStartup, s.checkUpdatesOnStartup);
    await p.setString(kGithubOwner, s.githubOwner);
    await p.setString(kGithubRepo, s.githubRepo);

    // secure
    await _sec.write(key: kTelegramBotTokenSec, value: s.telegramBotToken);
    await _sec.write(key: kSmtpPasswordSec, value: s.smtpPassword);

    await p.setBool(kShowTokensInChat, s.showTokensInChat);
    await p.setBool(kShowCostInChat, s.showCostInChat);
    await p.setBool(kShowModelInfoInChat, s.showModelInfoInChat);
  }

  Future<void> clearSecrets() async {
    await _sec.delete(key: kTelegramBotTokenSec);
    await _sec.delete(key: kSmtpPasswordSec);
  }
}
