import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HoverTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final Widget? suffix;

  const HoverTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.obscure = false,
    this.keyboardType,
    this.inputFormatters,
    this.errorText,
    this.suffix,
  });

  @override
  State<HoverTextField> createState() => _HoverTextFieldState();
}

class _HoverTextFieldState extends State<HoverTextField> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final base = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );

    final hover = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.55)),
    );

    final focused = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: scheme.primary, width: 1.4),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        enableSuggestions: !widget.obscure,
        autocorrect: !widget.obscure,
        style: TextStyle(fontSize: 13, color: scheme.onSurface),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          errorText: widget.errorText,
          suffixIcon: widget.suffix,
          filled: true,
          fillColor: scheme.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: _hovered ? hover : base,
          focusedBorder: focused,
        ),
      ),
    );
  }
}
