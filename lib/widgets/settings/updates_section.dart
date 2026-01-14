import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../settings/update_service.dart';
import '../../settings/settings_provider.dart';
import '../../settings/build_config.dart';
import 'toggle_tile.dart';
import 'status_line.dart';
import 'info_callout.dart';

class UpdatesSection extends StatefulWidget {
  final SettingsProvider sp;

  const UpdatesSection({super.key, required this.sp});

  @override
  State<UpdatesSection> createState() => _UpdatesSectionState();
}

class _UpdatesSectionState extends State<UpdatesSection> {
  String _version = '—';
  CheckState _state = CheckState.idle;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);
  }

  Future<void> _check() async {
    setState(() {
      _state = CheckState.running;
      _msg = 'Проверка...';
    });

    try {
      final owner = BuildConfig.githubOwner.trim();
      final repo = BuildConfig.githubRepo.trim();
      if (owner.isEmpty || repo.isEmpty) {
        setState(() {
          _state = CheckState.error;
          _msg = 'Repo не задан в build-конфиге';
        });
        return;
      }

      final info = await UpdateService.instance.checkGithubLatest(
        owner: owner,
        repo: repo,
        currentVersion: _version,
      );

      if (!mounted) return;

      if (!info.hasUpdate) {
        setState(() {
          _state = CheckState.ok;
          _msg = 'ОК: обновлений нет (у вас ${info.current})';
        });
        return;
      }

      setState(() {
        _state = CheckState.ok;
        _msg = 'Доступно: ${info.latest} (у вас ${info.current})';
      });

      final uri = Uri.tryParse(info.htmlUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = CheckState.error;
        _msg = 'Ошибка: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sp.s;
    final hasRepo = BuildConfig.hasGithubRepo;

    return Column(
      children: [
        ToggleTile(
          title: 'Автопроверка при запуске',
          subtitle: 'Проверять релизы при старте',
          value: s.checkUpdatesOnStartup,
          onChanged: (v) =>
              widget.sp.update(s.copyWith(checkUpdatesOnStartup: v)),
        ),
        const SizedBox(height: 10),
        if (hasRepo)
          InfoCallout(
            icon: Icons.code_outlined,
            title: 'Источник обновлений',
            body: Text('GitHub: ${BuildConfig.githubFull}'),
          ),
        if (hasRepo) const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    (_state == CheckState.running) ? null : _check,
                icon: _state == CheckState.running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.system_update_alt_rounded, size: 18),
                label: Text(_state == CheckState.running
                    ? 'Проверяем…'
                    : 'Проверить обновления'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        StatusLine(state: _state, text: _msg),
      ],
    );
  }
}
