import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'forum_site.dart';
import 'site_customization.dart';
import 'sites/linuxdo.dart';

/// 多论坛站点上下文（全局单例）
///
/// 职责：
/// - 维护「预置 + 手动添加」的论坛列表与当前站点
/// - 作为 [AppConstants.baseUrl] / [AppConstants.siteCustomization]
///   的动态取值来源（多论坛切换的核心）
/// - 持久化到 shared_preferences
///
/// 注意：本类被 constants.dart 引用，禁止反向 import constants.dart。
/// 切换时的副作用（会话代推进、cookie 重载、preload）由
/// ForumSwitchService 负责，本类只管状态与持久化。
class SiteContext extends ChangeNotifier {
  SiteContext._();

  static final SiteContext instance = SiteContext._();

  static const String _prefsSitesKey = 'forum_sites';
  static const String _prefsCurrentKey = 'current_forum_id';

  /// 预置站点（代码内置，UI 不可删除）
  static const List<ForumSite> presetSites = [
    ForumSite(
      id: 'linux.do',
      name: 'LinuxDO',
      baseUrl: 'https://linux.do',
      isPreset: true,
      hcaptchaSiteKey: 'a776b4ac-8c4c-441e-986a-c6ee9ed8cf08',
    ),
    ForumSite(
      id: 'idcflare.com',
      name: 'IDCFlare',
      baseUrl: 'https://idcflare.com',
      isPreset: true,
    ),
    ForumSite(
      id: 'www.nodeloc.com',
      name: 'NodeLoc',
      baseUrl: 'https://www.nodeloc.com',
      isPreset: true,
    ),
    ForumSite(
      id: 'meta.appinn.net',
      name: '小众软件',
      baseUrl: 'https://meta.appinn.net',
      isPreset: true,
    ),
  ];

  SharedPreferences? _prefs;
  ForumSite _current = presetSites.first;
  List<ForumSite> _customSites = [];
  int _revision = 0;

  /// 全部站点（预置 + 手动，按 id 去重，保持添加顺序）
  List<ForumSite> get allSites {
    final map = <String, ForumSite>{};
    for (final s in presetSites) {
      map[s.id] = s;
    }
    for (final s in _customSites) {
      // 预置站点是代码定义的稳定入口，用户重复添加同一 host 时不应
      // 覆盖它的名称、baseUrl 或 isPreset 标记。
      map.putIfAbsent(s.id, () => s);
    }
    return map.values.toList();
  }

  /// 当前站点
  ForumSite get current => _current;

  /// 当前站点上下文 revision。A→B→A 也会得到不同 revision，
  /// 用于让延迟异步任务识别自己是否属于当前这次切换。
  int get revision => _revision;

  /// 当前站点 baseUrl（AppConstants.baseUrl 的动态来源）
  String get baseUrl => _current.baseUrl;

  /// 当前站点 host
  String get host => _current.host;

  /// 当前站点定制配置（不同站点可有不同外观/链接策略）
  SiteCustomization get customization {
    switch (_current.id) {
      case 'linux.do':
        return linuxdoCustomization;
      default:
        return const SiteCustomization();
    }
  }

  /// 启动时初始化（须先于任何 baseUrl 读取，见 main.dart）
  Future<void> initialize(SharedPreferences prefs) async {
    _prefs = prefs;
    // 手动添加的站点列表
    final raw = prefs.getString(_prefsSitesKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _customSites = decoded
              .whereType<Map<String, dynamic>>()
              .map(ForumSite.fromJson)
              .where((s) => s.id.isNotEmpty && s.baseUrl.isNotEmpty)
              .toList();
        }
      } catch (e) {
        debugPrint('[SiteContext] 论坛列表解析失败，重置: $e');
        _customSites = [];
      }
    }
    // 当前站点
    final currentId = prefs.getString(_prefsCurrentKey);
    if (currentId != null && currentId.isNotEmpty) {
      final match = allSites.where((s) => s.id == currentId);
      if (match.isNotEmpty) {
        _current = match.first;
      }
    }
    debugPrint('[SiteContext] initialized, current=${_current.id}, '
        'sites=${allSites.map((s) => s.id).join(',')}');
  }

  /// 设置当前站点并持久化（切换流程由 ForumSwitchService 编排）
  Future<void> setCurrent(ForumSite site) async {
    if (site.id == _current.id) return;
    _current = site;
    _revision++;
    notifyListeners();
    await _prefs?.setString(_prefsCurrentKey, site.id);
  }

  /// 添加手动站点并持久化（已存在则覆盖）
  Future<void> addSite(ForumSite site) async {
    if (presetSites.any((preset) => preset.id == site.id)) {
      _customSites.removeWhere((s) => s.id == site.id);
      notifyListeners();
      await _saveSites();
      return;
    }
    _customSites.removeWhere((s) => s.id == site.id);
    _customSites.add(site);
    if (site.id == _current.id) {
      _current = site;
    }
    notifyListeners();
    await _saveSites();
  }

  /// 删除手动站点。预置站点或当前站点不可删除。
  Future<bool> removeSite(String id) async {
    if (presetSites.any((site) => site.id == id)) return false;
    if (id == _current.id) return false;
    final before = _customSites.length;
    _customSites.removeWhere((s) => s.id == id);
    if (_customSites.length == before) return false;
    notifyListeners();
    await _saveSites();
    return true;
  }

  /// 按 id 查找站点
  ForumSite? siteById(String id) {
    for (final s in allSites) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> _saveSites() async {
    await _prefs?.setString(
      _prefsSitesKey,
      jsonEncode(_customSites.map((s) => s.toJson()).toList()),
    );
  }
}
