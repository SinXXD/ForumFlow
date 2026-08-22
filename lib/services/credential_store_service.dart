import 'storage/resilient_secure_storage.dart';
import '../config/site_context.dart';

/// 登录凭证安全存储服务（单例）
///
/// 多论坛支持：存储 key 带站点前缀，每个论坛独立记住凭证。
class CredentialStoreService {
  CredentialStoreService._();
  static final CredentialStoreService _instance = CredentialStoreService._();
  factory CredentialStoreService() => _instance;

  static String get _keyUsername =>
      'login_credential_username_${SiteContext.instance.host}';
  static String get _keyPassword =>
      'login_credential_password_${SiteContext.instance.host}';

  final _storage = ResilientSecureStorage();

  /// 保存凭证
  Future<void> save(String username, String password) async {
    final usernameKey = _keyUsername;
    final passwordKey = _keyPassword;
    await _storage.write(key: usernameKey, value: username);
    await _storage.write(key: passwordKey, value: password);
  }

  /// 读取凭证
  Future<({String? username, String? password})> load() async {
    final usernameKey = _keyUsername;
    final passwordKey = _keyPassword;
    final username = await _storage.read(key: usernameKey);
    final password = await _storage.read(key: passwordKey);
    return (username: username, password: password);
  }

  /// 清除凭证
  Future<void> clear() async {
    final usernameKey = _keyUsername;
    final passwordKey = _keyPassword;
    await _storage.delete(key: usernameKey);
    await _storage.delete(key: passwordKey);
  }

  /// 是否已保存凭证
  Future<bool> hasCredentials() async {
    final usernameKey = _keyUsername;
    final passwordKey = _keyPassword;
    final username = await _storage.read(key: usernameKey);
    final password = await _storage.read(key: passwordKey);
    return username != null &&
        password != null &&
        username.isNotEmpty &&
        password.isNotEmpty;
  }
}
