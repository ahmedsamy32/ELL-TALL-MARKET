import 'package:flutter/material.dart';

class CustomSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final int divisions;
  final String? label;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool showValue;

  const CustomSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.onChangeEnd,
    this.divisions = 100,
    this.label,
    this.activeColor,
    this.inactiveColor,
    this.showValue = true,
  });

  @override
  _CustomSliderState createState() => _CustomSliderState();
}

class _CustomSliderState extends State<CustomSlider> {
  double _currentValue = 0;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _currentValue,
                min: widget.min,
                max: widget.max,
                divisions: widget.divisions,
                onChanged: (value) {
                  setState(() {
                    _currentValue = value;
                  });
                  widget.onChanged(value);
                },
                onChangeEnd: widget.onChangeEnd,
                activeColor:
                    widget.activeColor ?? Theme.of(context).primaryColor,
                inactiveColor: widget.inactiveColor ?? Colors.grey[300],
              ),
            ),
            if (widget.showValue) ...[
              SizedBox(width: 16),
              Text(
                _currentValue.toStringAsFixed(0),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class RangeSliderWidget extends StatefulWidget {
  final RangeValues values;
  final double min;
  final double max;
  final ValueChanged<RangeValues> onChanged;
  final int divisions;
  final String? label;
  final bool showValues;

  const RangeSliderWidget({
    super.key,
    required this.values,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.divisions = 100,
    this.label,
    this.showValues = true,
  });

  @override
  _RangeSliderWidgetState createState() => _RangeSliderWidgetState();
}

class _RangeSliderWidgetState extends State<RangeSliderWidget> {
  RangeValues _currentValues = RangeValues(0, 100);

  @override
  void initState() {
    super.initState();
    _currentValues = widget.values;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
        ],
        RangeSlider(
          values: _currentValues,
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          onChanged: (values) {
            setState(() {
              _currentValues = values;
            });
            widget.onChanged(values);
          },
          labels: RangeLabels(
            _currentValues.start.toStringAsFixed(0),
            _currentValues.end.toStringAsFixed(0),
          ),
        ),
        if (widget.showValues)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentValues.start.toStringAsFixed(0)} ج.م',
                style: TextStyle(fontSize: 12),
              ),
              Text(
                '${_currentValues.end.toStringAsFixed(0)} ج.م',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
      ],
    );
  }
}

class RatingSlider extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onRatingChanged;
  final int itemCount;
  final double itemSize;
  final bool allowHalfRating;

  const RatingSlider({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.itemCount = 5,
    this.itemSize = 30,
    this.allowHalfRating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(itemCount, (index) {
            final ratingValue = index + 1;
            return GestureDetector(
              onTap: () {
                onRatingChanged(
                  allowHalfRating
                      ? ratingValue.toDouble()
                      : ratingValue.toDouble(),
                );
              },
              child: Icon(
                rating >= ratingValue
                    ? Icons.star
                    : rating > ratingValue - 0.5 && allowHalfRating
                    ? Icons.star_half
                    : Icons.star_border,
                size: itemSize,
                color: Colors.amber,
              ),
            );
          }),
        ),
        SizedBox(height: 8),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class VolumeSlider extends StatefulWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final Color? iconColor;

  const VolumeSlider({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
    this.iconColor,
  });

  @override
  _VolumeSliderState createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  double _currentVolume = 0;

  @override
  void initState() {
    super.initState();
    _currentVolume = widget.volume;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.volume_mute, color: widget.iconColor),
        Expanded(
          child: Slider(
            value: _currentVolume,
            min: 0,
            max: 1,
            onChanged: (value) {
              setState(() {
                _currentVolume = value;
              });
              widget.onVolumeChanged(value);
            },
          ),
        ),
        Icon(Icons.volume_up, color: widget.iconColor),
      ],
    );
  }
}
