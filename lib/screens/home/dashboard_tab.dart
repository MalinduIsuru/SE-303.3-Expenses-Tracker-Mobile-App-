import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/budget_service.dart';
import '../../services/transaction_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/category_service.dart';
import '../../widgets/currency_display.dart';
import '../../widgets/professional_ui_components.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfessionalColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Professional Header
            _buildHeader(context),
            const SizedBox(height: 32),

            // Balance Overview Cards
            _buildBalanceOverview(),
            const SizedBox(height: 24),

            // Budget Progress
            _buildBudgetProgress(),
            const SizedBox(height: 24),

            // Category Breakdown
            _buildCategoryBreakdown(),
            const SizedBox(height: 24),

            // Quick Stats
            _buildQuickStats(),
            const SizedBox(height: 100), // Extra bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<UserProfileService>(
      builder: (context, userProfileService, child) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: userProfileService.getUserProfile(),
          builder: (context, snapshot) {
            final userData = snapshot.data;
            final displayName = userData?['displayName'] ?? 'User';
            final firstName = displayName.split(' ').first;

            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good ${_getGreeting()},',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: ProfessionalColors.gray600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        firstName,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: ProfessionalColors.gray900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: ProfessionalColors.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ProfessionalColors.primary.withAlpha(51),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: ProfessionalColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM yyyy').format(DateTime.now()),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ProfessionalColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  Widget _buildBalanceOverview() {    return Consumer2<BudgetService, TransactionService>(
      builder: (context, budgetService, transactionService, child) {
        final budget = budgetService.currentBudget;
        final double budgetAmount = budget?['amount']?.toDouble() ?? 0.0;
        final double expenses = transactionService.cachedMonthlyTotal;
        final double balance = budgetAmount - expenses;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Balance Card
            ProfessionalGradientCard(
              gradientColors: balance >= 0
                  ? [ProfessionalColors.success, ProfessionalColors.successLight]
                  : [ProfessionalColors.error, ProfessionalColors.errorLight],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          balance >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          balance >= 0 ? 'On Track' : 'Over Budget',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Current Balance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withAlpha(230),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CurrencyDisplay(
                    amountUSD: balance,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 36,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Budget and Expenses Cards
            Row(
              children: [
                // Budget Card
                Expanded(
                  child: ProfessionalCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ProfessionalIconContainer(
                              icon: Icons.account_balance_wallet_rounded,
                              backgroundColor: ProfessionalColors.primary.withAlpha(26),
                              iconColor: ProfessionalColors.primary,
                              size: 48,
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_upward_rounded,
                              color: ProfessionalColors.success,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Monthly Budget',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ProfessionalColors.gray600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        CurrencyDisplay(
                          amountUSD: budgetAmount,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: ProfessionalColors.gray900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Expenses Card
                Expanded(
                  child: ProfessionalCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ProfessionalIconContainer(
                              icon: Icons.shopping_cart_rounded,
                              backgroundColor: ProfessionalColors.error.withAlpha(26),
                              iconColor: ProfessionalColors.error,
                              size: 48,
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_downward_rounded,
                              color: ProfessionalColors.error,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Total Expenses',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ProfessionalColors.gray600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        CurrencyDisplay(
                          amountUSD: expenses,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: ProfessionalColors.gray900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBudgetProgress() {
    return Consumer2<BudgetService, TransactionService>(
      builder: (context, budgetService, transactionService, child) {
        final budget = budgetService.currentBudget;
        final double budgetAmount = budget?['amount']?.toDouble() ?? 0.0;
        final double expenses = transactionService.cachedMonthlyTotal;
        final double progress = budgetAmount > 0 ? (expenses / budgetAmount).clamp(0.0, 1.0) : 0.0;
        final int percentage = (progress * 100).round();

        final Color progressColor = _getProgressColor(progress);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget Progress',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: ProfessionalColors.gray900,
              ),
            ),
            const SizedBox(height: 24),
            ProfessionalCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: progressColor.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: progressColor.withAlpha(51),
                          ),
                        ),
                        child: Text(
                          '$percentage%',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: progressColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getProgressColor(double progress) {
    if (progress <= 0.7) return ProfessionalColors.success;
    if (progress <= 0.9) return ProfessionalColors.warning;
    return ProfessionalColors.error;
  }

  Map<String, Color> _getCategoryColors(String category) {
    final colorMap = {
      'Food': {'background': const Color(0xFFFEF3C7), 'icon': const Color(0xFFF59E0B)},
      'Transportation': {'background': const Color(0xFFDCFDF7), 'icon': const Color(0xFF10B981)},
      'Entertainment': {'background': const Color(0xFFFCE7F3), 'icon': const Color(0xFFEC4899)},
      'Shopping': {'background': const Color(0xFFEDE9FE), 'icon': const Color(0xFF8B5CF6)},
      'Health': {'background': const Color(0xFFDCFCE7), 'icon': const Color(0xFF22C55E)},
      'Bills': {'background': const Color(0xFFDCF2FF), 'icon': const Color(0xFF3B82F6)},
      'Education': {'background': const Color(0xFFFFF7ED), 'icon': const Color(0xFFF97316)},
      'Travel': {'background': const Color(0xFFF0F9FF), 'icon': const Color(0xFF0EA5E9)},
    };

    return colorMap[category] ?? {
      'background': ProfessionalColors.gray100,
      'icon': ProfessionalColors.gray500,
    };
  }

  Widget _buildCategoryBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Spending by Category',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: ProfessionalColors.gray900,
          ),
        ),
        const SizedBox(height: 16),

        Consumer<TransactionService>(
          builder: (context, transactionService, child) {
            final breakdown = transactionService.cachedCategoryBreakdown;

            if (breakdown.isEmpty) {
              return ProfessionalCard(
                child: ProfessionalEmptyState(
                  icon: Icons.pie_chart_outline_rounded,
                  title: 'No expenses this month',
                  subtitle: 'Add some expenses to see your spending breakdown',
                ),
              );
            }

            final sortedEntries = breakdown.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return ProfessionalCard(
              child: Column(
                children: sortedEntries.take(5).map((entry) {
                  final category = entry.key;
                  final amount = entry.value;
                  final total = breakdown.values.fold(0.0, (sum, value) => sum + value);
                  final percentage = total > 0 ? (amount / total * 100).round() : 0;
                  final categoryColors = _getCategoryColors(category);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Row(
                      children: [
                        Consumer<CategoryService>(
                          builder: (context, categoryService, child) {
                            final categoryIcon = categoryService.getCategoryIcon(category);
                            return ProfessionalIconContainer(
                              icon: categoryIcon,
                              backgroundColor: categoryColors['background']!,
                              iconColor: categoryColors['icon']!,
                              size: 48,
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    category,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: ProfessionalColors.gray900,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: categoryColors['background'],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$percentage%',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: categoryColors['icon'],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: ProfessionalProgressBar(
                                      progress: total > 0 ? amount / total : 0,
                                      color: categoryColors['icon'],
                                      height: 8,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  CurrencyDisplay(
                                    amountUSD: amount,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: ProfessionalColors.gray900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Consumer<TransactionService>(
      builder: (context, transactionService, child) {
        final dailyAverage = transactionService.cachedMonthlyTotal / DateTime.now().day;
        final daysRemaining = _getDaysRemainingInMonth();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Insights',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: ProfessionalColors.gray900,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                // Average Daily Spending
                Expanded(
                  child: ProfessionalCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ProfessionalIconContainer(
                              icon: Icons.trending_up_rounded,
                              backgroundColor: const Color(0xFFFCE7F3),
                              iconColor: const Color(0xFFEC4899),
                              size: 48,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCE7F3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Per Day',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFEC4899),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Daily Average',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ProfessionalColors.gray600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        CurrencyDisplay(
                          amountUSD: dailyAverage,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: ProfessionalColors.gray900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Days Remaining
                Expanded(
                  child: ProfessionalCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ProfessionalIconContainer(
                              icon: Icons.calendar_month_rounded,
                              backgroundColor: const Color(0xFFDCFDF7),
                              iconColor: const Color(0xFF10B981),
                              size: 48,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFDF7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Days',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Days Remaining',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ProfessionalColors.gray600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$daysRemaining',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: ProfessionalColors.gray900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  int _getDaysRemainingInMonth() {
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    return lastDayOfMonth.day - now.day;
  }
}