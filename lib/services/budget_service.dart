export 'budget_service.dart' show BudgetService;

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:expensestracker/services/connectivity_service.dart';

class BudgetService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  ConnectivityService? _connectivityService;
  Map<String, dynamic>? _cachedBudget;
  StreamSubscription<DocumentSnapshot>? _budgetSubscription;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _hasPendingWrite = false;
  Map<String, dynamic>? _pendingBudget;

  Map<String, dynamic>? get currentBudget => _cachedBudget;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get hasPendingWrite => _hasPendingWrite;

  void initializeWithConnectivity(ConnectivityService connectivityService) {
    _connectivityService = connectivityService;
    _connectivityService?.addListener(_onConnectivityChanged);
    _setupBudgetListener();
  }

  void _onConnectivityChanged() {
    if (_connectivityService?.isOnline == true && _hasPendingWrite) {
      _processPendingWrites();
    }
  }

  void _setupBudgetListener() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        if (_cachedBudget != null) {
          _subscribeToBudgetUpdates();
        } else {
          _clearCache();
          _subscribeToBudgetUpdates();
        }
      } else {
        _cleanupSubscription();
        _clearCache();
        notifyListeners();
      }
    });
  }

  void _clearCache() {
    _cachedBudget = null;
    _isInitialized = false;
    _isLoading = false;
  }

  void _cleanupSubscription() {
    _budgetSubscription?.cancel();
    _budgetSubscription = null;
  }
  
  Future<void> _processPendingWrites() async {
    if (!_hasPendingWrite || _pendingBudget == null) return;
    
    debugPrint('🔄 Processing pending budget updates');
    try {
      final amount = _pendingBudget!['amount'] as double;
      final autoCopied = _pendingBudget!['autoCopied'] as bool;
      
      await setMonthlyBudget(amount, autoCopied: autoCopied);
      
      _hasPendingWrite = false;
      _pendingBudget = null;
      
      debugPrint('✅ Successfully synced pending budget update');
    } catch (e) {
      debugPrint('❌ Failed to process pending budget update: $e');
    }
  }

  void _subscribeToBudgetUpdates() {
    final user = _auth.currentUser;
    if (user == null) return;

    _cleanupSubscription();

    final monthYear = _getCurrentMonthKey();
    _budgetSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('budgets')
        .doc(monthYear)
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snapshot) {
        _cachedBudget = snapshot.exists ? snapshot.data() : null;
        _isInitialized = true;
        _isLoading = false;
        
        final isFromCache = snapshot.metadata.isFromCache;
        if (isFromCache) {
          debugPrint('ℹ️ Budget data loaded from cache');
        } else {
          debugPrint('✅ Budget data received from server');
          if (_hasPendingWrite && _connectivityService?.isOnline == true) {
            _hasPendingWrite = false;
            _pendingBudget = null;
          }
        }
        
        notifyListeners();
      },
      onError: (e) {
        debugPrint('❌ Error in budget stream: $e');
        _isLoading = false;
        _isInitialized = true;
        notifyListeners();
      },
    );
  }

  String _getCurrentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String _getPreviousMonthKey() {
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1);
    return '${previousMonth.year}-${previousMonth.month.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>?> getCurrentBudget() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    if (_cachedBudget != null) {
      return _cachedBudget;
    }

    if (!_isInitialized) {
      return null;
    }

    return _cachedBudget;
  }

  Future<bool> setMonthlyBudget(double amount, {bool autoCopied = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final monthYear = _getCurrentMonthKey();
      final budgetData = {
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
        'month': DateTime.now().month,
        'year': DateTime.now().year,
        'updatedAt': FieldValue.serverTimestamp(),
        'autoCopied': autoCopied,
      };

      _pendingBudget = {
        ...budgetData,
        'amount': amount,
        'autoCopied': autoCopied,
      };

      _cachedBudget = {...budgetData, 'amount': amount};
      notifyListeners();

      final isOnline = _connectivityService?.isOnline ?? true;
      
      if (!isOnline) {
        debugPrint('⚠️ Device is offline, storing budget update for later sync');
        _hasPendingWrite = true;
        return true;
      }

      try {
        debugPrint('💾 Saving budget to Firestore: $amount');
        final batch = _firestore.batch();
        final docRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('budgets')
            .doc(monthYear);

        batch.set(docRef, budgetData, SetOptions(merge: true));

        await batch.commit().timeout(const Duration(seconds: 10));
        
        _hasPendingWrite = false;
        _pendingBudget = null;
        
        debugPrint('✅ Budget successfully saved to Firestore');
        return true;
      } on FirebaseException catch (e) {
        if (e.code == 'unavailable') {
          debugPrint('⚠️ Firebase unavailable, queuing budget update for later');
          _hasPendingWrite = true;
          return true;
        }
        rethrow;
      } on TimeoutException {
        debugPrint('⌛ Firestore operation timed out, will sync later');
        _hasPendingWrite = true;
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error setting budget: $e');
      
      final isOnline = _connectivityService?.isOnline ?? true;
      if (!isOnline && _cachedBudget != null) {
        _hasPendingWrite = true;
        return true;
      }
      
      await getCurrentBudget();
      return false;
    }
  }

  Future<Map<String, dynamic>?> getPreviousMonthBudget() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final previousMonthKey = _getPreviousMonthKey();
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('budgets')
          .doc(previousMonthKey);

      try {
        final doc = await docRef.get(const GetOptions(source: Source.server));
        return doc.data();
      } on FirebaseException catch (e) {
        if (e.code == 'unavailable') {
          final doc = await docRef.get(const GetOptions(source: Source.cache));
          return doc.data();
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('❌ Error getting previous month budget: $e');
      return null;
    }
  }

  Future<bool> resetBudget() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final monthYear = _getCurrentMonthKey();
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('budgets')
          .doc(monthYear);

      _cachedBudget = null;
      notifyListeners();

      if (_connectivityService?.isOnline != true) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'Cannot reset budget while offline',
        );
      }

      final batch = _firestore.batch();
      batch.delete(docRef);
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('❌ Error resetting budget: $e');
      await getCurrentBudget();
      return false;
    }
  }

  @override
  void dispose() {
    _cleanupSubscription();
    _connectivityService?.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}
