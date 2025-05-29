import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/professional_ui_components.dart';
import 'dashboard_tab.dart';
import 'transactions_tab.dart';
import 'add_expense_tab.dart';
import 'budget_tab.dart';
import 'profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    DashboardTab(),
    TransactionsTab(),
    AddExpenseTab(),
    BudgetTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfessionalColors.background,
      // Add floating network status indicator
      floatingActionButtonLocation: FloatingActionButtonLocation.miniStartTop,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 40.0),
        child: Consumer<ConnectivityService>(
          builder: (context, connectivity, _) {
            if (connectivity.isOnline) {
              return const SizedBox.shrink();
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(230),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, size: 14, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('OFFLINE', style: TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(width: 4),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => connectivity.forceReconnect(),
                    child: const Text('Try Connect', style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      // Wrap the body in SafeArea to avoid system UI overlaps
      body: SafeArea(
        bottom: false, // We handle bottom safe area in the navigation bar
        child: _tabs[_currentIndex],
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom > 0 ? 8 : 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildNavItem(0, Icons.grid_view_rounded, 'Dashboard')),
              Expanded(child: _buildNavItem(1, Icons.receipt_long_rounded, 'Transactions')),
              Expanded(child: _buildAddButton()),
              Expanded(child: _buildNavItem(3, Icons.account_balance_wallet_rounded, 'Budget')),
              Expanded(child: _buildNavItem(4, Icons.person_rounded, 'Profile')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? ProfessionalColors.primary.withAlpha(26)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? ProfessionalColors.primary
                    : ProfessionalColors.gray400,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? ProfessionalColors.primary
                    : ProfessionalColors.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 2),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ProfessionalColors.primary,
              ProfessionalColors.primaryLight,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: ProfessionalColors.primary.withAlpha(77),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}