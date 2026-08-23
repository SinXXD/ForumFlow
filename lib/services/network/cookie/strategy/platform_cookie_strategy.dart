import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'android_cookie_strategy.dart';
import 'apple_cookie_strategy.dart';
import 'default_cookie_strategy.dart';
import 'linux_cookie_strategy.dart';

/// 平台 cookie 策略抽象基类。
///
/// 只封装真正有平台差异的操作，不包含业务同步逻辑。
abstract class PlatformCookieStrategy {
  /// 工厂方法：根据平台返回对应策略
  factory PlatformCookieStrategy.create() {
    if (io.Platform.isAndroid) return AndroidCookieStrategy();
    if (io.Platform.isIOS || io.Platform.isMacOS) return AppleCookieStrategy();
    if (io.Platform.isLinux) return LinuxCookieStrategy();
    return DefaultCookieStrategy();
  }

  /// 从 WebView 读取指定 URL 的 cookie 列表
  /// 默认用 CookieManager.getCookies(url:)，Linux 覆写为 getAllCookies() 过滤
  Future<List<Cookie>> readCookiesFromWebView(CookieManager cookieManager, String url);

  /// 清除 WebView cookie store 中所有 cookie
  Future<void> clearWebViewCookies(CookieManager cookieManager, Set<String> knownHosts);

  /// 只清除指定 host 及其可见子域的 cookie。
  ///
  /// 登出单个论坛时必须使用这个入口，不能调用全量清理，否则会把其它
  /// 论坛的 WebView 登录态一并删除。
  Future<void> clearWebViewCookiesForHosts(
    CookieManager cookieManager,
    Set<String> knownHosts,
  ) async {
    for (final host in knownHosts) {
      final url = WebUri('https://$host');
      try {
        final cookies = await cookieManager.getCookies(url: url);
        for (final cookie in cookies) {
          await cookieManager.deleteCookie(
            url: url,
            name: cookie.name,
            domain: cookie.domain,
            path: cookie.path ?? '/',
          );
        }
      } catch (e) {
        // 单个 host 清理失败不阻断其它 host；调用方会继续清理 CookieJar。
        debugPrint(
          '[CookieStrategy] per-host WebView cookie clear failed '
          'for $host: $e',
        );
      }
    }
  }

  /// 将原始 Set-Cookie 头批量写入 WebView
  /// 返回成功写入的条数
  Future<int> writeRawCookiesToWebView(List<(String url, String rawHeader)> entries);
}
