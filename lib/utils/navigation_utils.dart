import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:map_explorer/logger.dart';

/// Utility class for handling navigation to external map applications
class NavigationUtils {
  /// Opens the location in the user's preferred map application
  /// Supports Google Maps, Apple Maps, and Waze
  static Future<void> openInMaps({
    required double latitude,
    required double longitude,
    required String locationName,
    required BuildContext context,
  }) async {
    // Show dialog to let user choose which app to use
    final mapApp = await showDialog<MapApp>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فتح في', textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map, color: Colors.blue),
              title: const Text('خرائط جوجل', textAlign: TextAlign.right),
              onTap: () => Navigator.pop(context, MapApp.googleMaps),
            ),
            if (Platform.isIOS)
              ListTile(
                leading: const Icon(Icons.map, color: Colors.green),
                title: const Text('خرائط آبل', textAlign: TextAlign.right),
                onTap: () => Navigator.pop(context, MapApp.appleMaps),
              ),
            ListTile(
              leading: const Icon(Icons.navigation, color: Colors.lightBlue),
              title: const Text('Waze', textAlign: TextAlign.right),
              onTap: () => Navigator.pop(context, MapApp.waze),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );

    if (mapApp == null) return;

    try {
      final url = _getMapUrl(
        mapApp: mapApp,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback to web URL if app is not installed
        final webUrl = _getWebMapUrl(
          mapApp: mapApp,
          latitude: latitude,
          longitude: longitude,
          locationName: locationName,
        );
        
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(
            webUrl,
            mode: LaunchMode.externalApplication,
          );
        } else {
          throw 'Could not launch map application';
        }
      }
    } catch (e) {
      logger.e('Error opening maps: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح التطبيق: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Get the appropriate URL for the selected map application
  static Uri _getMapUrl({
    required MapApp mapApp,
    required double latitude,
    required double longitude,
    required String locationName,
  }) {
    switch (mapApp) {
      case MapApp.googleMaps:
        // Google Maps URL scheme
        if (Platform.isIOS) {
          return Uri.parse(
            'comgooglemaps://?q=$latitude,$longitude&label=${Uri.encodeComponent(locationName)}'
          );
        } else {
          return Uri.parse(
            'geo:$latitude,$longitude?q=$latitude,$longitude(${Uri.encodeComponent(locationName)})'
          );
        }
      
      case MapApp.appleMaps:
        // Apple Maps URL scheme (iOS only)
        return Uri.parse(
          'maps://?q=${Uri.encodeComponent(locationName)}&ll=$latitude,$longitude'
        );
      
      case MapApp.waze:
        // Waze URL scheme
        return Uri.parse(
          'waze://?ll=$latitude,$longitude&navigate=yes'
        );
    }
  }

  /// Get web-based fallback URL if app is not installed
  static Uri _getWebMapUrl({
    required MapApp mapApp,
    required double latitude,
    required double longitude,
    required String locationName,
  }) {
    switch (mapApp) {
      case MapApp.googleMaps:
        return Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
        );
      
      case MapApp.appleMaps:
        return Uri.parse(
          'https://maps.apple.com/?q=${Uri.encodeComponent(locationName)}&ll=$latitude,$longitude'
        );
      
      case MapApp.waze:
        return Uri.parse(
          'https://www.waze.com/ul?ll=$latitude,$longitude&navigate=yes'
        );
    }
  }

  /// Quick navigation to Google Maps without dialog
  static Future<void> navigateToGoogleMaps({
    required double latitude,
    required double longitude,
    required String locationName,
    required BuildContext context,
  }) async {
    try {
      final Uri url;
      
      if (Platform.isIOS) {
        // Try Google Maps app first on iOS
        url = Uri.parse(
          'comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving'
        );
      } else {
        // Android intent
        url = Uri.parse(
          'google.navigation:q=$latitude,$longitude&mode=d'
        );
      }

      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback to web URL
        final webUrl = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude'
        );
        
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(
            webUrl,
            mode: LaunchMode.externalApplication,
          );
        } else {
          throw 'Google Maps is not available';
        }
      }
    } catch (e) {
      logger.e('Error opening Google Maps: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في فتح خرائط جوجل'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Enum for supported map applications
enum MapApp {
  googleMaps,
  appleMaps,
  waze,
}
