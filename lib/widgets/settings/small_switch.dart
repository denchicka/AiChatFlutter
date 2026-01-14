import 'package:flutter/material.dart';

class SmallSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const SmallSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.86,
      child: Switch.adaptive(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
