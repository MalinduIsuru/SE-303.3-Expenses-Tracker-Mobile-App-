// filepath: e:\Project\lib\screens\home\budget_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:expensestracker/services/budget_service.dart' show BudgetService;
import 'package:expensestracker/services/transaction_service.dart' show TransactionService;
import 'package:expensestracker/services/connectivity_service.dart' show ConnectivityService;
import 'package:expensestracker/services/currency_service.dart';
import '../../widgets/professional_ui_components.dart';
import '../../widgets/debounced_text_field.dart';

class BudgetTab extends StatefulWidget {
  const BudgetTab({super.key});

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _budgetController = TextEditingController();
  bool _isEditingBudget = false;
  bool _isSavingBudget = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentBudget();
    });
  }
  
  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }
  
  Future<void> _loadCurrentBudget() async {
    final budgetService = Provider.of<BudgetService>(context, listen: false);
    final budget = await budgetService.getCurrentBudget();
    if (budget != null && budget['amount'] != null) {
      // Update controller with current budget amount
      _budgetController.text = budget['amount'].toString();
    }
  }
  
  // Toggle between view mode and edit mode
  void _toggleEditMode() {
    setState(() {
      _isEditingBudget = !_isEditingBudget;
      if (!_isEditingBudget) {
        // If canceling edit, reset the controller to the current budget
        _loadCurrentBudget();
      }
    });
  }
  
  // Save the budget amount
  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSavingBudget = true;
    });
    
    try {
      final String cleanedAmount = _budgetController.text.replaceAll(RegExp(r'[^\d\.]'), '');
      final double? budgetAmount = double.tryParse(cleanedAmount);
      
      if (budgetAmount == null) {
        throw Exception('Invalid budget amount');
      }
      
      final budgetService = Provider.of<BudgetService>(context, listen: false);
      final result = await budgetService.setMonthlyBudget(budgetAmount);
      
      if (result) {
        setState(() {
          _isEditingBudget = false;
          _isSavingBudget = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Budget updated successfully'),
              backgroundColor: ProfessionalColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update budget'),
              backgroundColor: ProfessionalColors.error,
            ),
          );
        }
        setState(() {
          _isSavingBudget = false;
        });
      }
    } catch (e) {
      debugPrint('Error saving budget: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: ProfessionalColors.error,
          ),
        );
      }
      setState(() {
        _isSavingBudget = false;
      });
    }
  }
  
  // Reset the budget
  Future<void> _resetBudget() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Budget'),
        content: const Text('Are you sure you want to reset your budget? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'RESET',
              style: TextStyle(color: ProfessionalColors.error),
            ),
          ),
        ],
      ),
    );      if (shouldReset == true) {
      // Capture all context-dependent references before async operation
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final budgetService = Provider.of<BudgetService>(context, listen: false);
      
      setState(() {
        _isSavingBudget = true;
      });
      
      try {
        final result = await budgetService.resetBudget();
        
        if (result) {
          _budgetController.text = '';
            scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Budget has been reset'),
              backgroundColor: ProfessionalColors.primary,
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Failed to reset budget'),
              backgroundColor: ProfessionalColors.error,
            ),
          );
        }
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: ProfessionalColors.error,
          ),
        );
      } finally {
        setState(() {
          _isSavingBudget = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfessionalColors.background,
      appBar: AppBar(
        title: const Text('Budget'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ProfessionalColors.gray800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBudgetCard(),
            const SizedBox(height: 24),
            _buildSpendingInsights(),
            const SizedBox(height: 24),
            _buildMonthlyBreakdown(),
            const SizedBox(height: 24),
            _buildBudgetTips(),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetCard() {
    return Consumer2<BudgetService, TransactionService>(
      builder: (context, budgetService, transactionService, _) {
        final connectivityService = Provider.of<ConnectivityService>(context, listen: true);
        final budget = budgetService.currentBudget;
        final budgetAmount = budget?['amount']?.toDouble() ?? 0.0;
        final isAutocopied = budget?['autoCopied'] ?? false;
        final expenses = transactionService.cachedMonthlyTotal;
        final remaining = budgetAmount - expenses;
        final isOffline = !connectivityService.isOnline;
        final hasPendingWrite = budgetService.hasPendingWrite;
        
        return ProfessionalCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 28,
                    color: ProfessionalColors.primary,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Monthly Budget',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ProfessionalColors.gray800,
                    ),
                  ),
                  const Spacer(),
                  // Status indicator for offline mode
                  if (isOffline || hasPendingWrite)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOffline
                            ? ProfessionalColors.warning.withAlpha(26)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOffline
                              ? ProfessionalColors.warning
                              : ProfessionalColors.gray300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOffline ? Icons.wifi_off : Icons.sync,
                            size: 12,
                            color: isOffline
                                ? ProfessionalColors.warning
                                : ProfessionalColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOffline ? 'Offline' : 'Syncing',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isOffline
                                  ? ProfessionalColors.warning
                                  : ProfessionalColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Budget Form / Display
              if (_isEditingBudget)
                _buildBudgetForm()
              else
                _buildBudgetDisplay(budgetAmount, expenses, remaining, isAutocopied),
              
              // Action buttons
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isEditingBudget) ...[
                    // Cancel button
                    TextButton(
                      onPressed: _isSavingBudget ? null : _toggleEditMode,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    // Save button
                    ElevatedButton(
                      onPressed: _isSavingBudget ? null : _saveBudget,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ProfessionalColors.primary,
                      ),
                      child: _isSavingBudget
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Save'),
                    ),
                  ] else ...[                    // Reset Budget button
                    TextButton.icon(
                      onPressed: _resetBudget,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: ProfessionalColors.error,
                      ),
                      label: const Text(
                        'Reset',
                        style: TextStyle(
                          color: ProfessionalColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Edit Budget button
                    FilledButton.icon(
                      onPressed: _toggleEditMode,
                      icon: const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Edit Budget',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: ProfessionalColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildBudgetForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set your monthly budget:',
            style: TextStyle(
              fontSize: 16,
              color: ProfessionalColors.gray700,
            ),
          ),
          const SizedBox(height: 12),
          Consumer<CurrencyService>(
            builder: (context, currencyService, _) {
              // Get the currency symbol from the service
              final currencySymbol = currencyService.exchangeRates.isEmpty
                  ? '\$'  // Default to $ if rates not loaded yet
                  : '\$'; // For now using $ since we store in USD, but could be enhanced
                  
              return DebouncedTextField(
                controller: _budgetController,
                labelText: 'Budget Amount',
                prefixText: '$currencySymbol ',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a budget amount';
                  }
                  if (double.tryParse(value.replaceAll(RegExp(r'[^\d\.]'), '')) == null) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
                autofocus: true,
                debounceDuration: const Duration(milliseconds: 300),
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the total amount you want to allocate for this month',
            style: TextStyle(
              fontSize: 12,
              color: ProfessionalColors.gray500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBudgetDisplay(
    double budgetAmount,
    double expenses,
    double remaining,
    bool isAutocopied,
  ) {
    return Consumer<CurrencyService>(
      builder: (context, currencyService, _) {
        final formatter = NumberFormat.currency(
          symbol: '\$',
          decimalDigits: 2,
        );
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Total Budget Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Budget: ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: ProfessionalColors.gray700,
                  ),
                ),
                Text(
                  formatter.format(budgetAmount),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: ProfessionalColors.primary,
                  ),
                ),
              ],
            ),
            if (isAutocopied)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ProfessionalColors.gray100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Auto-copied from last month',
                  style: TextStyle(
                    fontSize: 12,
                    color: ProfessionalColors.gray600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // Budget Summary
            Row(
              children: [
                // Spent
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Spent',
                        style: TextStyle(
                          fontSize: 14,
                          color: ProfessionalColors.gray600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatter.format(expenses),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ProfessionalColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Remaining
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Remaining',
                        style: TextStyle(
                          fontSize: 14,
                          color: ProfessionalColors.gray600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatter.format(remaining),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: remaining >= 0
                              ? ProfessionalColors.success
                              : ProfessionalColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Progress bar
            const SizedBox(height: 20),
            if (budgetAmount > 0) ...[
              LinearProgressIndicator(
                value: (expenses / budgetAmount).clamp(0.0, 1.0),
                backgroundColor: ProfessionalColors.gray200,
                color: _getProgressColor(expenses / budgetAmount),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${((expenses / budgetAmount) * 100).round()}% spent',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ProfessionalColors.gray600,
                    ),
                  ),
                  Text(
                    remaining >= 0
                        ? '${(100 - (expenses / budgetAmount) * 100).round()}% remaining'
                        : 'Over budget',
                    style: TextStyle(
                      fontSize: 12,
                      color: remaining >= 0
                          ? ProfessionalColors.gray600
                          : ProfessionalColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
  
  // Budget progress color based on percentage
  Color _getProgressColor(double percentageSpent) {
    if (percentageSpent <= 0.7) {
      return ProfessionalColors.success;
    } else if (percentageSpent <= 0.9) {
      return ProfessionalColors.warning;
    } else {
      return ProfessionalColors.error;
    }
  }
  
  Widget _buildSpendingInsights() {
    return Consumer2<BudgetService, TransactionService>(
      builder: (context, budgetService, transactionService, _) {
        final budget = budgetService.currentBudget;
        final budgetAmount = budget?['amount']?.toDouble() ?? 0.0;
        final expenses = transactionService.cachedMonthlyTotal;
        final categoryBreakdown = transactionService.cachedCategoryBreakdown;
        
        return ProfessionalCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Spending Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ProfessionalColors.gray800,
                ),
              ),
              const SizedBox(height: 16),
              
              // Daily budget remaining
              _buildInsightItem(
                icon: Icons.calendar_today,
                title: 'Daily Budget',
                value: _calculateDailyBudget(budgetAmount, expenses),
                subtitle: 'Remaining budget divided by days left',
              ),
              
              const Divider(height: 24),
              
              // Top spending category
              _buildInsightItem(
                icon: Icons.category,
                title: 'Top Category',
                value: _getTopCategory(categoryBreakdown),
                subtitle: 'Your highest spending category',
              ),
              
              const Divider(height: 24),
              
              // Budget status
              _buildInsightItem(
                icon: _getBudgetStatusIcon(expenses, budgetAmount),
                title: 'Budget Status',
                value: _getBudgetStatus(expenses, budgetAmount),
                valueColor: _getBudgetStatusColor(expenses, budgetAmount),
                subtitle: _getBudgetStatusMessage(expenses, budgetAmount),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildInsightItem({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ProfessionalColors.primary.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: ProfessionalColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: ProfessionalColors.gray600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? ProfessionalColors.gray900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ProfessionalColors.gray500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _calculateDailyBudget(double budget, double spent) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = daysInMonth - now.day + 1;
    
    if (daysRemaining <= 0 || budget <= 0) {
      return '\$0.00';
    }
    
    final remaining = budget - spent;
    final dailyBudget = remaining / daysRemaining;
    
    return NumberFormat.currency(symbol: '\$').format(dailyBudget);
  }
  
  String _getTopCategory(Map<String, double> categoryBreakdown) {
    if (categoryBreakdown.isEmpty) {
      return 'None yet';
    }
    
    // Find the category with highest spending
    final sortedCategories = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    if (sortedCategories.isEmpty) {
      return 'None yet';
    }
    
    return sortedCategories.first.key;
  }
  
  IconData _getBudgetStatusIcon(double expenses, double budget) {
    if (budget <= 0) return Icons.help_outline;
    
    final percentage = expenses / budget;
    
    if (percentage >= 1.0) {
      return Icons.warning_amber;
    } else if (percentage >= 0.9) {
      return Icons.error_outline;
    } else if (percentage >= 0.7) {
      return Icons.info_outline;
    } else {
      return Icons.check_circle_outline;
    }
  }
  
  Color _getBudgetStatusColor(double expenses, double budget) {
    if (budget <= 0) return ProfessionalColors.gray600;
    
    final percentage = expenses / budget;
    
    if (percentage >= 1.0) {
      return ProfessionalColors.error;
    } else if (percentage >= 0.9) {
      return ProfessionalColors.warning;
    } else if (percentage >= 0.7) {
      return ProfessionalColors.warning;
    } else {
      return ProfessionalColors.success;
    }
  }
  
  String _getBudgetStatus(double expenses, double budget) {
    if (budget <= 0) return 'Not set';
    
    final percentage = expenses / budget;
    
    if (percentage >= 1.0) {
      return 'Over Budget';
    } else if (percentage >= 0.9) {
      return 'Critical';
    } else if (percentage >= 0.7) {
      return 'Warning';
    } else {
      return 'On Track';
    }
  }
  
  String _getBudgetStatusMessage(double expenses, double budget) {
    if (budget <= 0) return 'Set a budget to start tracking';
    
    final percentage = expenses / budget;
    
    if (percentage >= 1.0) {
      return 'You\'ve exceeded your monthly budget';
    } else if (percentage >= 0.9) {
      return 'You\'re very close to exceeding your budget';
    } else if (percentage >= 0.7) {
      return 'You\'ve used more than 70% of your budget';
    } else {
      return 'You\'re managing your budget well';
    }
  }
  
  Widget _buildMonthlyBreakdown() {
    final now = DateTime.now();
    final month = DateFormat('MMMM yyyy').format(now);
    
    return ProfessionalCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pie_chart,
                color: ProfessionalColors.primary,
              ),
              const SizedBox(width: 12),
              Text(
                '$month Budget',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ProfessionalColors.gray800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Monthly stats
          Consumer2<BudgetService, TransactionService>(
            builder: (context, budgetService, transactionService, _) {
              final budget = budgetService.currentBudget;
              final budgetAmount = budget?['amount']?.toDouble() ?? 0.0;
              final expenses = transactionService.cachedMonthlyTotal;
              
              final formatter = NumberFormat.currency(symbol: '\$');
              final now = DateTime.now();
              final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
              final daysPassed = now.day;
              final daysRemaining = daysInMonth - daysPassed;
              
              return Column(
                children: [
                  _buildStatRow(
                    'Budget',
                    formatter.format(budgetAmount),
                    Icons.account_balance_wallet,
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    'Spent So Far',
                    formatter.format(expenses),
                    Icons.shopping_cart,
                    valueColor: ProfessionalColors.error,
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    'Remaining',
                    formatter.format(budgetAmount - expenses),
                    Icons.savings,
                    valueColor: (budgetAmount - expenses) >= 0
                        ? ProfessionalColors.success
                        : ProfessionalColors.error,
                  ),
                  const Divider(height: 24),
                  _buildStatRow(
                    'Days Passed',
                    daysPassed.toString(),
                    Icons.event_available,
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    'Days Remaining',
                    daysRemaining.toString(),
                    Icons.event_busy,
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    'Daily Average',
                    daysPassed > 0
                        ? formatter.format(expenses / daysPassed)
                        : '\$0.00',
                    Icons.trending_up,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: ProfessionalColors.gray500,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: ProfessionalColors.gray600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: valueColor ?? ProfessionalColors.gray900,
          ),
        ),
      ],
    );
  }
  
  Widget _buildBudgetTips() {
    return ProfessionalCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: ProfessionalColors.warning,
              ),
              SizedBox(width: 12),
              Text(
                'Budget Tips',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ProfessionalColors.gray800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildTipItem(
            '50/30/20 Rule',
            'Try allocating 50% for needs, 30% for wants, and 20% for savings',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            'Zero-Based Budgeting',
            'Give every dollar a purpose by assigning it to expenses or savings',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            'Review Weekly',
            'Check your spending progress weekly to stay on track',
          ),
        ],
      ),
    );
  }
  
  Widget _buildTipItem(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.arrow_right,
          color: ProfessionalColors.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ProfessionalColors.gray800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: ProfessionalColors.gray600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}