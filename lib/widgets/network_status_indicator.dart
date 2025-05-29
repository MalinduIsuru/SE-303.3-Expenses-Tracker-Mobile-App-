import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import 'professional_ui_components.dart';

class NetworkStatusIndicator extends StatelessWidget {
  final bool mini;
  
  const NetworkStatusIndicator({
    super.key, 
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    final connectivityService = context.watch<ConnectivityService>();
    final isOnline = connectivityService.isOnline;
        
    if (mini) {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOnline ? ProfessionalColors.success : ProfessionalColors.error,
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: isOnline 
            ? ProfessionalColors.success.withAlpha(25)
            : ProfessionalColors.error.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline 
              ? ProfessionalColors.success.withAlpha(77)
              : ProfessionalColors.error.withAlpha(77),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? ProfessionalColors.success : ProfessionalColors.error,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isOnline ? ProfessionalColors.success : ProfessionalColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class ConnectionAwareButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final String tooltipWhenOffline;
  
  const ConnectionAwareButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.tooltipWhenOffline = 'This action requires an internet connection',
  });

  @override
  Widget build(BuildContext context) {
    final connectivityService = context.watch<ConnectivityService>();
    final isOnline = connectivityService.isOnline;
        
    if (isOnline) {
      return FilledButton(
        onPressed: onPressed,
        child: child,
      );
    }
    
    return Tooltip(
      message: tooltipWhenOffline,
      child: FilledButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tooltipWhenOffline),
              behavior: SnackBarBehavior.floating,
              backgroundColor: ProfessionalColors.warning,
              action: SnackBarAction(
                label: 'Try Again',
                textColor: Colors.white,
                onPressed: () => connectivityService.forceReconnect(),
              ),
            ),
          );
        },
        style: FilledButton.styleFrom(
          backgroundColor: Colors.grey,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(width: 8),
            const Icon(Icons.wifi_off, size: 16),
          ],
        ),
      ),
    );
  }
}
