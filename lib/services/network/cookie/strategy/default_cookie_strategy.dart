import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../raw_cookie_writer.dart';
import 'platform_cookie_strategy.dart';

/// 默认 cookie 策略（Windows 等）
class DefaultCookieStrategy implements PlatformCookieStrategy {
  @override
  Future<List<Cookie>> readCookiesFromWebView(
    CookieManager cookieManager,
    String url,
  ) async {
    return cookieManager.getCookies(url: WebUri(url));
  }

  @override
  Future<void> clearWebViewCookies(
    CookieManager cookieManager,
    Set<String> knownHosts,
  ) async {
    await cookieManager.deleteAllCookies();
  }

  @override
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

  @override
  Future<int> writeRawCookiesToWebView(
    List<(String url, String rawHeader)> entries,
  ) async {
    final writer = RawCookieWriter.instance;
    if (!writer.isSupported) return 0;

    var written = 0;
    for (final (url, raw) in entries) {
      try {
        if (await writer.setRawCookie(url, raw)) written++;
      } catch (e) {
        debugPrint('[CookieStrategy] 写入 WebView 失败: $e');
      }
    }
    return written;
  }
}
