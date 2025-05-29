import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService with ChangeNotifier {
  static const String _baseUrl = 'https://api.exchangerate-api.com/v4/latest';
  static const String _baseCurrency = 'USD'; // All amounts stored in USD
  static const String _cacheKey = 'exchange_rates';
  static const String _cacheTimestampKey = 'exchange_rates_timestamp';
  static const int _cacheValidityHours = 6; // Cache for 6 hours

  Map<String, double> _exchangeRates = {};
  DateTime? _lastUpdate;
  bool _isLoading = false;

  // Getters
  Map<String, double> get exchangeRates => Map.from(_exchangeRates);
  bool get isLoading => _isLoading;
  DateTime? get lastUpdate => _lastUpdate;

  CurrencyService() {
    _loadCachedRates();
  }

  /// Load cached exchange rates from local storage
  Future<void> _loadCachedRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRates = prefs.getString(_cacheKey);
      final cachedTimestamp = prefs.getInt(_cacheTimestampKey);

      if (cachedRates != null && cachedTimestamp != null) {
        final timestamp = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
        final now = DateTime.now();
        
        // Check if cache is still valid
        if (now.difference(timestamp).inHours < _cacheValidityHours) {
          _exchangeRates = Map<String, double>.from(json.decode(cachedRates));
          _lastUpdate = timestamp;
          notifyListeners();
          debugPrint('Loaded cached exchange rates: ${_exchangeRates.length} currencies');
          return;
        }
      }
      
      // Cache is invalid or doesn't exist, fetch new rates
      await fetchExchangeRates();
    } catch (e) {
      debugPrint('Error loading cached rates: $e');
      await fetchExchangeRates();
    }
  }

  /// Fetch latest exchange rates from API
  Future<void> fetchExchangeRates() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_baseCurrency'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _exchangeRates = Map<String, double>.from(data['rates']);
        _lastUpdate = DateTime.now();

        // Cache the rates
        await _cacheRates();
        
        debugPrint('Fetched exchange rates: ${_exchangeRates.length} currencies');
        notifyListeners();
      } else {
        throw Exception('Failed to fetch exchange rates: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching exchange rates: $e');
      // If we have cached rates, use them
      if (_exchangeRates.isEmpty) {
        _setFallbackRates();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cache exchange rates to local storage
  Future<void> _cacheRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(_exchangeRates));
      await prefs.setInt(_cacheTimestampKey, _lastUpdate!.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error caching exchange rates: $e');
    }
  }

  /// Set fallback rates if API fails
  void _setFallbackRates() {
    _exchangeRates = {
      'USD': 1.0,
      'EUR': 0.85,
      'GBP': 0.73,
      'JPY': 110.0,
      'CAD': 1.25,
      'AUD': 1.35,
      'CHF': 0.92,
      'CNY': 6.45,
      'INR': 74.5,
      'KRW': 1180.0,
    };
    _lastUpdate = DateTime.now();
    debugPrint('Using fallback exchange rates');
  }

  /// Convert amount from USD to target currency
  double convertFromUSD(double amountUSD, String targetCurrency) {
    if (targetCurrency == _baseCurrency) return amountUSD;
    
    final rate = _exchangeRates[targetCurrency];
    if (rate == null) {
      debugPrint('Exchange rate not found for $targetCurrency, using USD');
      return amountUSD;
    }
    
    return amountUSD * rate;
  }

  /// Convert amount from source currency to USD
  double convertToUSD(double amount, String sourceCurrency) {
    if (sourceCurrency == _baseCurrency) return amount;
    
    final rate = _exchangeRates[sourceCurrency];
    if (rate == null) {
      debugPrint('Exchange rate not found for $sourceCurrency, treating as USD');
      return amount;
    }
    
    return amount / rate;
  }

  /// Convert amount between any two currencies
  double convertCurrency(double amount, String fromCurrency, String toCurrency) {
    if (fromCurrency == toCurrency) return amount;
    
    // Convert to USD first, then to target currency
    final amountUSD = convertToUSD(amount, fromCurrency);
    return convertFromUSD(amountUSD, toCurrency);
  }

  /// Get exchange rate between two currencies
  double getExchangeRate(String fromCurrency, String toCurrency) {
    if (fromCurrency == toCurrency) return 1.0;
    
    final fromRate = _exchangeRates[fromCurrency] ?? 1.0;
    final toRate = _exchangeRates[toCurrency] ?? 1.0;
    
    if (fromCurrency == _baseCurrency) {
      return toRate;
    } else if (toCurrency == _baseCurrency) {
      return 1.0 / fromRate;
    } else {
      return toRate / fromRate;
    }
  }

  /// Check if exchange rates are available
  bool hasRates() {
    return _exchangeRates.isNotEmpty;
  }

  /// Force refresh exchange rates
  Future<void> refreshRates() async {
    await fetchExchangeRates();
  }

  /// Get formatted currency amount with symbol
  String formatCurrency(double amount, String currencyCode) {
    // Currency symbols mapping
    const symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'CAD': 'C\$',
      'AUD': 'A\$',
      'CHF': 'CHF',
      'CNY': '¥',
      'INR': '₹',
      'KRW': '₩',
    };

    final symbol = symbols[currencyCode] ?? currencyCode;
    
    // Format based on currency
    if (currencyCode == 'JPY' || currencyCode == 'KRW') {
      // No decimal places for these currencies
      return '$symbol${amount.round()}';
    } else {
      return '$symbol${amount.toStringAsFixed(2)}';
    }
  }
}
