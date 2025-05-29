import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;

  AuthService() {
    _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get user => _user;

  bool _isValidEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Sign in with email and password
  Future<String?> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found for that email';
        case 'wrong-password':
          return 'Wrong password provided';
        case 'invalid-email':
          return 'Please enter a valid email address';
        case 'user-disabled':
          return 'This account has been disabled';
        default:
          return e.message ?? 'An error occurred';
      }
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  // Register with email and password
  Future<String?> registerWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;

      if (user != null) {
        // Create user profile document
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'displayName': email.split('@')[0], // Default display name
          'currency': 'USD', // Default currency
          'notificationsEnabled': true, // Default notification setting
        });
      }
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          return 'The password provided is too weak';
        case 'email-already-in-use':
          return 'An account already exists for that email';
        case 'invalid-email':
          return 'Please enter a valid email address';
        default:
          return e.message ?? 'An error occurred';
      }
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Password reset
  Future<void> resetPassword(String? email) async {
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'Please enter your email address',
      );
    }

    if (!_isValidEmail(email)) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Please enter a valid email address',
      );
    }

    try {
      debugPrint('Sending password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('Password reset email sent successfully');
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error sending reset email: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error sending reset email: $e');
      throw FirebaseAuthException(
        code: 'reset-failed',
        message: 'Failed to send password reset email',
      );
    }
  }
}