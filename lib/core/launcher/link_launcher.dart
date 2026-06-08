/// 打开外链的结果。UI 据此给出对应中文提示（V0.2 §2.5）：
/// noUrl → 「暂无主页信息」；failed → 「主页可能已失效，可通过学校官网确认」。
enum LaunchResult { success, noUrl, failed }

/// 外链打开抽象。feature 层只依赖此接口，便于在 widget 测试中注入假实现。
abstract interface class LinkLauncher {
  /// 用系统浏览器打开 [url]。
  /// - null / 空白 → [LaunchResult.noUrl]
  /// - 非法 / 非 http(s) / 打开失败 → [LaunchResult.failed]
  /// - 成功 → [LaunchResult.success]
  Future<LaunchResult> open(String? url);
}
