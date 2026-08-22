import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/forum_site.dart';
import '../config/site_context.dart';
import '../providers/app_state_refresher.dart';
import 'auth_session.dart';
import 'browser_trust_coordinator.dart';
import 'cf_clearance_refresh_service.dart';
import 'discourse/discourse_service.dart';
import 'message_bus_service.dart';
import 'network/adapters/webview_http_adapter.dart';
import 'network/cookie/webview_cookie_priming.dart';
import 'network/discourse_dio.dart';
import 'preloaded_data_service.dart';
import 'webview_session_cookie_refresh_service.dart';

/// 论坛切换编排服务。
///
/// 一次切换的完整动作（语义 = 针对新站点的「登出旧站 + 登入新站」）：
/// 1. 会话代推进：取消旧站点所有在途请求，迟到响应一律作废
/// 2. 更新当前站点（持久化 + 通知 UI）
/// 3. 重置登录态：清旧站内存态、按新站重载凭证、重置 CSRF
/// 4. 重置并重新预加载新站点数据（site.json / 分类 / 当前用户）
/// 5. 数据就绪后全量刷新各 provider（invalidate 时读到的已是新站数据）
class ForumSwitchService {
  ForumSwitchService._();
  static final ForumSwitchService instance = ForumSwitchService._();

  bool _switching = false;

  /// 是否正在切换（UI 可用来显示切换中状态）
  bool get isSwitching => _switching;

  /// 切换到 [site]。已在目标站点或切换进行中时直接返回。
  static Future<void> switchTo(
    ProviderContainer container,
    ForumSite site,
  ) async {
    final ctx = SiteContext.instance;
    if (site.id == ctx.current.id) return;
    if (instance._switching) return;
    instance._switching = true;
    try {
      debugPrint('[ForumSwitch] 切换到 ${site.id}');

      // 1. 会话代推进：取消旧站点所有在途请求
      AuthSession().advance();

      // 2. 更新当前站点（持久化 + 通知监听者）
      await ctx.setCurrent(site);

      // 已创建的 Dio 会缓存 BaseOptions.baseUrl，先统一切到新站；否则
      // 后续所有以 `/path` 形式发出的请求仍会落到旧论坛。
      DiscourseDio.refreshSiteBaseUrls();

      // 停止旧站的长轮询和 WebView 会话 bootstrap。站点域名不同，
      // priming / bootstrap 的成功态不能跨站复用。
      MessageBusService().resetForSiteSwitch();
      await CfClearanceRefreshService().resetForSiteSwitch();
      WebViewHttpAdapter.resetAllForSiteSwitch();
      WebViewCookiePriming.instance.invalidate();
      WebViewSessionCookieRefreshService.instance.resetSessionState(
        reason: 'site-switch',
      );
      BrowserTrustCoordinator.instance.resetForSiteSwitch();

      // 3. 重置登录态 + 按新站重载凭证 + 重置 CSRF
      await DiscourseService().resetForSiteSwitch();

      // 4. 重置预加载状态并拉取新站数据。
      //    resetForSiteSwitch 使 _loaded=false，ensurePreloaded 不会短路。
      PreloadedDataService().resetForSiteSwitch();
      try {
        await BrowserTrustCoordinator.instance
            .ensurePreloaded(reason: 'site-switch');
      } catch (e) {
        debugPrint('[ForumSwitch] 新站预加载失败(不阻断切换): $e');
      }

      // 5. 数据就绪后全量刷新（invalidate 后各 provider 取新站数据）
      AppStateRefresher.refreshAll(container, force: true);
      debugPrint('[ForumSwitch] 切换完成: ${site.id}');
    } finally {
      instance._switching = false;
    }
  }
}
