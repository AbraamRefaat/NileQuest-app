import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for currency conversion and price information
class CurrencyService {
  // Using ExchangeRate-API (free tier)
  static const String _apiKey = 'YOUR_EXCHANGERATE_API_KEY'; // User needs to add their key
  static const String _baseUrl = 'https://v6.exchangerate-api.com/v6';
  final Dio _dio = Dio();

  static const String _cacheKey = 'exchange_rates';
  static const String _cacheTimeKey = 'exchange_rates_time';
  static const int _cacheHours = 24;

  /// Get exchange rates (cached for 24 hours)
  Future<Map<String, double>> getExchangeRates() async {
    try {
      // Check cache first
      final prefs = await SharedPreferences.getInstance();
      final cachedRates = prefs.getString(_cacheKey);
      final cacheTime = prefs.getInt(_cacheTimeKey) ?? 0;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheAge = now - cacheTime;
      final cacheValid = cacheAge < (_cacheHours * 60 * 60 * 1000);

      if (cachedRates != null && cacheValid) {
        return _parseRates(cachedRates);
      }

      // Fetch fresh rates
      final response = await _dio.get('$_baseUrl/$_apiKey/latest/EGP');

      if (response.statusCode == 200) {
        final rates = response.data['conversion_rates'] as Map<String, dynamic>;
        final ratesMap = rates.map((key, value) => MapEntry(key, (value as num).toDouble()));
        
        // Cache the rates
        await prefs.setString(_cacheKey, rates.toString());
        await prefs.setInt(_cacheTimeKey, now);
        
        return ratesMap;
      }
      
      return {};
    } catch (e) {
      print('Error fetching exchange rates: $e');
      return {};
    }
  }

  Map<String, double> _parseRates(String cached) {
    // Simple parsing - in production, use proper JSON
    return {
      'USD': 0.032,
      'EUR': 0.030,
      'GBP': 0.026,
      'JPY': 4.80,
      'CNY': 0.23,
      'AUD': 0.050,
      'CAD': 0.045,
      'SAR': 0.12,
      'AED': 0.12,
    };
  }

  /// Convert EGP to target currency
  Future<double> convertFromEGP(double egpAmount, String targetCurrency) async {
    final rates = await getExchangeRates();
    final rate = rates[targetCurrency.toUpperCase()] ?? 1.0;
    return egpAmount * rate;
  }

  /// Convert target currency to EGP
  Future<double> convertToEGP(double amount, String sourceCurrency) async {
    final rates = await getExchangeRates();
    final rate = rates[sourceCurrency.toUpperCase()] ?? 1.0;
    return amount / rate;
  }

  /// Format price with currency symbol
  String formatPrice(double egpAmount, String targetCurrency) {
    final symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'CNY': '¥',
      'AUD': 'A\$',
      'CAD': 'C\$',
      'SAR': 'SR',
      'AED': 'AED',
      'EGP': 'EGP',
    };

    final symbol = symbols[targetCurrency.toUpperCase()] ?? targetCurrency;
    
    if (targetCurrency.toUpperCase() == 'EGP') {
      return '$egpAmount $symbol';
    }

    // Convert and format
    convertFromEGP(egpAmount, targetCurrency).then((converted) {
      if (targetCurrency == 'JPY' || targetCurrency == 'CNY') {
        return '$symbol${converted.round()}';
      }
      return '$symbol${converted.toStringAsFixed(2)}';
    });

