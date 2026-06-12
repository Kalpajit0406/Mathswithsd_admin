
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class AuthStorageService {
  static const _storage = FlutterSecureStorage();

  static Future<void> saveToken(String token) async {
    await _storage.write(key: AppConstants.tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: AppConstants.tokenKey);
  }

  static Future<void> saveIsAdmin(bool isAdmin) async {
    await _storage.write(key: AppConstants.isAdminKey, value: isAdmin.toString());
  }

  static Future<bool> getIsAdmin() async {
    final val = await _storage.read(key: AppConstants.isAdminKey);
    return val == 'true';
  }

  static Future<void> saveUserPhone(String phone) async {
    await _storage.write(key: AppConstants.userPhoneKey, value: phone);
  }

  static Future<String?> getUserPhone() async {
    return await _storage.read(key: AppConstants.userPhoneKey);
  }

  static Future<void> saveUserClass(int classNo) async {
    await _storage.write(key: AppConstants.userClassKey, value: classNo.toString());
  }

  static Future<int> getUserClass() async {
    final val = await _storage.read(key: AppConstants.userClassKey);
    return int.tryParse(val ?? '0') ?? 0;
  }

  static Future<void> saveUserName(String firstName, String lastName) async {
    await _storage.write(key: AppConstants.userFirstNameKey, value: firstName);
    await _storage.write(key: AppConstants.userLastNameKey, value: lastName);
  }

  static Future<String> getUserFirstName() async {
    return await _storage.read(key: AppConstants.userFirstNameKey) ?? '';
  }

  static Future<String> getUserLastName() async {
    return await _storage.read(key: AppConstants.userLastNameKey) ?? '';
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Base URL override (manual developer/device override)
  static Future<void> saveBaseUrlOverride(String url) async {
    await _storage.write(key: AppConstants.baseUrlOverrideKey, value: url);
  }

  static Future<String?> getBaseUrlOverride() async {
    return await _storage.read(key: AppConstants.baseUrlOverrideKey);
  }
}
