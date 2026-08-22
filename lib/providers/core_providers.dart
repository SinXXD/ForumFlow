// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../config/site_context.dart';
import '../services/auth_session.dart';
import '../services/discourse/discourse_service.dart';
import '../services/preloaded_data_service.dart';

/// Discourse 服务 Provider
final discourseServiceProvider = Provider((ref) => DiscourseService());

/// 认证错误 Provider（监听登录失效事件）
final authErrorProvider = StreamProvider<String>((ref) {
  final service = ref.watch(discourseServiceProvider);
  return service.authErrorStream;
});

/// 认证状态变化 Provider（登录/退出）
final authStateProvider = StreamProvider<void>((ref) {
  final service = ref.watch(discourseServiceProvider);
  return service.authStateStream;
});

/// 当前用户 Provider
/// 优先使用预加载数据同步返回，避免启动时短暂显示未登录状态
class CurrentUserNotifier extends AsyncNotifier<User?> {
  /// 多论坛支持：缓存按站点隔离，避免跨论坛用户缓存串站。
  static String get _cacheKey =>
      'current_user_cache_${SiteContext.instance.host}';
  static String get _cacheUserKey =>
      'current_user_cache_username_${SiteContext.instance.host}';
  static const Duration _refreshCooldown = Duration(minutes: 2);
  DateTime? _lastRefreshTime;

  @override
  FutureOr<User?> build() {
    final service = ref.read(discourseServiceProvider);
    final siteRevision = SiteContext.instance.revision;
    final siteId = SiteContext.instance.current.id;
    final authGeneration = AuthSession().generation;
    final cacheKey = _cacheKey;
    final cacheUserKey = _cacheUserKey;
    final preloaded = PreloadedDataService().currentUserSync;
    if (preloaded != null) {
      final preloadedUser = User.fromJson(preloaded);
      service.currentUserNotifier.value = preloadedUser;
      _refreshUser(
        service,
        preloadedUser,
        siteRevision: siteRevision,
        siteId: siteId,
        authGeneration: authGeneration,
        cacheKey: cacheKey,
        cacheUserKey: cacheUserKey,
      );
      return preloadedUser;
    }
    return _loadUserWithCache(
      service,
      siteRevision: siteRevision,
      siteId: siteId,
      authGeneration: authGeneration,
      cacheKey: cacheKey,
      cacheUserKey: cacheUserKey,
    );
  }

