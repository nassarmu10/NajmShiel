import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:map_explorer/models/comment.dart';
import 'package:map_explorer/providers/location_data_provider.dart';

class AddCommentWidget extends StatefulWidget {
  final String locationId;
  final Function() onCommentAdded;
  
  const AddCommentWidget({
    Key? key,
    required this.locationId,
    required this.onCommentAdded,
  }) : super(key: key);

  @override
  _AddCommentWidgetState createState() => _AddCommentWidgetState();
}

class _AddCommentWidgetState extends State<AddCommentWidget> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  XFile? _selectedImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      
      if (photo != null) {
        setState(() {
          _selectedImage = photo;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking photo: $e')),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _submitComment() async {
    // Validate input
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment')),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final locationProvider = Provider.of<LocationDataProvider>(context, listen: false);
      
      // Upload image to Cloudinary if selected
      String? imageUrl;
      if (_selectedImage != null) {
        final cloudinary = CloudinaryPublic(
          'dchx2vghg',  // Replace with your cloud name
          'location_comments',  // Replace with your upload preset name
          cache: false,
        );
        
        final cloudinaryFile = CloudinaryFile.fromFile(
          _selectedImage!.path,
          folder: 'location_comments',
          resourceType: CloudinaryResourceType.Image,
        );
        
        final response = await cloudinary.uploadFile(cloudinaryFile);
        imageUrl = response.secureUrl;
      }

      // Create comment
      final comment = Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        locationId: widget.locationId,
        userId: locationProvider.currentUserId ?? 'anonymous',
        username: _nameController.text.trim(),
        content: _commentController.text.trim(),
        createdAt: DateTime.now(),
        imageUrl: imageUrl,
      );

      // Add comment to database
      await locationProvider.addComment(comment);
      
      // Clear form
      _commentController.clear();
      setState(() {
        _selectedImage = null;
      });
      
      // Notify parent
      widget.onCommentAdded();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أضف تعليقك',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسمك',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                alignLabelWithHint: true,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              maxLength: 50,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'التعليق',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.comment),
                alignLabelWithHint: true,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'إضافة صورة (اختياري):',
                  textDirection: TextDirection.rtl,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.photo_library),
                  onPressed: _isSubmitting ? null : _pickImage,
                  tooltip: 'Pick from gallery',
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: _isSubmitting ? null : _takePhoto,
                  tooltip: 'Take a photo',
                ),
              ],
            ),
            if (_selectedImage != null)
              Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    height: 150,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_selectedImage!.path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        onPressed: _isSubmitting ? null : _removeImage,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitComment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isSubmitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('جاري النشر...'),
                      ],
                    )
                  : const Text('نشر التعليق'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
