// filepath: e:\Project\lib\screens\home\add_expense_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/category_service.dart';
import '../../services/transaction_service.dart';
import '../../widgets/debounced_text_field.dart';
import '../../widgets/professional_ui_components.dart';
import 'package:intl/intl.dart';

class AddExpenseTab extends StatefulWidget {
  const AddExpenseTab({super.key});

  @override
  State<AddExpenseTab> createState() => _AddExpenseTabState();
}

class _AddExpenseTabState extends State<AddExpenseTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  String _selectedCategoryId = '';
  bool _isSubmitting = false;
  bool _showSuccess = false;

  String _getMonthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }
  
  @override
  void initState() {
    super.initState();
    // Set default category to the first one when loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoryService = Provider.of<CategoryService>(context, listen: false);
      if (categoryService.categories.isNotEmpty) {
        setState(() {
          _selectedCategoryId = categoryService.categories.first.id;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Validates and submits the new expense
  Future<void> _submitExpense() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedCategoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
      _showSuccess = false;
    });
      // Capture the context before async operation
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final amount = double.parse(_amountController.text.replaceAll(RegExp(r'[^\d\.]'), ''));
      
      // Get the transaction service
      final transactionService = Provider.of<TransactionService>(context, listen: false);

      // Create transaction data
      final String transactionId = DateTime.now().millisecondsSinceEpoch.toString();
      final Map<String, dynamic> transactionData = {
        'id': transactionId,
        'amount': amount,
        'description': _descriptionController.text.trim(),
        'category': _selectedCategoryId,
        'timestamp': DateTime.now(),
        'monthYear': _getMonthKey(DateTime.now()),
      };
      
      // Add the expense
      await transactionService.addTransaction(transactionData);
      
      // Clear form on success
      _amountController.clear();
      _descriptionController.clear();
      
      setState(() {
        _isSubmitting = false;
        _showSuccess = true;
      });
      
      // Reset success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showSuccess = false;
          });
        }
      });
    } catch (e) {      setState(() {
        _isSubmitting = false;
      });
      
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryService = Provider.of<CategoryService>(context);
    final transactionService = Provider.of<TransactionService>(context);
    
    return Scaffold(
      backgroundColor: ProfessionalColors.background,
      appBar: AppBar(
        title: const Text('Add Expense'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: ProfessionalColors.gray800,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form Container
              ProfessionalCard(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount Input
                      const Text('Amount', style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ProfessionalColors.gray700,
                      )),
                      const SizedBox(height: 8),
                      DebouncedTextField(
                        controller: _amountController,
                        prefixText: '\$ ',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          if (double.tryParse(value.replaceAll(RegExp(r'[^\d\.]'), '')) == null) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                        autofocus: true,
                        debounceDuration: const Duration(milliseconds: 300),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Category Selection
                      const Text('Category', style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ProfessionalColors.gray700,
                      )),
                      const SizedBox(height: 8),
                      categoryService.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: categoryService.categories.map((category) {
                                final isSelected = category.id == _selectedCategoryId;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedCategoryId = category.id;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? ProfessionalColors.primary : ProfessionalColors.gray100,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected ? ProfessionalColors.primary : ProfessionalColors.gray300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          category.icon,
                                          size: 16,
                                          color: isSelected ? Colors.white : ProfessionalColors.gray700,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          category.name,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : ProfessionalColors.gray700,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                      
                      const SizedBox(height: 20),
                      
                      // Description Input
                      const Text('Description (Optional)', style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ProfessionalColors.gray700,
                      )),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          hintText: 'Enter description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitExpense,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ProfessionalColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Add Expense'),
                        ),
                      ),
                      
                      // Success Message
                      if (_showSuccess)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ProfessionalColors.successLight.withAlpha(51),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: ProfessionalColors.success,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: ProfessionalColors.success,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Expense added successfully!',
                                style: TextStyle(
                                  color: ProfessionalColors.success,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Monthly Summary
              ProfessionalCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This Month',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ProfessionalColors.gray800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Expenses:',
                          style: TextStyle(
                            fontSize: 16,
                            color: ProfessionalColors.gray600,
                          ),
                        ),
                        Text(
                          '\$${NumberFormat("#,##0.00").format(transactionService.cachedMonthlyTotal)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ProfessionalColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Top Category:',
                          style: TextStyle(
                            fontSize: 16,
                            color: ProfessionalColors.gray600,
                          ),
                        ),
                        _buildTopCategoryChip(
                          transactionService.cachedCategoryBreakdown,
                          categoryService.categories,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTopCategoryChip(
    Map<String, double> categoryBreakdown,
    List<CategoryModel> allCategories,
  ) {
    if (categoryBreakdown.isEmpty) {
      return const Text('None yet', style: TextStyle(fontStyle: FontStyle.italic));
    }
    
    // Find top category
    final sortedCategories = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    if (sortedCategories.isEmpty) {
      return const Text('None yet', style: TextStyle(fontStyle: FontStyle.italic));
    }
    
    final topCategoryId = sortedCategories.first.key;
    final categoryModel = allCategories.firstWhere(
      (cat) => cat.id == topCategoryId,
      orElse: () => CategoryModel(id: 'unknown', name: 'Unknown', icon: Icons.help_outline),
    );
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ProfessionalColors.primaryLight.withAlpha(51),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            categoryModel.icon,
            size: 16,
            color: ProfessionalColors.primaryDark,
          ),
          const SizedBox(width: 4),
          Text(
            categoryModel.name,
            style: const TextStyle(
              color: ProfessionalColors.primaryDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}