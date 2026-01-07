import 'package:flutter/material.dart';

class CustomRadioGroup<T> extends StatefulWidget {
  final List<RadioItem<T>> children;
  final T? initialValue;
  final ValueChanged<T?>? onChanged;

  const CustomRadioGroup({
    super.key,
    required this.children,
    this.initialValue,
    this.onChanged,
  });

  @override
  State<CustomRadioGroup<T>> createState() => _CustomRadioGroupState<T>();
}

class _CustomRadioGroupState<T> extends State<CustomRadioGroup<T>> {
  T? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue;
  }

  @override
  void didUpdateWidget(CustomRadioGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _selectedValue = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Avoid `RadioListTile` and even `Radio` here because (on some Flutter
    // versions) the old radio selection API is deprecated in favor of
    // `RadioGroup`.
    //
    // This implementation keeps behavior identical without depending on those
    // deprecated members.
    return Column(
      children: widget.children.map((item) {
        final isSelected = _selectedValue == item.value;
        return InkWell(
          onTap: () {
            setState(() {
              _selectedValue = item.value;
            });
            widget.onChanged?.call(item.value);
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
            title: Text(item.label),
            leading: _RadioIndicator(selected: isSelected),
            selected: isSelected,
          ),
        );
      }).toList(),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  final bool selected;

  const _RadioIndicator({required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = selected ? scheme.primary : scheme.outline;
    final fillColor = selected ? scheme.primary : Colors.transparent;

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: fillColor),
      ),
    );
  }
}

class RadioItem<T> {
  final T value;
  final String label;

  const RadioItem({required this.value, required this.label});
}
