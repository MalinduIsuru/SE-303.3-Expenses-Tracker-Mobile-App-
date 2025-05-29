import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/category_service.dart';
import '../../widgets/professional_ui_components.dart';
import '../../widgets/currency_display.dart';

class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  String _selectedCategory = 'All';
  String _selectedDateFilter = 'This Month';

  final List<String> _dateFilters = [
    'This Month',
    'Last Month',
    'Last 3 Months',
    'All Time',
  ];

  String _getMonthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  List<String> _getMonthKeysForFilter() {
    final now = DateTime.now();
    switch (_selectedDateFilter) {
      case 'This Month':
        return [_getMonthKey(now)];
      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1);
        return [_getMonthKey(lastMonth)];
      case 'Last 3 Months':
        return List.generate(3, (index) {
          final date = DateTime(now.year, now.month - index);
          return _getMonthKey(date);
        });
      case 'All Time':
      default:
        return [];
    }
  }

  Query _buildQuery() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('transactions');

    // Apply date filter
    if (_selectedDateFilter != 'All Time') {
      final monthKeys = _getMonthKeysForFilter();
      if (monthKeys.isNotEmpty) {
        query = query.where('monthYear', whereIn: monthKeys);
      }
    }

    // Apply category filter
    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }    // Order by timestamp descending (newest first)
    return query.orderBy('timestamp', descending: true);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfessionalColors.background,
      body: Column(
        children: [
          // Professional Header
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: ProfessionalColors.gray200,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Transactions',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ProfessionalColors.gray900,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            Icons.filter_list_rounded,
                            size: 16,
                            color: ProfessionalColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Filters',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: ProfessionalColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Filter by Category
                Text(
                  'Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ProfessionalColors.gray700,
                  ),
                ),
                const SizedBox(height: 12),
                Consumer<CategoryService>(
                  builder: (context, categoryService, child) {
                    if (categoryService.isLoading) {
                      return const SizedBox(
                        height: 60,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    // Create categories list with "All" option
                    final allCategories = [
                      CategoryModel(id: 'all', name: 'All', icon: Icons.grid_view_rounded),
                      ...categoryService.categories,
                    ];

                    return SizedBox(
                      height: 48,  // Reduced height
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        itemCount: allCategories.length,
                        itemBuilder: (context, index) {
                          final category = allCategories[index];
                          final isSelected = category.name == _selectedCategory;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),  // Reduced padding
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = category.name;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),  // Reduced padding
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? ProfessionalColors.primary
                                      : ProfessionalColors.gray100,
                                  borderRadius: BorderRadius.circular(12),  // Slightly reduced radius
                                  border: Border.all(
                                    color: isSelected
                                        ? ProfessionalColors.primary
                                        : ProfessionalColors.gray200,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      category.icon,
                                      size: 16,  // Slightly reduced icon size
                                      color: isSelected
                                          ? Colors.white
                                          : ProfessionalColors.gray600,
                                    ),
                                    const SizedBox(width: 6),  // Reduced spacing
                                    Text(
                                      category.name,
                                      style: TextStyle(
                                        fontSize: 13,  // Reduced font size
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : ProfessionalColors.gray700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Filter by Date
                Text(
                  'Time Period',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ProfessionalColors.gray700,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: _dateFilters.length,
                    itemBuilder: (context, index) {
                      final filter = _dateFilters[index];
                      final isSelected = filter == _selectedDateFilter;

                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDateFilter = filter;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? ProfessionalColors.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? ProfessionalColors.primary
                                    : ProfessionalColors.gray300,
                              ),
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : ProfessionalColors.gray700,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Transaction List
          Expanded(
            child: _buildTransactionList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ProfessionalEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Error loading transactions',
            subtitle: 'Please try again later',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final transactions = snapshot.data?.docs ?? [];

        if (transactions.isEmpty) {
          return ProfessionalEmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'No transactions found',
            subtitle: _selectedCategory != 'All' || _selectedDateFilter != 'This Month'
                ? 'Try adjusting your filters to see more transactions'
                : 'Add your first expense to get started',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20.0),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final doc = transactions[index];
            final data = doc.data() as Map<String, dynamic>;

            return _buildTransactionItem(data, doc.id);
          },
        );
      },
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> data, String docId) {
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final description = data['description'] as String? ?? 'No description';
    final category = data['category'] as String? ?? 'Other';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    return ProfessionalCard(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          // Category Icon
          Consumer<CategoryService>(
            builder: (context, categoryService, child) {
              final categoryIcon = categoryService.getCategoryIcon(category);
              final categoryColors = _getCategoryColors(category);

              return ProfessionalIconContainer(
                icon: categoryIcon,
                backgroundColor: categoryColors['background']!,
                iconColor: categoryColors['icon']!,
                size: 56,
              );
            },
          ),

          const SizedBox(width: 16),

          // Transaction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ProfessionalColors.gray900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ProfessionalColors.gray100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ProfessionalColors.gray600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: ProfessionalColors.gray400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ProfessionalColors.gray500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '-',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ProfessionalColors.error,
                    ),
                  ),
                  CurrencyDisplay(
                    amountUSD: amount,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ProfessionalColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ProfessionalColors.error.withAlpha(26),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Expense',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ProfessionalColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today ${DateFormat('HH:mm').format(date)}';
    } else if (transactionDate == yesterday) {
      return 'Yesterday ${DateFormat('HH:mm').format(date)}';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE HH:mm').format(date);
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }
}
