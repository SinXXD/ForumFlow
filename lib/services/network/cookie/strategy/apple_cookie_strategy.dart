import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../constants.dart';
import 'default_cookie_strategy.dart';

/// Apple (iOS / macOS) cookie 策略
///
/// WKWebView 的 sharedCookiesEnabled 会从 HTTPCookieStorage.shared 读 cookie。
/// 仅清 WKHTTPCookieStore 不够，需要同时清 HTTPCookieStorage.shared。
class AppleCookieStrategy extends DefaultCookieStrategy {
  static const _nativeCookieChannel = MethodChannel('com.fluxdo/cookie_storage');

  @override
  Future<void> clearWebViewCookies(
    CookieManager cookieManager,
    Set<String> knownHosts,
  ) async {
    // 清除 WKHTTPCookieStore
    await cookieManager.deleteAllCookies();

    // 同时清除 HTTPCookieStorage.shared
    try {
      await _nativeCookieChannel.invokeMethod(
        'clearCookies',
        AppConstants.baseUrl,
      );
    } catch (e) {
      debugPrint('[CookieStrategy][Apple] HTTPCookieStorage clear failed: $e');
    }
  }

  @override
  Future<void> clearWebViewCookiesForHosts(
    CookieManager cookieManager,
    Set<String> knownHosts,
  ) async {
    await super.clearWebViewCookiesForHosts(cookieManager, knownHosts);

    // WKHTTPCookieStore 与 HTTPCookieStorage.shared 是两套存储，
    // Dart 侧逐 cookie 删除不能覆盖 shared storage，因此每个相关 host
    // 都通过原生通道执行一次站点范围清理。
    for (final host in knownHosts) {
      try {
        await _nativeCookieChannel.invokeMethod(
          'clearCookies',
          'https://$host',
        );
      } catch (e) {
        debugPrint(
          '[CookieStrategy][Apple] per-host shared cookie clear failed '
          'for $host: $e',
        );
      }
    }
  }
}
