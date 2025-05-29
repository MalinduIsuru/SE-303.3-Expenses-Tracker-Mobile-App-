export 'connectivity_service.dart' show ConnectivityService;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  StreamSubscription? _connectivitySubscription;

  ConnectivityService() {
    _initConnectivityMonitoring();
  }

  bool get isOnline => _isOnline;

  Future<void> _initConnectivityMonitoring() async {
    await _checkConnectivity();
    _setupConnectivityListener();
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('❌ Connectivity check failed: $e');
      _setOnlineStatus(false);
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    _setOnlineStatus(result != ConnectivityResult.none);
  }

  void _setOnlineStatus(bool status) {
    if (_isOnline != status) {
      _isOnline = status;
      debugPrint('🌐 Connection status: ${_isOnline ? "ONLINE" : "OFFLINE"}');
      notifyListeners();
    }
  }

  Future<bool> forceReconnect() async {
    debugPrint('🔄 Forcing reconnection check...');
    await _checkConnectivity();
    return _isOnline;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
