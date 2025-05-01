import 'package:flutter/material.dart';
import '../models/location.dart';
import '../utils/location_type_utils.dart';

class FilterOptionWidget extends StatelessWidget {
  final LocationType locationType;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;
  final String? customLabel;

  const FilterOptionWidget({
    Key? key,
    required this.locationType,
    required this.isSelected,
    required this.onChanged,
    this.customLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Row(
        children: [
          Icon(
            LocationTypeUtils.getIcon(locationType),
            color: LocationTypeUtils.getColor(locationType),
          ),
          const SizedBox(width: 8),
          Text(
            customLabel ?? LocationTypeUtils.getDisplayName(locationType),
            textAlign: TextAlign.right,
          ),
        ],
      ),
      value: isSelected,
      onChanged: onChanged,
      dense: true,
    );
  }
}
