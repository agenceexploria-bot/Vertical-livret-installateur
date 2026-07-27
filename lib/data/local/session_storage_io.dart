import 'package:shared_preferences/shared_preferences.dart';
import 'session_storage.dart';

class PlatformSessionStorage implements SessionStorage {
  @override
  Future<String?> getString(String key) async => (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> setString(String key, String value) async => (await SharedPreferences.getInstance()).setString(key, value);

  @override
  Future<void> remove(String key) async => (await SharedPreferences.getInstance()).remove(key);
}
