import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CategoryModel {
  final String id;
  final String name;
  final IconData icon;
  final bool isCustom;
  final DateTime? createdAt;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    this.isCustom = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'isCustom': isCustom,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      icon: IconData(
        map['iconCodePoint'] ?? Icons.category.codePoint,
        fontFamily: map['iconFontFamily'],
      ),
      isCustom: map['isCustom'] ?? false,
      createdAt: map['createdAt']?.toDate(),
    );
  }
}

class CategoryService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CategoryModel> _categories = [];
  bool _isLoading = false;

  // Getters
  List<CategoryModel> get categories => List.from(_categories);
  List<CategoryModel> get stockCategories => _categories.where((c) => !c.isCustom).toList();
  List<CategoryModel> get customCategories => _categories.where((c) => c.isCustom).toList();
  bool get isLoading => _isLoading;

  // Stock categories with icons
  static final List<CategoryModel> _stockCategories = [
    CategoryModel(id: 'food', name: 'Food', icon: Icons.restaurant),
    CategoryModel(id: 'transportation', name: 'Transportation', icon: Icons.directions_car),
    CategoryModel(id: 'shopping', name: 'Shopping', icon: Icons.shopping_bag),
    CategoryModel(id: 'entertainment', name: 'Entertainment', icon: Icons.movie),
    CategoryModel(id: 'bills', name: 'Bills', icon: Icons.receipt),
    CategoryModel(id: 'healthcare', name: 'Healthcare', icon: Icons.local_hospital),
    CategoryModel(id: 'education', name: 'Education', icon: Icons.school),
    CategoryModel(id: 'travel', name: 'Travel', icon: Icons.flight),
    CategoryModel(id: 'groceries', name: 'Groceries', icon: Icons.local_grocery_store),
    CategoryModel(id: 'utilities', name: 'Utilities', icon: Icons.electrical_services),
    CategoryModel(id: 'insurance', name: 'Insurance', icon: Icons.security),
    CategoryModel(id: 'fitness', name: 'Fitness', icon: Icons.fitness_center),
    CategoryModel(id: 'beauty', name: 'Beauty', icon: Icons.face),
    CategoryModel(id: 'gifts', name: 'Gifts', icon: Icons.card_giftcard),
    CategoryModel(id: 'subscriptions', name: 'Subscriptions', icon: Icons.subscriptions),
    CategoryModel(id: 'other', name: 'Other', icon: Icons.category),
  ];

  // Available icons for custom categories
  static final List<IconData> availableIcons = [
    Icons.home, Icons.work, Icons.pets, Icons.sports_soccer, Icons.music_note,
    Icons.book, Icons.camera_alt, Icons.coffee, Icons.local_gas_station,
    Icons.phone, Icons.computer, Icons.games, Icons.beach_access,
    Icons.child_care, Icons.elderly, Icons.volunteer_activism,
    Icons.savings, Icons.account_balance, Icons.credit_card,
    Icons.local_atm, Icons.payment, Icons.monetization_on,
    Icons.trending_up, Icons.trending_down, Icons.pie_chart,
    Icons.bar_chart, Icons.show_chart, Icons.assessment,
  ];

  CategoryService() {
    _initializeCategories();
  }

  Future<void> _initializeCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Start with stock categories
      _categories = List.from(_stockCategories);

      // Load custom categories from local storage first (instant)
      await _loadFromLocalStorage();

      // Notify listeners immediately with local data
      _isLoading = false;
      notifyListeners();

      // Try to sync with Firestore in background (don't wait)
      _syncFromFirestore().catchError((e) {
        debugPrint('Background Firestore sync failed: $e');
        // Don't affect UI - local storage is sufficient
      });
    } catch (e) {
      debugPrint('Error initializing categories: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _syncFromFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .get()
          .timeout(const Duration(seconds: 5));

      final firestoreCategories = querySnapshot.docs
          .map((doc) => CategoryModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      // Merge with local categories (local takes precedence)
      for (final firestoreCategory in firestoreCategories) {
        if (!_categories.any((c) => c.id == firestoreCategory.id)) {
          _categories.add(firestoreCategory);
        }
      }

      // Save merged data to local storage
      await _saveToLocalStorage();
      notifyListeners();

      debugPrint('Successfully synced ${firestoreCategories.length} categories from Firestore');
    } catch (e) {
      debugPrint('Failed to sync from Firestore: $e');
      // Don't rethrow - local storage is sufficient
    }
  }

  Future<void> addCustomCategory(String name, IconData icon) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Validate category name
    if (name.trim().isEmpty) {
      throw Exception('Category name cannot be empty');
    }

    // Check if category already exists
    if (_categories.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
      throw Exception('Category already exists');
    }

    // Generate a unique ID for the category
    final categoryId = 'custom_${DateTime.now().millisecondsSinceEpoch}_${name.trim().toLowerCase().replaceAll(' ', '_')}';

    final newCategory = CategoryModel(
      id: categoryId,
      name: name.trim(),
      icon: icon,
      isCustom: true,
      createdAt: DateTime.now(),
    );

    // Add to local list immediately - this is the primary storage now
    _categories.add(newCategory);
    notifyListeners();

    // Save to local storage for persistence
    await _saveToLocalStorage();

    // Try to sync with Firestore in the background (fire and forget)
    _syncToFirestore(newCategory).catchError((e) {
      debugPrint('Background Firestore sync failed: $e');
      // Don't throw error - local storage is sufficient
    });
  }

  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customCategories = _categories.where((c) => c.isCustom).toList();
      final categoriesJson = customCategories.map((c) => {
        'id': c.id,
        'name': c.name,
        'iconCodePoint': c.icon.codePoint,
        'iconFontFamily': c.icon.fontFamily,
        'isCustom': c.isCustom,
        'createdAt': c.createdAt?.millisecondsSinceEpoch,
      }).toList();

      await prefs.setString('custom_categories', json.encode(categoriesJson));
    } catch (e) {
      debugPrint('Error saving to local storage: $e');
    }
  }

  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoriesString = prefs.getString('custom_categories');

      if (categoriesString != null) {
        final categoriesJson = json.decode(categoriesString) as List;
        final customCategories = categoriesJson.map((json) => CategoryModel(
          id: json['id'],
          name: json['name'],
          icon: IconData(
            json['iconCodePoint'],
            fontFamily: json['iconFontFamily'],
          ),
          isCustom: json['isCustom'] ?? true,
          createdAt: json['createdAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
              : null,
        )).toList();

        _categories.addAll(customCategories);
      }
    } catch (e) {
      debugPrint('Error loading from local storage: $e');
    }
  }

  Future<void> _syncToFirestore(CategoryModel category) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final categoryData = {
        'name': category.name,
        'iconCodePoint': category.icon.codePoint,
        'iconFontFamily': category.icon.fontFamily,
        'isCustom': category.isCustom,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(category.id)
          .set(categoryData)
          .timeout(const Duration(seconds: 5));

      debugPrint('Successfully synced category to Firestore: ${category.name}');
    } catch (e) {
      debugPrint('Failed to sync category to Firestore: $e');
      // Don't rethrow - local storage is sufficient
    }
  }

  Future<void> updateCustomCategory(String categoryId, String name, IconData icon) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Validate category name
    if (name.trim().isEmpty) {
      throw Exception('Category name cannot be empty');
    }

    // Check if category exists and is custom
    final categoryIndex = _categories.indexWhere((c) => c.id == categoryId);
    if (categoryIndex == -1) {
      throw Exception('Category not found');
    }

    final category = _categories[categoryIndex];
    if (!category.isCustom) {
      throw Exception('Cannot edit stock categories');
    }

    // Check if new name conflicts with existing categories (excluding current)
    if (_categories.any((c) => c.id != categoryId && c.name.toLowerCase() == name.toLowerCase())) {
      throw Exception('Category name already exists');
    }

    // Update local list immediately
    _categories[categoryIndex] = CategoryModel(
      id: categoryId,
      name: name.trim(),
      icon: icon,
      isCustom: true,
      createdAt: category.createdAt,
    );

    notifyListeners();

    // Save to local storage
    await _saveToLocalStorage();

    // Try to sync with Firestore in background
    _syncUpdateToFirestore(categoryId, name.trim(), icon).catchError((e) {
      debugPrint('Background Firestore update failed: $e');
      // Don't throw error - local storage is sufficient
    });
  }

  Future<void> _syncUpdateToFirestore(String categoryId, String name, IconData icon) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(categoryId)
          .update({
        'name': name,
        'iconCodePoint': icon.codePoint,
        'iconFontFamily': icon.fontFamily,
      }).timeout(const Duration(seconds: 5));

      debugPrint('Successfully updated category in Firestore: $name');
    } catch (e) {
      debugPrint('Failed to update category in Firestore: $e');
      // Don't rethrow - local storage is sufficient
    }
  }

  CategoryModel? getCategoryByName(String name) {
    try {
      return _categories.firstWhere((c) => c.name == name);
    } catch (e) {
      return null;
    }
  }

  IconData getCategoryIcon(String categoryName) {
    final category = getCategoryByName(categoryName);
    return category?.icon ?? Icons.category;
  }

  List<String> getCategoryNames() {
    return _categories.map((c) => c.name).toList();
  }

  Future<void> deleteCustomCategory(String categoryId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Check if category exists and is custom
    final category = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => throw Exception('Category not found'),
    );

    if (!category.isCustom) {
      throw Exception('Cannot delete stock categories');
    }

    // Remove from local list immediately
    _categories.removeWhere((c) => c.id == categoryId);
    notifyListeners();

    // Save to local storage
    await _saveToLocalStorage();

    // Try to sync deletion with Firestore in background
    _syncDeleteToFirestore(categoryId, category.name).catchError((e) {
      debugPrint('Background Firestore deletion failed: $e');
      // Don't throw error - local storage is sufficient
    });
  }

  Future<void> _syncDeleteToFirestore(String categoryId, String categoryName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check if category is being used in transactions
      final transactionQuery = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .where('category', isEqualTo: categoryName)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      if (transactionQuery.docs.isNotEmpty) {
        // If category is in use, add it back to local storage
        debugPrint('Category is in use, cannot delete from Firestore');
        return;
      }

      // Delete from Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(categoryId)
          .delete()
          .timeout(const Duration(seconds: 5));

      debugPrint('Successfully deleted category from Firestore: $categoryName');
    } catch (e) {
      debugPrint('Failed to delete category from Firestore: $e');
      // Don't rethrow - local storage is sufficient
    }
  }

  Future<void> refreshCategories() async {
    await _initializeCategories();
  }
}
