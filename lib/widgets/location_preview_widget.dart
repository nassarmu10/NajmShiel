// lib/widgets/location_preview_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map_explorer/models/location.dart';
import 'package:map_explorer/utils/location_type_utils.dart';
import 'dart:ui' as ui show TextDirection;

class LocationPreviewWidget extends StatelessWidget {
  final Location location;
  final VoidCallback onTap;
  final VoidCallback onClose;
  
  const LocationPreviewWidget({
    Key? key,
    required this.location,
    required this.onTap,
    required this.onClose,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: isLandscape ? 100 : 140,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              textDirection: ui.TextDirection.rtl, // RTL for Arabic
              children: [
                // Image section
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: SizedBox(
                    width: 120,
                    height: double.infinity,
                    child: location.images.isNotEmpty
                        ? Image.network(
                            location.images.first,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: Icon(
                                  LocationTypeUtils.getIcon(location.type),
                                  color: LocationTypeUtils.getColor(location.type),
                                  size: 40,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: Icon(
                              LocationTypeUtils.getIcon(location.type),
                              color: LocationTypeUtils.getColor(location.type),
                              size: 40,
                            ),
                          ),
                  ),
                ),
                
                // Info section
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Title and type
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          textDirection: ui.TextDirection.rtl,
                          children: [
                            // Location name with ellipsis if too long
                            Expanded(
                              child: Text(
                                location.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Type badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: LocationTypeUtils.getColor(location.type),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                LocationTypeUtils.getDisplayName(location.type),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Description with limited lines
                        Text(
                          location.description.isEmpty ? 'لا يوجد وصف' : location.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: location.description.isEmpty ? Colors.grey : Colors.black87,
                            fontStyle: location.description.isEmpty ? FontStyle.italic : FontStyle.normal,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                        
                        const Spacer(),
                        
                        // Date and view details hint
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          textDirection: ui.TextDirection.rtl,
                          children: [
                            // Date added
                            Text(
                              DateFormat('MMM d, yyyy').format(location.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            
                            // View details hint
                            Row(
                              children: [
                                Text(
                                  'عرض التفاصيل',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_back_ios,
                                  size: 12,
                                  color: Colors.blue[700],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: GestureDetector(
            onTap: onClose,  // Just call the callback function
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.close,
                size: 20,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
