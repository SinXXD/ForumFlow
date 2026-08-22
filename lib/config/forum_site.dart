import 'package:flutter/foundation.dart';

/// 论坛站点配置（多论坛支持）
///
/// 每个 [ForumSite] 对应一个 Discourse 论坛实例。
/// - [id] 使用规范化 host（如 `linux.do`）作为唯一标识，
///   同时作为登录态存储命名空间的前缀
/// - [isPreset] 为 true 表示预置站点（代码内置，UI 上不可删除）
@immutable
class ForumSite {
  /// 站点唯一 id = 规范化 host（如 `linux.do`）
  final String id;

  /// 显示名称（如 `Linux.do`）
  final String name;

  /// 站点根 URL（如 `https://linux.do`）
  final String baseUrl;

  /// 是否预置站点（不可删除）
  final bool isPreset;

  /// 站点登录页使用的 hCaptcha sitekey。
  ///
  /// 预置站点可以直接提供已知配置；为空时，登录 WebView 会在当前站点
  /// 的原生登录页中只提取合法的 sitekey，不读取页面文案或执行页面指令。
  final String? hcaptchaSiteKey;

  const ForumSite({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.isPreset = false,
    this.hcaptchaSiteKey,
  });

  /// 规范化 host
  String get host => Uri.parse(baseUrl).host;

  /// 从用户输入构造站点，id 自动取规范化 host
  factory ForumSite.fromBaseUrl({
    required String name,
    required String baseUrl,
    bool isPreset = false,
  }) {
    var input = baseUrl.trim();
    if (!input.contains('://')) {
      input = 'https://$input';
    }
    final uri = Uri.tryParse(input);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw FormatException('无效的论坛地址: $baseUrl');
    }
    final host = uri.host;
    // 规范化为 scheme://<host>[:port] 形式
    final normalized =
        '${uri.scheme}://$host${uri.hasPort ? ':${uri.port}' : ''}';
    return ForumSite(
      id: host,
      name: name,
      baseUrl: normalized,
      isPreset: isPreset,
    );
  }

  factory ForumSite.fromJson(Map<String, dynamic> json) => ForumSite(
        id: json['id'] as String,
        name: json['name'] as String? ?? json['id'] as String,
        baseUrl: json['baseUrl'] as String,
        isPreset: json['isPreset'] as bool? ?? false,
        hcaptchaSiteKey: json['hcaptchaSiteKey'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'isPreset': isPreset,
        if (hcaptchaSiteKey != null) 'hcaptchaSiteKey': hcaptchaSiteKey,
      };

  @override
  bool operator ==(Object other) => other is ForumSite && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ForumSite($name, $baseUrl)';
}
