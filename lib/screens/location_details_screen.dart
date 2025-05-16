import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:map_explorer/logger.dart';
import 'package:map_explorer/utils/location_type_utils.dart';
import 'package:map_explorer/widgets/comment_list_widget.dart';
import 'package:provider/provider.dart';

import '../models/location.dart';
import '../providers/location_data_provider.dart';
import '../widgets/add_comment_widget.dart';
import '../widgets/vote_widget.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;

class LocationDetailsScreen extends StatefulWidget {
  final String locationId;
  
  const LocationDetailsScreen({super.key, required this.locationId});
  
  @override
  LocationDetailsScreenState createState() => LocationDetailsScreenState();
}

class LocationDetailsScreenState extends State<LocationDetailsScreen> {
  bool _showAddComment = false;
  bool _isEditingDescription = false;
  TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
  
  @override
  void initState() {
    super.initState();
    
    // Set a temporary user ID if not set (in a real app, this would come from auth)
    final provider = Provider.of<LocationDataProvider>(context, listen: false);
    if (provider.currentUserId == null) {
      provider.setCurrentUserId('user_${DateTime.now().millisecondsSinceEpoch}');
    }
  }
  
  void _toggleAddComment() {
    setState(() {
      _showAddComment = !_showAddComment;
    });
  }
  
  void _refreshComments() {
    setState(() {
      // This will trigger a rebuild of the CommentsList widget
    });
  }

