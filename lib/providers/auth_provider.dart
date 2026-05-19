import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  AuthStatus _status = AuthStatus.initial;
  AppUser? _user;
  String? _errorMessage;
  bool _isAdmin = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAdmin => _isAdmin;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> tryAutoLogin() async {
    final isLoggedIn = await AuthStorageService.isLoggedIn();
    if (!isLoggedIn) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    final token = await AuthStorageService.getToken();
    final firstName = await AuthStorageService.getUserFirstName();
    final lastName = await AuthStorageService.getUserLastName();
    final phone = await AuthStorageService.getUserPhone();
    final classNo = await AuthStorageService.getUserClass();
    _isAdmin = await AuthStorageService.getIsAdmin();

    _user = AppUser(
      id: '',
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      classNo: classNo,
      token: token!,
    );
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<bool> login(String phone, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.loginWithRetry(phone, password);
      final data = response['data'];
      if (data == null) {
        throw Exception('Invalid response from server');
      }

      final accessToken = data['accessToken'] as String;
      final userData = data['student'] as Map<String, dynamic>;
      final role = userData['role'] as String? ?? '';

      _isAdmin = role.toLowerCase() == 'admin' || role.toLowerCase() == 'teacher';
      _user = AppUser.fromJson(userData, accessToken);

      // Persist securely
      await AuthStorageService.saveToken(accessToken);
      await AuthStorageService.saveIsAdmin(_isAdmin);
      await AuthStorageService.saveUserPhone(_user!.phone ?? phone);
      await AuthStorageService.saveUserClass(_user!.classNo ?? 0);
      await AuthStorageService.saveUserName(_user!.firstName, _user!.lastName);

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Connection error. Please check your internet and try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await AuthStorageService.clearAll();
    _user = null;
    _isAdmin = false;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
