import 'package:web/web.dart' as web;
import 'session_storage.dart';

class PlatformSessionStorage implements SessionStorage {
  @override
  Future<String?> getString(String key) async => web.window.sessionStorage.getItem(key);

  @override
  Future<void> setString(String key, String value) async => web.window.sessionStorage.setItem(key, value);

  @override
  Future<void> remove(String key) async => web.window.sessionStorage.removeItem(key);
}