  // Add this method to LocationDetailsScreenState class
  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('لا يمكن فتح الرابط: $url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في فتح الرابط: $e')),
        );
      }
    }
  }

  // Update the description section in the build method
  Widget _buildDescriptionSection(Location location) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'الوصف',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            // Copy button
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () => _copyToClipboard(location.description),
              tooltip: 'نسخ الوصف',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (location.description.isEmpty)
          Text(
            'لا يوجد وصف',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.right,
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: SelectableLinkify(
              text: location.description,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
              linkStyle: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
              textAlign: TextAlign.right,
              textDirection: ui.TextDirection.rtl,
              onOpen: (link) => _launchUrl(link.url),
              options: const LinkifyOptions(
                humanize: false,
                looseUrl: true,
              ),
            ),
          ),
      ],
    );
  }

  // Add copy to clipboard method
  Future<void> _copyToClipboard(String text) async {
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد نص للنسخ')),
      );
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نسخ الوصف'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في النسخ: $e')),
        );
      }
    }
  }

  Widget _buildTagsSection(Location location) {
    if (location.tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'العلامات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: location.tags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: LocationTypeUtils.getColor(tag).withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: LocationTypeUtils.getColor(tag),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LocationTypeUtils.getIcon(tag),
                    size: 14,
                    color: LocationTypeUtils.getColor(tag),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    LocationTypeUtils.getDisplayName(tag),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: LocationTypeUtils.getColor(tag),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<LocationDataProvider>(
      builder: (context, locationProvider, child) {
        final locations = locationProvider.locations.where(
        (loc) => loc.id == widget.locationId,
      );
      
      if (locations.isEmpty) {
        // Location doesn't exist, navigate back
        return Scaffold(
          appBar: AppBar(title: const Text('موقع غير موجود')),
          body: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'هذا الموقع غير موجود أو تم حذفه',
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
      
      final location = locations.first;
        
        return Scaffold(
          appBar: AppBar(
            title: Text(location.name),
            actions: [
              _buildOptionsMenu(location, locationProvider),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Images gallery at the top
                if (location.images.isNotEmpty)
                  SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        // Image PageView
                        PageView.builder(
                          itemCount: location.images.length,
                          itemBuilder: (context, index) {
                            return Image.network(
                              location!.images[index],
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
                                  child: const Center(
                                    child: Icon(Icons.error, color: Colors.red, size: 50),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        
                        // Image counter indicator
                        if (location.images.length > 1)
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '1/${location.images.length}',  // This is static, ideally would update with current page
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'لا توجد صور',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Location details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // RTL alignment
                    children: [
                      // Type badge with enhanced styling
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: LocationTypeUtils.getColor(location.type),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: LocationTypeUtils.getColor(location.type).withOpacity(0.4),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              location.typeDisplayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              LocationTypeUtils.getIcon(location.type),
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Name with enhanced styling
                      Text(
                        location.name,
                        style: const TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      
                      // Creator info with enhanced styling
                      if (location.creatorName != null && location.creatorName!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                location.creatorName!,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'تمت الإضافة بواسطة:',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),

                      // Date added
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'تمت الإضافة بتاريخ ${DateFormat('MMM d, yyyy').format(location.createdAt)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                      //tags section
                      _buildTagsSection(location),
                      // Description
                      // Check if user is creator of this location
                      if (locationProvider.isLocationCreator(location))
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconButton(
                              icon: Icon(_isEditingDescription ? Icons.check : Icons.edit),
                              onPressed: () {
                                if (_isEditingDescription) {
                                  // Save the updated description
                                  _saveDescription(location, locationProvider);
                                } else {
                                  // Enter edit mode
                                  setState(() {
                                    _descriptionController.text = location!.description;
                                    _isEditingDescription = true;
                                  });
                                }
                              },
                            ),
                            if (_isEditingDescription)
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  // Cancel editing
                                  setState(() {
                                    _isEditingDescription = false;
                                  });
                                },
                              ),
                            Expanded(
                              child: _isEditingDescription 
                                ? TextFormField(
                                    controller: _descriptionController,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      hintText: 'أدخل وصفاً جديداً',
                                    ),
                                    maxLines: 5,
                                    textDirection: ui.TextDirection.rtl,
                                    textAlign: TextAlign.right,
                                  )
                                : _buildDescriptionSection(location),
                            ),
                          ],
                        )
                      else
                        _buildDescriptionSection(location),
                      
                      const SizedBox(height: 16),
                      
                      // Coordinates text
                      Text(
                        'الإحداثيات: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                      
                      // Map showing the location
                      Container(
                        height: 200,
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: location.latLng,
                              initialZoom: 12,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_labels_under/{z}/{x}/{y}{r}.png',
                                subdomains: const ['a', 'b', 'c'],
                                additionalOptions: const {
                                  'attribution': '© OpenStreetMap contributors',
                                },
                                retinaMode: RetinaMode.isHighDensity(context),
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    height: 30,
                                    width: 30,
                                    point: location.latLng,
                                    child: Container(
                                      height: 40,
                                      width: 40,
                                      decoration: BoxDecoration(
                                        color: LocationTypeUtils.getColor(location.type),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 2,
                                            spreadRadius: 0.5,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        LocationTypeUtils.getIcon(location.type),
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
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
                
                // Vote section
                VoteWidget(locationId: widget.locationId),
                
                // Divider
                const Divider(thickness: 1),
                
                // Comments section
                CommentsList(locationId: widget.locationId),
                
                // Add comment button/form
                if (_showAddComment)
                  AddCommentWidget(
                    locationId: widget.locationId,
                    onCommentAdded: _refreshComments,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _toggleAddComment,
                        icon: const Icon(Icons.add_comment),
                        label: const Text('أضف تعليق'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                
                const SizedBox(height: 40), // Bottom padding
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveDescription(Location location, LocationDataProvider provider) async {
    final updatedDescription = _descriptionController.text.trim();
    
    if (updatedDescription.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الوصف لا يمكن أن يكون فارغاً')),
      );
      return;
    }

    if (updatedDescription == location.description) {
      // No changes made, just exit edit mode
      setState(() {
        _isEditingDescription = false;
      });
      return;
    }

    try {
      // Create updated location with new description only
      final updatedLocation = Location(
        id: location.id,
        name: location.name,
        description: updatedDescription,
        type: location.type,
        latitude: location.latitude,
        longitude: location.longitude,
        createdAt: location.createdAt,
        images: location.images,
        createdBy: location.createdBy,
        creatorName: location.creatorName,
      );
      
      // Update the location
      await provider.updateLocation(updatedLocation);
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الوصف بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Exit edit mode
        setState(() {
          _isEditingDescription = false;
        });
        
        // Refresh locations to get updated data
        provider.refreshLocations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث الوصف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteDialog(Location location, LocationDataProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الموقع'),
        content: Text('هل أنت متأكد من أنك تريد حذف موقع "${location.name}"؟\n\nستتم إزالة الموقع وجميع التعليقات والتصويتات المرتبطة به نهائياً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteLocation(location, provider);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLocation(Location location, LocationDataProvider provider) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري حذف الموقع...'),
            ],
          ),
        ),
      );

      // Delete the location
      await provider.deleteLocation(location.id);

      if (mounted) {
        // Close loading dialog first
        Navigator.of(context).pop();
        // await Future.delayed(const Duration(seconds: 5));
        
        // // Simple: just pop back to the first route (MapScreen)
        // Navigator.of(context).popUntil((route) => route.isFirst);
        
        // Show success message
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم حذف الموقع بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
          }
        });

        // Navigate back to map
      Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حذف الموقع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildOptionsMenu(Location location, LocationDataProvider provider) {
    if (!provider.isLocationCreator(location)) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'delete') {
          _showDeleteDialog(location, provider);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('حذف الموقع', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}
