import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  String? _userRole;
  String? _userId;
  String? _userName;
  late ApiService _apiService;
  final _storage = const FlutterSecureStorage();

  AuthStatus get status => _status;
  String? get userRole => _userRole;
  String? get userName => _userName;
  String? get userId => _userId;
  ApiService get api => _apiService;

  AuthProvider() {
    _apiService = ApiService(onUnauthenticated: logout);
    _checkSession();
  }

  Future<void> _checkSession() async {
    final token = await _storage.read(key: 'token');
    if (token != null) {
      _userRole = await _storage.read(key: 'userRole');
      _userId = await _storage.read(key: 'userId');
      _userName = await _storage.read(key: 'userName') ?? "User";

      // Verify token is still valid with the server
      final verified = await _apiService.verifyToken();
      if (verified != null) {
        _status = AuthStatus.authenticated;
      } else {
        // Token expired, clear session
        await _storage.deleteAll();
        _status = AuthStatus.unauthenticated;
        _userRole = null;
        _userId = null;
        _userName = null;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password, String type) async {
    try {
      final data = await _apiService.login(email, password, type);

      _status = AuthStatus.authenticated;
      _userRole = type;

      final userObj = data['user'];
      if (userObj != null) {
        _userId = userObj['_id'] ?? userObj['id'];
        _userName = userObj['name'];
      }

      await _storage.write(key: 'token', value: data['token']);
      await _storage.write(key: 'userRole', value: type);
      if (_userId != null) await _storage.write(key: 'userId', value: _userId!);
      if (_userName != null) {
        await _storage.write(key: 'userName', value: _userName!);
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Login failed: $e");
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _status = AuthStatus.unauthenticated;
    _userRole = null;
    _userId = null;
    _userName = null;
    notifyListeners();
  }
}