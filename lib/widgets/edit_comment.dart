import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:map_explorer/models/comment.dart';
import 'package:map_explorer/providers/location_data_provider.dart';

class EditCommentWidget extends StatefulWidget {
  final Comment comment;
  final Function() onCommentUpdated;
  
  const EditCommentWidget({
    Key? key,
    required this.comment,
    required this.onCommentUpdated,
  }) : super(key: key);

  @override
  EditCommentWidgetState createState() => EditCommentWidgetState();
}

class EditCommentWidgetState extends State<EditCommentWidget> {
  final TextEditingController _commentController = TextEditingController();
  XFile? _selectedImage;
  String? _existingImageUrl;
  bool _isSubmitting = false;
  bool _keepExistingImage = true;

  @override
  void initState() {
    super.initState();
    _commentController.text = widget.comment.content;
    _existingImageUrl = widget.comment.imageUrl;
  }

  @override
  void dispose() {
    _commentController.dispose();
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
          _keepExistingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
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
          _keepExistingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      if (_selectedImage != null) {
        _selectedImage = null;
      } else {
        _keepExistingImage = false;
        _existingImageUrl = null;
      }
    });
  }

  Future<void> _updateComment() async {
    // Validate input
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال تعليق')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final locationProvider = Provider.of<LocationDataProvider>(context, listen: false);
      
      // Determine final image URL
      String? imageUrl;
      
      // Keep existing image
      if (_keepExistingImage && _existingImageUrl != null) {
        imageUrl = _existingImageUrl;
      } 
      // Upload new image
      else if (_selectedImage != null) {
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
      // No image case - imageUrl will remain null

      // Create updated comment
      final updatedComment = Comment(
        id: widget.comment.id,
        locationId: widget.comment.locationId,
        userId: widget.comment.userId,
        username: widget.comment.username,
        content: _commentController.text.trim(),
        createdAt: widget.comment.createdAt,
        imageUrl: imageUrl,
      );

      // Update comment in database
      if (mounted) {
        await locationProvider.updateComment(updatedComment);
        
        // Notify parent
        widget.onCommentUpdated();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث التعليق بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Close the edit dialog
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحديث التعليق: $e')),
        );
      }
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'تعديل التعليق',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
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
                'الصورة:',
                textDirection: TextDirection.rtl,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.photo_library),
                onPressed: _isSubmitting ? null : _pickImage,
                tooltip: 'اختيار من المعرض',
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt),
                onPressed: _isSubmitting ? null : _takePhoto,
                tooltip: 'التقاط صورة',
              ),
            ],
          ),
          
          // Show existing image
          if (_keepExistingImage && _existingImageUrl != null)
            Stack(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  height: 150,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _existingImageUrl!,
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
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
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
            
          // Show newly selected image
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
                    decoration: const BoxDecoration(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _updateComment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('حفظ التعديلات'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
