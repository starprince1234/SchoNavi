import 'package:url_launcher/url_launcher.dart';

import 'link_launcher.dart';

/// 基于 url_launcher 的实现，用系统浏览器（externalApplication）打开。
class UrlLauncherLinkLauncher implements LinkLauncher {
  const UrlLauncherLinkLauncher();

  @override
  Future<LaunchResult> open(String? url) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return LaunchResult.noUrl;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return LaunchResult.failed;
    }

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return ok ? LaunchResult.success : LaunchResult.failed;
    } catch (_) {
      return LaunchResult.failed;
    }
  }
}
