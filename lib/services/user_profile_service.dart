import 'dart:io';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  Map<String, dynamic>? _cachedProfile;
  
  UserProfileService() : _firestore = FirebaseFirestore.instance {
    // Enable Firestore offline persistence
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  Stream<Map<String, dynamic>?> get userProfileStream {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) {
            final data = doc.data();
            if (data != null) {
              _saveToLocalCache(data); // Cache the data
              _cachedProfile = data;
            }
            return data;
          })
          .handleError((error) {
            debugPrint('Error in user profile stream: $error');
            return _cachedProfile; // Return cached data on error
          });
    }
    return Stream.value(null);
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Try to get from Firestore
        try {
          final doc = await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

          final data = doc.data();
          if (data != null) {
            _saveToLocalCache(data);
            _cachedProfile = data;
            return data;
          }
        } catch (e) {
          debugPrint('Error fetching from Firestore: $e');
          // Fall through to use cache
        }

        // If Firestore fails, try to get from cache
        return await _getFromLocalCache() ?? _cachedProfile;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      rethrow;
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      debugPrint('Error sending verification email: $e');
      rethrow;
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    return await updateUserProfile(
      displayName: profileData['displayName'],
      email: profileData['email'],
      currency: profileData['currency'],
      notificationsEnabled: profileData['notificationsEnabled'],
    );
  }

  Future<bool> updateUserProfile({
    String? displayName,
    String? email,
    String? currency,
    bool? notificationsEnabled,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        Map<String, dynamic> updateData = {
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Update display name if provided
        if (displayName != null && displayName != user.displayName) {
          await user.updateDisplayName(displayName);
          updateData['displayName'] = displayName;
        }

        // Update currency preference
        if (currency != null) {
          updateData['currency'] = currency;
        }

        // Update notification preference
        if (notificationsEnabled != null) {
          updateData['notificationsEnabled'] = notificationsEnabled;
        }

        // Update Firestore with new data
        await _firestore.collection('users').doc(user.uid).set(
          updateData,
          SetOptions(merge: true),
        );

        // Handle email update
        if (email != null && email != user.email) {
          // First update Firestore with pending email change
          await _firestore.collection('users').doc(user.uid).set({
            'pendingEmail': email,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Send verification email to new address
          await user.verifyBeforeUpdateEmail(email);

          // Throw a specific error to handle in UI
          throw FirebaseAuthException(
            code: 'verification-needed',
            message: 'Please check your new email address for verification instructions.',
          );
        }

        notifyListeners();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error updating user profile: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }

  Future<String?> uploadProfileImage(dynamic imageData) async {
    try {
      debugPrint('Starting profile picture upload...');
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('No user logged in');
        throw Exception('User not logged in');
      }

      // Validate image data size
      int imageSize = 0;
      if (kIsWeb && imageData is Uint8List) {
        imageSize = imageData.length;
      } else if (!kIsWeb && imageData is File) {
        imageSize = await imageData.length();
      }

      debugPrint('Image size: $imageSize bytes');
      if (imageSize > 5 * 1024 * 1024) { // 5MB limit
        throw Exception('Image size too large. Please select an image smaller than 5MB.');
      }

      if (imageSize == 0) {
        throw Exception('Invalid image file. Please try selecting a different image.');
      }

      // Generate a unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_$timestamp.jpg';
      final path = 'profile_pictures/${user.uid}/$fileName';
      debugPrint('Upload path: $path');

      // Create reference
      final ref = _storage.ref().child(path);
      debugPrint('Storage reference created');

      // Prepare metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': user.uid,
          'timestamp': timestamp.toString(),
          'platform': kIsWeb ? 'web' : 'mobile',
        },
      );
      debugPrint('Metadata prepared');

      // Start upload based on platform
      late final UploadTask uploadTask;
      if (kIsWeb) {
        debugPrint('Starting web upload...');
        if (imageData is! Uint8List) {
          throw Exception('Invalid image data for web platform');
        }
        uploadTask = ref.putData(imageData, metadata);
      } else {
        debugPrint('Starting mobile upload...');
        if (imageData is! File) {
          throw Exception('Invalid image data for mobile platform');
        }
        uploadTask = ref.putFile(imageData, metadata);
      }

      // Monitor upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          debugPrint('Upload progress: ${progress.toStringAsFixed(2)}%');
          debugPrint('Bytes transferred: ${snapshot.bytesTransferred}');
          debugPrint('Total bytes: ${snapshot.totalBytes}');
          debugPrint('State: ${snapshot.state}');
        },
        onError: (e) {
          debugPrint('Upload stream error: $e');
        },
        cancelOnError: false,
      );

      // Wait for upload completion with timeout
      debugPrint('Waiting for upload to complete...');
      final snapshot = await uploadTask.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          debugPrint('Upload timed out after 2 minutes');
          uploadTask.cancel();
          throw Exception('Upload timed out. Please check your internet connection and try again.');
        },
      );

      debugPrint('Upload task completed with state: ${snapshot.state}');

      if (snapshot.state != TaskState.success) {
        String errorMessage = 'Upload failed';
        switch (snapshot.state) {
          case TaskState.canceled:
            errorMessage = 'Upload was canceled';
            break;
          case TaskState.error:
            errorMessage = 'Upload failed due to an error';
            break;
          case TaskState.paused:
            errorMessage = 'Upload was paused';
            break;
          default:
            errorMessage = 'Upload did not complete successfully';
        }
        throw Exception(errorMessage);
      }

      // Get download URL
      debugPrint('Getting download URL...');
      final downloadUrl = await snapshot.ref.getDownloadURL().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Failed to get download URL. Please try again.');
        },
      );
      debugPrint('Got download URL: $downloadUrl');

      // Update Firestore
      debugPrint('Updating Firestore...');
      await _firestore.collection('users').doc(user.uid).update({
        'profilePictureUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Failed to update profile. Please try again.');
        },
      );

      debugPrint('Profile picture upload completed successfully');
      notifyListeners();
      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint('Firebase error uploading profile picture: ${e.code} - ${e.message}');
      String userMessage = 'Upload failed';
      switch (e.code) {
        case 'storage/unauthorized':
          userMessage = 'You do not have permission to upload images. Please try logging out and back in.';
          break;
        case 'storage/canceled':
          userMessage = 'Upload was canceled';
          break;
        case 'storage/unknown':
          userMessage = 'An unknown error occurred. Please try again.';
          break;
        case 'storage/object-not-found':
          userMessage = 'File not found. Please try selecting the image again.';
          break;
        case 'storage/bucket-not-found':
          userMessage = 'Storage bucket not found. Please contact support.';
          break;
        case 'storage/project-not-found':
          userMessage = 'Project not found. Please contact support.';
          break;
        case 'storage/quota-exceeded':
          userMessage = 'Storage quota exceeded. Please try again later.';
          break;
        case 'storage/unauthenticated':
          userMessage = 'Authentication required. Please log in again.';
          break;
        case 'storage/retry-limit-exceeded':
          userMessage = 'Too many attempts. Please try again later.';
          break;
        case 'storage/invalid-checksum':
          userMessage = 'File corrupted during upload. Please try again.';
          break;
        default:
          userMessage = 'Upload failed: ${e.message ?? 'Unknown error'}';
      }
      throw Exception(userMessage);
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      if (e.toString().contains('timeout') || e.toString().contains('timed out')) {
        throw Exception('Upload timed out. Please check your internet connection and try again.');
      }
      rethrow;
    }
  }

  // Currency management methods
  static const List<Map<String, String>> supportedCurrencies = [
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£'},
    {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
    {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'C\$'},
    {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$'},
    {'code': 'CHF', 'name': 'Swiss Franc', 'symbol': 'CHF'},
    {'code': 'CNY', 'name': 'Chinese Yuan', 'symbol': '¥'},
    {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹'},
    {'code': 'KRW', 'name': 'South Korean Won', 'symbol': '₩'},
  ];

  Future<void> updateCurrency(String currencyCode) async {
    try {
      await updateUserProfile(currency: currencyCode);
      // Notify listeners that currency has changed
      // This will trigger UI updates across the app
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating currency: $e');
      rethrow;
    }
  }

  Future<void> updateNotificationSettings(bool enabled) async {
    try {
      await updateUserProfile(notificationsEnabled: enabled);
    } catch (e) {
      debugPrint('Error updating notification settings: $e');
      rethrow;
    }
  }

  String getUserCurrency(Map<String, dynamic>? userData) {
    return userData?['currency'] ?? 'USD';
  }

  bool getNotificationSettings(Map<String, dynamic>? userData) {
    return userData?['notificationsEnabled'] ?? true;
  }

  String getCurrencySymbol(String currencyCode) {
    final currency = supportedCurrencies.firstWhere(
      (c) => c['code'] == currencyCode,
      orElse: () => {'symbol': '\$'},
    );
    return currency['symbol'] ?? '\$';
  }

  Future<void> _saveToLocalCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile_cache', json.encode(data));
    } catch (e) {
      debugPrint('Error saving to local cache: $e');
    }
  }

  Future<Map<String, dynamic>?> _getFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('user_profile_cache');
      if (cached != null) {
        return json.decode(cached) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error reading from local cache: $e');
    }
    return null;
  }
}