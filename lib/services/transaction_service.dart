export 'transaction_service.dart' show TransactionService;

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:expensestracker/services/connectivity_service.dart';

class TransactionService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  ConnectivityService? _connectivityService;
  Map<String, dynamic> _cachedTransactions = {};
  StreamSubscription? _transactionsSubscription;
  bool _isInitialized = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _pendingTransactions = [];

  Map<String, dynamic> get cachedTransactions => _cachedTransactions;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get hasPendingTransactions => _pendingTransactions.isNotEmpty;

  /// Returns the total amount spent in the current month
  double get cachedMonthlyTotal {
    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';    return _cachedTransactions.values
        .where((transaction) => transaction['monthYear'] == currentMonthKey)
        .fold(0.0, (total, transaction) => total + (transaction['amount'] as num));
  }

  /// Returns a map of category IDs to their total amounts for the current month
  Map<String, double> get cachedCategoryBreakdown {
    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final breakdown = <String, double>{};

    for (final transaction in _cachedTransactions.values) {
      if (transaction['monthYear'] == currentMonthKey) {
        final categoryId = transaction['category'] as String;
        final amount = transaction['amount'] as num;
        breakdown[categoryId] = (breakdown[categoryId] ?? 0.0) + amount;
      }
    }

    return breakdown;
  }

  void initializeWithConnectivity(ConnectivityService connectivityService) {
    _connectivityService = connectivityService;
    _connectivityService?.addListener(_onConnectivityChanged);
    _setupTransactionsListener();
  }

  void _onConnectivityChanged() {
    if (_connectivityService?.isOnline == true && _pendingTransactions.isNotEmpty) {
      _processPendingTransactions();
    }
  }

  void _setupTransactionsListener() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _subscribeToDatabaseUpdates();
      } else {
        _cleanupSubscription();
        _clearCache();
      }
    });
  }

  void _clearCache() {
    _cachedTransactions = {};
    _isInitialized = false;
    _isLoading = false;
    notifyListeners();
  }

  void _cleanupSubscription() {
    _transactionsSubscription?.cancel();
    _transactionsSubscription = null;
  }

  void _subscribeToDatabaseUpdates() {
    final user = _auth.currentUser;
    if (user == null) return;

    _cleanupSubscription();

    _transactionsSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snapshot) {
        final transactions = <String, dynamic>{};
        for (var doc in snapshot.docs) {
          transactions[doc.id] = doc.data();
        }
        _cachedTransactions = transactions;
        _isInitialized = true;
        _isLoading = false;

        final isFromCache = snapshot.metadata.isFromCache;
        if (isFromCache) {
          debugPrint('ℹ️ Transaction data loaded from cache');
        } else {
          debugPrint('✅ Transaction data received from server');
        }

        notifyListeners();
      },
      onError: (error) {
        debugPrint('❌ Error in transactions stream: $error');
        _isLoading = false;
        _isInitialized = true;
        notifyListeners();
      },
    );
  }

  Future<void> _processPendingTransactions() async {
    if (_pendingTransactions.isEmpty) return;

    debugPrint('🔄 Processing ${_pendingTransactions.length} pending transactions');

    final failedTransactions = <Map<String, dynamic>>[];

    for (final transaction in _pendingTransactions) {
      try {
        await _saveTransactionToFirestore(transaction);
      } catch (e) {
        debugPrint('❌ Failed to sync transaction: $e');
        failedTransactions.add(transaction);
      }
    }

    _pendingTransactions = failedTransactions;
    if (failedTransactions.isEmpty) {
      debugPrint('✅ All pending transactions synced successfully');
    } else {
      debugPrint('⚠️ ${failedTransactions.length} transactions failed to sync');
    }
  }

  Future<void> _saveTransactionToFirestore(Map<String, dynamic> transaction) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .doc(transaction['id'] as String);

    await docRef.set(transaction, SetOptions(merge: true));
  }

  Future<bool> addTransaction(Map<String, dynamic> transaction) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final isOnline = _connectivityService?.isOnline ?? true;

      // Store in cache immediately
      _cachedTransactions[transaction['id']] = transaction;
      notifyListeners();

      if (!isOnline) {
        debugPrint('⚠️ Device is offline, storing transaction for later sync');
        _pendingTransactions.add(transaction);
        return true;
      }

      try {
        await _saveTransactionToFirestore(transaction);
        debugPrint('✅ Transaction saved successfully');
        return true;
      } on FirebaseException catch (e) {
        if (e.code == 'unavailable') {
          debugPrint('⚠️ Firebase unavailable, queuing transaction for later');
          _pendingTransactions.add(transaction);
          return true;
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('❌ Error adding transaction: $e');

      // If offline, keep in pending
      final isOnline = _connectivityService?.isOnline ?? true;
      if (!isOnline) {
        _pendingTransactions.add(transaction);
        return true;
      }

      // Remove from cache if we couldn't save while online
      _cachedTransactions.remove(transaction['id']);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTransaction(String id, Map<String, dynamic> updates) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final currentData = _cachedTransactions[id];
      if (currentData == null) return false;

      final updatedTransaction = <String, dynamic>{
        ...Map<String, dynamic>.from(currentData),
        ...updates
      };

      // Update cache immediately
      _cachedTransactions[id] = updatedTransaction;
      notifyListeners();

      final isOnline = _connectivityService?.isOnline ?? true;

      if (!isOnline) {
        debugPrint('⚠️ Device is offline, storing transaction update for later sync');
        _pendingTransactions.add(updatedTransaction);
        return true;
      }

      try {
        await _saveTransactionToFirestore(updatedTransaction);
        debugPrint('✅ Transaction updated successfully');
        return true;
      } on FirebaseException catch (e) {
        if (e.code == 'unavailable') {
          _pendingTransactions.add(updatedTransaction);
          return true;
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('❌ Error updating transaction: $e');
      return false;
    }
  }

  Future<bool> deleteTransaction(String id) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      if (_connectivityService?.isOnline != true) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'Cannot delete transaction while offline',
        );
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(id)
          .delete();

      _cachedTransactions.remove(id);
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('❌ Error deleting transaction: $e');
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