  Future<User?> _loadUserWithCache(
    DiscourseService service, {
    required int siteRevision,
    required String siteId,
    required int authGeneration,
    required String cacheKey,
    required String cacheUserKey,
  }) async {
    // 先把上次会话的缓存亮出来(毫秒级,登出时缓存会被清,存在即上次已
    // 登录):本 provider 可能在预加载完成前就被 watch(如根部印记层第一
    // 帧即 watch,早于 PreheatGate 放行),此时 build 的同步快路径拿不到
    // preloaded;而下面的 isLoggedIn 含服务端校验、getCurrentUser 是全量
    // 接口,若等它们串行完成才给首值,头像/发帖入口要白等数秒。
    // 渐进 emit:缓存 → preloaded → 接口终态。
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return null;
    final cached = prefs.getString(cacheKey);
    User? cachedUser;
    if (cached != null) {
      try {
        final json = jsonDecode(cached) as Map<String, dynamic>;
        cachedUser = User.fromCacheJson(json);
        if (_isCurrentSnapshot(siteRevision, siteId, authGeneration)) {
          state = AsyncValue.data(cachedUser);
        }
      } catch (_) {
        // 缓存损坏，忽略
      }
    }

    final hasToken = await service.isLoggedIn();
    if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return null;
    if (!hasToken) {
      await prefs.remove(cacheKey);
      await prefs.remove(cacheUserKey);
      return null;
    }

    try {
      final preloadedUser = await service.getPreloadedCurrentUser();
      if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) {
        return null;
      }
      if (preloadedUser != null) {
        state = AsyncValue.data(preloadedUser);
      }
      final user = await service.getCurrentUser();
      if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) {
        return null;
      }
      final resolved = user == null
          ? preloadedUser
          : (preloadedUser == null ? user : _mergeUser(user, preloadedUser));
      if (resolved != null) {
        _saveCache(
          prefs,
          resolved,
          cacheKey: cacheKey,
          cacheUserKey: cacheUserKey,
        );
        return resolved;
      }
      // 网络返回 null 但本地有缓存时，保守处理：保留缓存返回，
      // 避免短暂鉴权抖动把 UI 误判成已登出。
      // 只有在已确认没有 token 的分支（第 48-53 行）才清理缓存。
      if (cachedUser != null) return cachedUser;
      return null;
    } catch (e) {
      if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) {
        return null;
      }
      // 网络失败，返回缓存
      if (cachedUser != null) return cachedUser;
      rethrow;
    }
  }

  Future<User?> _loadUser(
    DiscourseService service, {
    required int siteRevision,
    required String siteId,
    required int authGeneration,
  }) async {
    final preloadedUser = await service.getPreloadedCurrentUser();
    if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return null;
    final user = await service.getCurrentUser();
    if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return null;
    if (user == null) return preloadedUser;
    if (preloadedUser == null) return user;
    return _mergeUser(user, preloadedUser);
  }

  /// 静默刷新，带冷却时间（默认 2 分钟内不重复请求）
  /// 不提前 emit 中间状态，只在拿到结果后更新一次，避免多余 rebuild
  Future<void> refreshSilently({bool force = false}) async {
    if (!force &&
        _lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!) < _refreshCooldown) {
      return;
    }
    final service = ref.read(discourseServiceProvider);
    final previous = state.value;
    final siteRevision = SiteContext.instance.revision;
    final siteId = SiteContext.instance.current.id;
    final authGeneration = AuthSession().generation;
    final cacheKey = _cacheKey;
    final cacheUserKey = _cacheUserKey;
    try {
      final user = await _loadUser(
        service,
        siteRevision: siteRevision,
        siteId: siteId,
        authGeneration: authGeneration,
      );
      if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return;
      _lastRefreshTime = DateTime.now();
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return;
        _saveCache(
          prefs,
          user,
          cacheKey: cacheKey,
          cacheUserKey: cacheUserKey,
        );
      }
      if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return;
      state = AsyncValue.data(user ?? previous);
    } catch (e, st) {
      if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return;
      // 刷新失败，保留旧数据并标记错误状态（用于离线提示）
      if (previous != null) {
        state = AsyncValue<User?>.error(
          e,
          st,
        ).copyWithPrevious(AsyncValue.data(previous));
      }
    }
  }

  void _refreshUser(
    DiscourseService service,
    User preloadedUser, {
    required int siteRevision,
    required String siteId,
    required int authGeneration,
    required String cacheKey,
    required String cacheUserKey,
  }) {
    Future(() async {
      try {
        final user = await service.getCurrentUser();
        if (user == null) return;
        if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return;
        final merged = _mergeUser(user, preloadedUser);
        final prefs = await SharedPreferences.getInstance();
        if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return;
        _saveCache(
          prefs,
          merged,
          cacheKey: cacheKey,
          cacheUserKey: cacheUserKey,
        );
        if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return;
        state = AsyncValue.data(merged);
      } catch (_) {
        // 后台刷新失败时静默忽略，refreshSilently 会负责设置错误状态
      }
    });
  }

  User _mergeUser(User user, User preloadedUser) {
    return user.copyWith(
      unreadNotifications: preloadedUser.unreadNotifications,
      unreadHighPriorityNotifications:
          preloadedUser.unreadHighPriorityNotifications,
      allUnreadNotificationsCount: preloadedUser.allUnreadNotificationsCount,
      seenNotificationId: preloadedUser.seenNotificationId,
      notificationChannelPosition: preloadedUser.notificationChannelPosition,
      // can_assign 只在 CurrentUserSerializer(预加载/会话数据)里有,
      // /u/username.json 这条公开资料接口不带,live fetch 那份永远是
      // 默认值 false——用预加载兜底,否则第二次刷新就把权限位冲没了。
      canAssign: user.canAssign || preloadedUser.canAssign,
    );
  }

  void _saveCache(
    SharedPreferences prefs,
    User user, {
    String? cacheKey,
    String? cacheUserKey,
  }) {
    prefs.setString(
      cacheKey ?? _cacheKey,
      jsonEncode(user.toCacheJson()),
    );
    prefs.setString(cacheUserKey ?? _cacheUserKey, user.username);
  }

  Future<void> clearCache() async {
    final cacheKey = _cacheKey;
    final cacheUserKey = _cacheUserKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cacheKey);
    await prefs.remove(cacheUserKey);
  }

  bool _isCurrentSnapshot(
    int siteRevision,
    String siteId,
    int authGeneration,
  ) {
    return SiteContext.instance.revision == siteRevision &&
        SiteContext.instance.current.id == siteId &&
        AuthSession().isValid(authGeneration);
  }
}

final currentUserProvider = AsyncNotifierProvider<CurrentUserNotifier, User?>(
  CurrentUserNotifier.new,
);

/// 系统用户头像模板 Provider
/// 用于通知列表中没有 acting_user 时的默认头像
final systemUserAvatarTemplateProvider = FutureProvider<String?>((ref) async {
  return PreloadedDataService().getSystemUserAvatarTemplate();
});

