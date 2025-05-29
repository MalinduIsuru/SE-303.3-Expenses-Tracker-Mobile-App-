import 'package:flutter/material.dart';
import 'professional_ui_components.dart';

// This is a helper widget to standardize tab layouts and fix rendering issues
class ScaffoldTab extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final bool useSafeArea;
  final EdgeInsetsGeometry padding;
  
  const ScaffoldTab({
    super.key,
    required this.child,
    this.backgroundColor,
    this.useSafeArea = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: child,
    );
    
    return Scaffold(
      backgroundColor: backgroundColor ?? ProfessionalColors.background,
      body: useSafeArea ? SafeArea(child: content) : content,
    );
  }
}
