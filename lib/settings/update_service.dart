import 'dart:convert';
import 'package:http/http.dart' as http;

class UpdateInfo {
  final bool hasUpdate;
  final String current;
  final String latest;
  final String htmlUrl;

  const UpdateInfo({
    required this.hasUpdate,
    required this.current,
    required this.latest,
    required this.htmlUrl,
  });
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  int _cmpVersion(String a, String b) {
    // "v1.2.3" -> "1.2.3"
    String norm(String s) => s.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final pa = norm(a).split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = norm(b).split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (pa.length < 3) {
      pa.add(0);
    }
    while (pb.length < 3) {
      pb.add(0);
    }
    for (int i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
    }
    return 0;
  }

  Future<UpdateInfo> checkGithubLatest({
    required String owner,
    required String repo,
    required String currentVersion,
  }) async {
    if (owner.trim().isEmpty || repo.trim().isEmpty) {
      throw Exception('GitHub owner/repo не заполнены');
    }

    final uri =
        Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
    final resp = await http.get(uri, headers: {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'AIChatFlutter',
    }).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception('GitHub API error: ${resp.statusCode} ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final latestTag = (json['tag_name'] ?? '').toString();
    final htmlUrl = (json['html_url'] ?? '').toString();

    if (latestTag.isEmpty) {
      throw Exception('GitHub: tag_name пустой');
    }

    final cmp = _cmpVersion(currentVersion, latestTag);
    final hasUpdate = cmp < 0;

    return UpdateInfo(
      hasUpdate: hasUpdate,
      current: currentVersion,
      latest: latestTag,
      htmlUrl: htmlUrl,
    );
  }
}
