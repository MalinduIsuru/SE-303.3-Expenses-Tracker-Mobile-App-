import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/currency_service.dart';
import '../services/user_profile_service.dart';

class CurrencyDisplay extends StatelessWidget {
  final double amountUSD; // Amount in USD (base currency)
  final TextStyle? style;
  final bool showSymbol;
  final bool showCode;

  const CurrencyDisplay({
    super.key,
    required this.amountUSD,
    this.style,
    this.showSymbol = true,
    this.showCode = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: Provider.of<UserProfileService>(context).userProfileStream,
      builder: (context, snapshot) {
        return Consumer<CurrencyService>(
          builder: (context, currencyService, child) {
            // Get user's preferred currency from their profile
            final userData = snapshot.data;
            final userProfileService = Provider.of<UserProfileService>(context, listen: false);
            final userCurrency = userProfileService.getUserCurrency(userData);

            // Convert amount to user's preferred currency
            final convertedAmount = currencyService.convertFromUSD(amountUSD, userCurrency);

            // Format the currency display
            String displayText;
            if (showSymbol && showCode) {
              displayText = '${currencyService.formatCurrency(convertedAmount, userCurrency)} $userCurrency';
            } else if (showCode) {
              displayText = '${convertedAmount.toStringAsFixed(2)} $userCurrency';
            } else {
              displayText = currencyService.formatCurrency(convertedAmount, userCurrency);
            }

            return Text(
              displayText,
              style: style,
            );
          },
        );
      },
    );
  }
}

class CurrencyInput extends StatefulWidget {
  final double? initialAmountUSD;
  final Function(double amountUSD) onChanged;
  final String? labelText;
  final String? hintText;
  final TextStyle? style;
  final InputDecoration? decoration;

  const CurrencyInput({
    super.key,
    this.initialAmountUSD,
    required this.onChanged,
    this.labelText,
    this.hintText,
    this.style,
    this.decoration,
  });

  @override
  State<CurrencyInput> createState() => _CurrencyInputState();
}

class _CurrencyInputState extends State<CurrencyInput> {
  late TextEditingController _controller;
  String _currentCurrency = 'USD';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    // Initial display amount will be set in build method
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateDisplayAmount(Map<String, dynamic>? userData) {
    final currencyService = Provider.of<CurrencyService>(context, listen: false);
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);

    // Get user's preferred currency
    final userCurrency = userProfileService.getUserCurrency(userData);

    if (widget.initialAmountUSD != null && _currentCurrency != userCurrency) {
      final convertedAmount = currencyService.convertFromUSD(widget.initialAmountUSD!, userCurrency);
      _controller.text = convertedAmount.toStringAsFixed(2);
      _currentCurrency = userCurrency;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: Provider.of<UserProfileService>(context).userProfileStream,
      builder: (context, snapshot) {
        return Consumer<CurrencyService>(
          builder: (context, currencyService, child) {
            // Get user's preferred currency
            final userData = snapshot.data;
            final userProfileService = Provider.of<UserProfileService>(context, listen: false);
            final userCurrency = userProfileService.getUserCurrency(userData);
            final currencySymbol = getCurrencySymbol(userCurrency);

            // Update display if currency changed
            if (_currentCurrency != userCurrency) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _updateDisplayAmount(userData);
              });
            }

            return TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: widget.style,
              decoration: widget.decoration ?? InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                prefixText: currencySymbol,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                final amount = double.tryParse(value) ?? 0.0;
                // Convert to USD for storage
                final amountUSD = currencyService.convertToUSD(amount, userCurrency);
                widget.onChanged(amountUSD);
              },
            );
          },
        );
      },
    );
  }
}

class CurrencyCard extends StatelessWidget {
  final String title;
  final double amountUSD;
  final IconData icon;
  final Color? color;
  final TextStyle? titleStyle;
  final TextStyle? amountStyle;

  const CurrencyCard({
    super.key,
    required this.title,
    required this.amountUSD,
    required this.icon,
    this.color,
    this.titleStyle,
    this.amountStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color ?? Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: titleStyle ?? Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CurrencyDisplay(
              amountUSD: amountUSD,
              style: amountStyle ?? Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color ?? Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to get currency symbol
String getCurrencySymbol(String currencyCode) {
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
  return symbols[currencyCode] ?? currencyCode;
}
