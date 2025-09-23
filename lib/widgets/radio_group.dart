import 'package:flutter/material.dart';

class CustomRadioGroup<T> extends StatelessWidget {
  final T groupValue;
  final ValueChanged<T?> onChanged;
  final List<RadioItem<T>> children;

  const CustomRadioGroup({
    super.key,
    required this.groupValue,
    required this.onChanged,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: children.map((child) {
        return InkWell(
          onTap: () => onChanged(child.value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Radio<T>(
                  value: child.value,
                  groupValue: groupValue,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 8),
                Text(child.label),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class RadioItem<T> {
  final T value;
  final String label;

  const RadioItem({
    required this.value,
    required this.label,
  });
}
