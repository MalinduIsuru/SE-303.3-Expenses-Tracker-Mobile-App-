import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/auth_service.dart';
import 'services/user_profile_service.dart';
import 'services/budget_service.dart';
import 'services/currency_service.dart';
import 'services/transaction_service.dart';
import 'services/category_service.dart';
import 'services/connectivity_service.dart';
import 'screens/wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase with appropriate options
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyDdWpLkJ4Zg1UoAj2pVl3ftjBzI2zqaZYA',
          appId: '1:709452424896:web:706710396b595b527aef25',
          messagingSenderId: '709452424896',
          projectId: 'expensestracker-bbd7b',
          storageBucket: 'expensestracker-bbd7b.appspot.com',
          authDomain: 'expensestracker-bbd7b.firebaseapp.com',
        ),
      );
    } else {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyDdWpLkJ4Zg1UoAj2pVl3ftjBzI2zqaZYA',
          appId: '1:709452424896:android:706710396b595b527aef25',
          messagingSenderId: '709452424896',
          projectId: 'expensestracker-bbd7b',
          storageBucket: 'expensestracker-bbd7b.appspot.com',
        ),
      );
    }
    
    // Configure Firestore settings - same for web and mobile
    FirebaseFirestore.instance.settings = Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      // Increase timeouts for better reliability
      host: kIsWeb ? 'firestore.googleapis.com' : null,
      sslEnabled: true,
    );
    
    // Configure persistence for web and mobile
    if (kIsWeb) {
      try {
        // Configure persistence settings for web
        FirebaseFirestore.instance.settings = Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        debugPrint('✅ Web persistence enabled successfully');
      } catch (e) {
        // This error is expected if persistence was already enabled
        debugPrint('ℹ️ Persistence configuration issue: $e');
      }
    }

    // Force a connection to verify Firebase is properly initialized
    try {
      await FirebaseFirestore.instance.collection('_initialization_test')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      debugPrint('✅ Firebase connection verified successfully');
    } catch (e) {
      debugPrint('⚠️ Firebase connection test failed: $e');
      // Don't throw - we'll handle connectivity issues through the service
    }
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
    // Show a user-friendly message or rethrow based on your error handling strategy
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core services
        ChangeNotifierProvider<ConnectivityService>(
          create: (_) => ConnectivityService(),
        ),
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProvider<CurrencyService>(
          create: (_) => CurrencyService(),
        ),
        ChangeNotifierProvider<CategoryService>(
          create: (_) => CategoryService(),
        ),
        
        // Services that depend on auth
        ChangeNotifierProxyProvider<AuthService, UserProfileService>(
          create: (_) => UserProfileService(),
          update: (_, auth, previous) => previous ?? UserProfileService(),
        ),
        ChangeNotifierProxyProvider2<AuthService, ConnectivityService, BudgetService>(
          create: (_) => BudgetService(),
          update: (_, auth, connectivity, previous) {
            final service = previous ?? BudgetService();
            service.initializeWithConnectivity(connectivity);
            return service;
          },
        ),
        ChangeNotifierProxyProvider2<AuthService, ConnectivityService, TransactionService>(
          create: (_) => TransactionService(),
          update: (_, auth, connectivity, previous) {
            final service = previous ?? TransactionService();
            service.initializeWithConnectivity(connectivity);
            return service;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Expenses Tracker',
        debugShowCheckedModeBanner: false, // Make sure this is always false for cleaner UI
        // Add these settings to handle screen dimensions properly across devices
        // Set a consistent text scale factor
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.0),
            ),
            child: child!,
          );
        },
        theme: ThemeData(
          useMaterial3: true,
          // Ensure app adapts to Pixel 4 screen cutouts and rounded corners
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
            ),
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1), // Modern indigo
            brightness: Brightness.light,
          ),
          // Professional Typography
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            headlineMedium: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            titleLarge: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
            bodyLarge: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
            ),
            bodyMedium: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
            ),
          ),
          // Professional Card Theme
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            shadowColor: Colors.black.withAlpha(26),
          ),
          // Modern App Bar Theme is defined above
          // Professional Button Themes
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
          // Professional Input Decoration
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        home: const Wrapper(),
      ),
    );
  }
}
