import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/launcher/link_launcher.dart';
import 'package:scho_navi/core/launcher/url_launcher_link_launcher.dart';

void main() {
  const launcher = UrlLauncherLinkLauncher();

  test('null url → noUrl', () async {
    expect(await launcher.open(null), LaunchResult.noUrl);
  });

  test('空白 url → noUrl', () async {
    expect(await launcher.open('   '), LaunchResult.noUrl);
  });

  test('缺 scheme 的 url → failed', () async {
    expect(await launcher.open('example.edu.cn/zhangsan'), LaunchResult.failed);
  });

  test('非 http(s) scheme → failed', () async {
    expect(await launcher.open('ftp://example.edu.cn'), LaunchResult.failed);
  });
}