    return '$egpAmount EGP';
  }

  /// Get fair price indicators for common tourist items
  Map<String, PriceGuide> getTouristPriceGuides() {
    return {
      'taxi_per_km': PriceGuide(
        item: 'Taxi (per km)',
        localPrice: 5.0,
        touristPrice: 15.0,
        fairPrice: 8.0,
        tips: [
          'Use Uber or Careem for fixed prices',
          'Always agree on fare before starting',
          'Insist on using the meter',
        ],
      ),
      'water_bottle': PriceGuide(
        item: 'Water Bottle (1.5L)',
        localPrice: 5.0,
        touristPrice: 20.0,
        fairPrice: 8.0,
        tips: [
          'Buy from supermarkets, not tourist areas',
          'Convenience stores charge 10-15 EGP',
        ],
      ),
      'street_food': PriceGuide(
        item: 'Street Food Meal',
        localPrice: 30.0,
        touristPrice: 100.0,
        fairPrice: 50.0,
        tips: [
          'Koshary: 20-40 EGP',
          'Falafel sandwich: 10-20 EGP',
          'Shawarma: 30-50 EGP',
        ],
      ),
      'restaurant_meal': PriceGuide(
        item: 'Restaurant Meal',
        localPrice: 150.0,
        touristPrice: 400.0,
        fairPrice: 200.0,
        tips: [
          'Budget: 100-200 EGP',
          'Mid-range: 200-400 EGP',
          'Fine dining: 500+ EGP',
        ],
      ),
      'museum_entry': PriceGuide(
        item: 'Museum Entry',
        localPrice: 30.0,
        touristPrice: 200.0,
        fairPrice: 200.0,
        tips: [
          'Egyptian Museum: 200 EGP',
          'Grand Egyptian Museum: 500 EGP',
          'Student discounts available with ID',
        ],
      ),
      'papyrus': PriceGuide(
        item: 'Papyrus Souvenir',
        localPrice: 50.0,
        touristPrice: 500.0,
        fairPrice: 150.0,
        tips: [
          'Many are fake (banana leaf)',
          'Bargain hard - start at 30% of asking price',
          'Real papyrus costs 100-300 EGP',
        ],
      ),
      'pyramid_entry': PriceGuide(
        item: 'Pyramid Entry',
        localPrice: 80.0,
        touristPrice: 400.0,
        fairPrice: 400.0,
        tips: [
          'Giza Pyramids area: 200 EGP',
          'Inside Great Pyramid: +400 EGP',
          'Sphinx included in area ticket',
        ],
      ),
      'felucca_ride': PriceGuide(
        item: 'Felucca Ride (1 hour)',
        localPrice: 100.0,
        touristPrice: 300.0,
        fairPrice: 150.0,
        tips: [
          'Negotiate before boarding',
          'Group rides cheaper (per person)',
          'Sunset rides cost more',
        ],
      ),
    };
  }

  /// Get bargaining tips
  List<BargainingTip> getBargainingTips() {
    return [
      BargainingTip(
        title: 'Start Low',
        description: 'Offer 30-40% of the asking price',
        icon: '💰',
      ),
      BargainingTip(
        title: 'Walk Away',
        description: 'If price is too high, start walking away - they\'ll often call you back',
        icon: '🚶',
      ),
      BargainingTip(
        title: 'Bundle Deals',
        description: 'Buy multiple items for a better overall price',
        icon: '📦',
      ),
      BargainingTip(
        title: 'Cash is King',
        description: 'Paying cash often gets you a better deal',
        icon: '💵',
      ),
      BargainingTip(
        title: 'Be Polite',
        description: 'Friendly negotiation works better than aggressive haggling',
        icon: '😊',
      ),
      BargainingTip(
        title: 'Know the Value',
        description: 'Research typical prices beforehand',
        icon: '🔍',
      ),
    ];
  }

  /// Get common scam warnings
  List<ScamWarning> getScamWarnings() {
    return [
      ScamWarning(
        title: 'Unofficial Guides',
        description: 'People offering "free" tours then demanding payment',
        avoidance: 'Only use licensed guides with official badges',
        severity: ScamSeverity.high,
      ),
      ScamWarning(
        title: 'Taxi Meter "Broken"',
        description: 'Driver claims meter is broken, charges inflated fare',
        avoidance: 'Use Uber/Careem or agree on price before starting',
        severity: ScamSeverity.medium,
      ),
      ScamWarning(
        title: 'Fake Papyrus',
        description: 'Banana leaf sold as papyrus at high prices',
        avoidance: 'Buy from reputable shops, real papyrus feels different',
        severity: ScamSeverity.low,
      ),
      ScamWarning(
        title: 'Photography Fees',
        description: 'People demand money after you photograph them',
        avoidance: 'Ask permission first or avoid photographing people',
        severity: ScamSeverity.low,
      ),
      ScamWarning(
        title: 'Perfume Shop Pressure',
        description: 'High-pressure sales tactics in perfume shops',
        avoidance: 'Politely decline and leave if uncomfortable',
        severity: ScamSeverity.medium,
      ),
    ];
  }

  /// Get supported currencies
  List<String> getSupportedCurrencies() {
    return ['USD', 'EUR', 'GBP', 'JPY', 'CNY', 'AUD', 'CAD', 'SAR', 'AED', 'EGP'];
  }

  /// Get currency name
  String getCurrencyName(String code) {
    const names = {
      'USD': 'US Dollar',
      'EUR': 'Euro',
      'GBP': 'British Pound',
      'JPY': 'Japanese Yen',
      'CNY': 'Chinese Yuan',
      'AUD': 'Australian Dollar',
      'CAD': 'Canadian Dollar',
      'SAR': 'Saudi Riyal',
      'AED': 'UAE Dirham',
      'EGP': 'Egyptian Pound',
    };
    return names[code.toUpperCase()] ?? code;
  }
}

class PriceGuide {
  final String item;
  final double localPrice; // What locals pay
  final double touristPrice; // What tourists often pay
  final double fairPrice; // What you should pay
  final List<String> tips;

  PriceGuide({
    required this.item,
    required this.localPrice,
    required this.touristPrice,
    required this.fairPrice,
    required this.tips,
  });

  double get markup => ((touristPrice - fairPrice) / fairPrice * 100);
  String get markupText => '${markup.round()}% markup';

  bool isOverpriced(double price) => price > fairPrice * 1.2;
  bool isFairPrice(double price) => price >= fairPrice * 0.8 && price <= fairPrice * 1.2;
  bool isGoodDeal(double price) => price < fairPrice * 0.8;
}

class BargainingTip {
  final String title;
  final String description;
  final String icon;

  BargainingTip({
    required this.title,
    required this.description,
    required this.icon,
  });
}

enum ScamSeverity { low, medium, high }

class ScamWarning {
  final String title;
  final String description;
  final String avoidance;
  final ScamSeverity severity;

  ScamWarning({
    required this.title,
    required this.description,
    required this.avoidance,
    required this.severity,
  });

  String get severityText {
    switch (severity) {
      case ScamSeverity.low:
        return 'Low Risk';
      case ScamSeverity.medium:
        return 'Medium Risk';
      case ScamSeverity.high:
        return 'High Risk';
    }
  }

  String get severityIcon {
    switch (severity) {
      case ScamSeverity.low:
        return '⚠️';
      case ScamSeverity.medium:
        return '⚠️⚠️';
      case ScamSeverity.high:
        return '🚨';
    }
  }
}
