import 'package:flutter/material.dart';
import '../models/location.dart';
import '../utils/location_type_utils.dart';
import 'filter_option_widget.dart';

class LocationFilterDialog extends StatefulWidget {
  final Map<LocationType, bool> filterSettings;
  final Function(Map<LocationType, bool>) onApply;

  const LocationFilterDialog({
    Key? key,
    required this.filterSettings,
    required this.onApply,
  }) : super(key: key);

  @override
  _LocationFilterDialogState createState() => _LocationFilterDialogState();
}

class _LocationFilterDialogState extends State<LocationFilterDialog> {
  late Map<LocationType, bool> _currentSettings;

  @override
  void initState() {
    super.initState();
    // Create a copy of the settings to work with
    _currentSettings = Map.from(widget.filterSettings);
  }

  void _setAllFilters(bool value) {
    setState(() {
      for (var type in LocationType.values) {
        _currentSettings[type] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'تصفية المواقع',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                // Quick action buttons
                TextButton(
                  onPressed: () => _setAllFilters(true),
                  child: const Text('الكل'),
                ),
                TextButton(
                  onPressed: () => _setAllFilters(false),
                  child: const Text('لا شيء'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Dynamically create all filter options
            ...LocationType.values.map((type) => 
              FilterOptionWidget(
                locationType: type,
                isSelected: _currentSettings[type] ?? true,
                onChanged: (value) {
                  setState(() {
                    _currentSettings[type] = value ?? true;
                  });
                },
              ),
            ),

            // Apply button
            Center(
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_currentSettings);
                  Navigator.pop(context);
                },
                child: const Text('تطبيق الفلتر'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
