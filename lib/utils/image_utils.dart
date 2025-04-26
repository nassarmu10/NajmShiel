import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:map_explorer/logger.dart';

/// Utility class for handling image operations throughout the app
class ImageUtils {
  /// Compress and validate image size
  /// Returns a compressed XFile or null if compression fails or image is too large
  static Future<XFile?> compressAndValidateImage(
    XFile originalImage, 
    {
      BuildContext? context,
      int maxSizeKB = 1024,  // Default max size is 1MB
      int minWidth = 800,
      int minHeight = 800,
    }
  ) async {
    try {
      // Check file size before compression
      final File originalFile = File(originalImage.path);
      final int originalSize = await originalFile.length();
      
      // If the file is already small enough, just return it
      if (originalSize <= 500 * 1024) { // 500KB
        return originalImage;
      }
      
      // Create a temporary directory to store compressed images
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Calculate target quality based on file size
      int quality = 70; // Default quality
      if (originalSize > 3 * 1024 * 1024) { // > 3MB
        quality = 50;
      } else if (originalSize > 1 * 1024 * 1024) { // > 1MB
        quality = 60;
      }
      
      // Compress the image
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        originalImage.path,
        targetPath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        rotate: 0,
      );
      
      if (compressedFile == null) {
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'فشل ضغط الصورة، يرجى المحاولة مرة أخرى.',
                textAlign: TextAlign.right,
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }
      
      // Check if the compressed file is still over max size
      final fileSize = await compressedFile.length();
      final maxSize = maxSizeKB * 1024;
      
      // If still too large, compress again with lower quality
      if (fileSize > maxSize) {
        final secondTargetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_2.jpg';
        final secondCompressedFile = await FlutterImageCompress.compressAndGetFile(
          compressedFile.path,
          secondTargetPath,
          quality: 40, // Lower quality for second pass
          minWidth: minWidth - 200, // Smaller dimensions
          minHeight: minHeight - 200,
        );
        
        if (secondCompressedFile == null) {
          return XFile(compressedFile.path); // Return first compression if second fails
        }
        
        // Check final size
        final finalSize = await secondCompressedFile.length();
        if (finalSize > maxSize) {
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'الصورة كبيرة جدًا حتى بعد الضغط. يرجى اختيار صورة أصغر.',
                  textAlign: TextAlign.right,
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return null;
        }
        
        return XFile(secondCompressedFile.path);
      }
      
      // Return compressed image as XFile
      return XFile(compressedFile.path);
    } catch (e) {
      logger.e('Error compressing image: $e');
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في معالجة الصورة: $e')),
        );
      }
      return null;
    }
  }

  /// Pick multiple images from gallery
  /// Returns a list of compressed image XFiles
  static Future<List<XFile>> pickAndCompressMultipleImages(
    BuildContext context, 
    {int maxSizeKB = 1024}
  ) async {
    final List<XFile> resultImages = [];
    final ImagePicker picker = ImagePicker();
    
    try {
      final List<XFile> selectedImages = await picker.pickMultiImage();
      if (selectedImages.isEmpty) {
        return [];
      }
      
      // Process each image
      for (var image in selectedImages) {
        final compressedImage = await compressAndValidateImage(
          image, 
          context: context,
          maxSizeKB: maxSizeKB
        );
        
        if (compressedImage != null) {
          resultImages.add(compressedImage);
        }
      }
      
      return resultImages;
    } catch (e) {
      logger.e('Error picking images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في اختيار الصور: $e')),
      );
      return [];
    }
  }

  /// Take photo from camera
  /// Returns a compressed image XFile or null
  static Future<XFile?> takeAndCompressPhoto(
    BuildContext context, 
    {int maxSizeKB = 1024}
  ) async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      
      if (photo == null) {
        return null;
      }
      
      final compressedPhoto = await compressAndValidateImage(
        photo, 
        context: context,
        maxSizeKB: maxSizeKB
      );
      
      return compressedPhoto;
    } catch (e) {
      logger.e('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في التقاط الصورة: $e')),
      );
      return null;
    }
  }

  /// Upload image to Cloudinary
  /// Returns the secure URL of the uploaded image or null if upload fails
  static Future<String?> uploadToCloudinary(
    XFile image, 
    {
      required BuildContext context,
      required String cloudName,
      required String uploadPreset,
      required String folder,
      int maxRetries = 3,
    }
  ) async {
    try {
      // Show uploading image indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري تحميل الصورة...'),
          duration: Duration(seconds: 3),
        ),
      );

      final cloudinary = CloudinaryPublic(
        cloudName,
        uploadPreset,
        cache: false,
      );
      
      // Set additional options for the upload
      final cloudinaryFile = CloudinaryFile.fromFile(
        image.path,
        folder: folder,
        resourceType: CloudinaryResourceType.Image,
        // Add these options to improve upload reliability
        tags: [folder],
      );
      
      // Upload to Cloudinary with retry
      CloudinaryResponse? response;
      int retryCount = 0;
      
      while (response == null && retryCount <= maxRetries) {
        try {
          response = await cloudinary.uploadFile(cloudinaryFile);
        } catch (uploadError) {
          logger.e('Cloudinary upload attempt $retryCount failed: $uploadError');
          retryCount++;
          if (retryCount > maxRetries) throw uploadError;
          // Wait before retrying
          await Future.delayed(Duration(seconds: retryCount));
        }
      }
      
      if (response != null) {
        return response.secureUrl;
      } else {
        return null;
      }
    } catch (e) {
      logger.e('Cloudinary upload error: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل تحميل الصورة.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return null;
    }
  }
}
