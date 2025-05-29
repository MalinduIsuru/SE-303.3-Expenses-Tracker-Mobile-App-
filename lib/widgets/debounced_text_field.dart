import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebouncedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? prefixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool autofocus;
  final VoidCallback? onChanged;
  final Duration debounceDuration;

  const DebouncedTextField({
    super.key,
    required this.controller,
    this.labelText,
    this.prefixText,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.debounceDuration = const Duration(milliseconds: 500),
  });

  @override
  State<DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<DebouncedTextField> {
  Timer? _debounceTimer;
  String _lastValue = '';

  @override
  void initState() {
    super.initState();
    _lastValue = widget.controller.text;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String value) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Only process if value actually changed
    if (value == _lastValue) return;
    
    // Start new timer
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (mounted && value != _lastValue) {
        _lastValue = value;
        widget.onChanged?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixText: widget.prefixText,
        border: const OutlineInputBorder(),
      ),
      keyboardType: widget.keyboardType,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      onChanged: _onTextChanged,
    );
  }
}