/// 用户统计数据 Provider
class UserSummaryNotifier extends AsyncNotifier<UserSummary?> {
  /// 多论坛支持：缓存按站点隔离。
  static String get _cacheKey =>
      'user_summary_cache_${SiteContext.instance.host}';
  static String get _cacheUserKey =>
      'user_summary_cache_username_${SiteContext.instance.host}';

  @override
  Future<UserSummary?> build() async {
    final service = ref.watch(discourseServiceProvider);
    final siteRevision = SiteContext.instance.revision;
    final siteId = SiteContext.instance.current.id;
    final authGeneration = AuthSession().generation;
    final cacheKey = _cacheKey;
    final cacheUserKey = _cacheUserKey;
    final currentUsername = ref.watch(
      currentUserProvider.select((value) => value.value?.username),
    );
    final username =
        currentUsername ??
        (await ref.watch(currentUserProvider.future))?.username;
    if (username == null) return null;
    if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return null;

    // 先尝试从 SP 读取缓存
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return null;
    final cachedUser = prefs.getString(cacheUserKey);
    // 切换账号时清除旧缓存
    if (cachedUser != null && cachedUser != username) {
      await _clearCache(
        prefs,
        cacheKey: cacheKey,
        cacheUserKey: cacheUserKey,
      );
    }

    if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return null;
    final cached = prefs.getString(cacheKey);
    UserSummary? cachedSummary;
    if (cached != null) {
      try {
        final json = jsonDecode(cached) as Map<String, dynamic>;
        cachedSummary = UserSummary.fromCacheJson(json);
      } catch (_) {
        // 缓存损坏，忽略
      }
    }

    try {
      final summary = await service.getUserSummary(username);
      if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return null;
      _saveCache(
        prefs,
        summary,
        username,
        cacheKey: cacheKey,
        cacheUserKey: cacheUserKey,
      );
      return summary;
    } catch (e) {
      if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return null;
      if (cachedSummary != null) return cachedSummary;
      rethrow;
    }
  }

  Future<void> refresh() async {
    final previous = state.value;
    final siteRevision = SiteContext.instance.revision;
    final siteId = SiteContext.instance.current.id;
    final authGeneration = AuthSession().generation;
    final cacheKey = _cacheKey;
    final cacheUserKey = _cacheUserKey;
    try {
      final service = ref.read(discourseServiceProvider);
      final user = ref.read(currentUserProvider).value;
      if (user == null) return;
      if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return;

      final summary = await service.getUserSummary(
        user.username,
        forceRefresh: true,
      );
      if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return;
      final prefs = await SharedPreferences.getInstance();
      if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return;
      _saveCache(
        prefs,
        summary,
        user.username,
        cacheKey: cacheKey,
        cacheUserKey: cacheUserKey,
      );
      if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return;
      state = AsyncValue.data(summary);
    } catch (e, st) {
      if (!_isCurrentSnapshot(siteRevision, siteId, authGeneration)) return;
      // 刷新失败，保留旧数据并标记错误状态
      if (previous != null) {
        state = AsyncValue<UserSummary?>.error(
          e,
          st,
        ).copyWithPrevious(AsyncValue.data(previous));
      }
    }
  }

  void _saveCache(
    SharedPreferences prefs,
    UserSummary summary,
    String username, {
    String? cacheKey,
    String? cacheUserKey,
  }) {
    prefs.setString(cacheKey ?? _cacheKey, jsonEncode(summary.toCacheJson()));
    prefs.setString(cacheUserKey ?? _cacheUserKey, username);
  }

  Future<void> clearCache() async {
    final cacheKey = _cacheKey;
    final cacheUserKey = _cacheUserKey;
    final prefs = await SharedPreferences.getInstance();
    await _clearCache(
      prefs,
      cacheKey: cacheKey,
      cacheUserKey: cacheUserKey,
    );
  }

  Future<void> _clearCache(
    SharedPreferences prefs, {
    String? cacheKey,
    String? cacheUserKey,
  }) async {
    await prefs.remove(cacheKey ?? _cacheKey);
    await prefs.remove(cacheUserKey ?? _cacheUserKey);
  }

  bool _isCurrentSnapshot(
    int siteRevision,
    String siteId,
    int authGeneration,
  ) {
    return SiteContext.instance.revision == siteRevision &&
        SiteContext.instance.current.id == siteId &&
        AuthSession().isValid(authGeneration);
  }
}

final userSummaryProvider =
    AsyncNotifierProvider<UserSummaryNotifier, UserSummary?>(
      UserSummaryNotifier.new,
    );
