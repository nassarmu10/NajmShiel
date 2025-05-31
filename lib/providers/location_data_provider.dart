import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:map_explorer/logger.dart';
import 'package:map_explorer/models/location.dart';
import 'package:map_explorer/models/comment.dart';
import 'package:map_explorer/models/vote.dart';
import 'package:map_explorer/services/location_service.dart';
import 'package:map_explorer/utils/location_type_utils.dart';

class LocationDataProvider with ChangeNotifier {
  final FirebaseLocationService _firebaseService = FirebaseLocationService();

  List<Location> _locations = [];
  final Map<String, List<Comment>> _locationComments = {};
  final Map<String, VoteSummary> _locationVotes = {};
  String? _currentUserId; // For tracking the current user
  // User's name cache
  String? _userName;
  bool _isLoading = false;

  // Filter settings
  bool _showHistorical = true;
  bool _showForests = true;
  bool _showCities = true;
  bool _showOther = true;
  bool _showBarbecue = true;
  bool _showFamily = true;
  bool _showViewpoint = true;
  bool _showBeach = true;
  bool _showHiking = true;
  bool _showCamping = true;
  bool _showWaterSpring = true;
  bool _showMosque = true;
  bool _showChurch = true;

  LocationDataProvider() {
    // Load locations when provider is created
    // _loadLocations();
  }

  // Call this method from your MapScreen's initState
  Future<void> initialize() async {
    if (_locations.isEmpty) {
      await _loadLocations();
    }
  }

  // Getters
  List<Location> get locations => _locations;
  bool get isLoading => _isLoading;
  bool get showHistorical => _showHistorical;
  bool get showForests => _showForests;
  bool get showCities => _showCities;
  bool get showOther => _showOther;
  bool get showBarbecue => _showBarbecue;
  bool get showFamily => _showFamily;
  bool get showViewpoint => _showViewpoint;
  bool get showBeach => _showBeach;
  bool get showHiking => _showHiking;
  bool get showCamping => _showCamping;
  String? get currentUserId => _currentUserId;
  bool get showWaterSpring => _showWaterSpring;
  bool get showMosque => _showMosque;
  bool get showChurch => _showChurch;

  // Set current user
  void setCurrentUserId(String userId, {bool notify = true}) {
    _currentUserId = userId;

    // Only call notifyListeners if notify is true
    // This allows us to set the ID without rebuilding during initialization
    if (notify) {
      notifyListeners();
    }
  }

  // Add this method to initialize without triggering rebuilds
  Future<void> silentInitialize() async {
    if (_locations.isEmpty) {
      _isLoading = true;

      try {
        _locations = await _firebaseService.getLocations();
        _isLoading = false;
      } catch (e) {
        logger.e('Error loading locations: $e');
        _isLoading = false;
      }
    }
  }

  // Get filtered locations
  List<Location> get filteredLocations {
    return _locations.where((location) {
      // Check main type
      bool mainTypeVisible = _isTypeVisible(location.type);
      
      // Check if any tags are visible
      bool anyTagVisible = location.tags.any((tag) => _isTypeVisible(tag));
      
      // Show location if either main type is visible OR any tag is visible
      return mainTypeVisible || anyTagVisible;
    }).toList();
  }

  bool _isTypeVisible(LocationType type) {
    switch (type) {
      case LocationType.historical:
        return _showHistorical;
      case LocationType.forest:
        return _showForests;
      case LocationType.city:
        return _showCities;
      case LocationType.barbecue:
        return _showBarbecue;
      case LocationType.family:
        return _showFamily;
      case LocationType.viewpoint:
        return _showViewpoint;
      case LocationType.beach:
        return _showBeach;
      case LocationType.hiking:
        return _showHiking;
      case LocationType.camping:
        return _showCamping;
      case LocationType.waterSpring:
        return _showWaterSpring;
      case LocationType.mosque:
        return _showMosque;
      case LocationType.church:
        return _showChurch;
      case LocationType.other:
        return _showOther;
    }
  }

  // Search locations by name
  List<Location> searchLocations(String query) {
    if (query.isEmpty) {
      return [];
    }
    
    final lowercaseQuery = query.toLowerCase();
    
    return _locations.where((location) {
      final lowercaseName = location.name.toLowerCase();
      final lowercaseDescription = location.description.toLowerCase();
      
      bool matchesNameOrDescription = lowercaseName.contains(lowercaseQuery) || 
             lowercaseDescription.contains(lowercaseQuery);

      // Search in main type
      bool matchesMainType = LocationTypeUtils.getDisplayName(location.type)
          .toLowerCase().contains(lowercaseQuery);

      // Search in tags
      bool matchesTags = location.tags.any((tag) {
        final tagDisplayName = LocationTypeUtils.getDisplayName(tag).toLowerCase();
        return tagDisplayName.contains(lowercaseQuery);
      });

      return matchesNameOrDescription || matchesMainType || matchesTags;
    }).toList();
  }

  // Load locations from Firebase
  Future<void> _loadLocations() async {
    _isLoading = true;
    notifyListeners();
    try {
      _locations = await _firebaseService.getLocations();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      logger.e('Error loading locations: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get current user name
  Future<String> getUserName() async {
    // Return cached name if available
    if (_userName != null) {
      return _userName!;
    }
    if (_currentUserId == null) {
      return 'مستخدم';
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      if (doc.exists && doc.data()?['name'] != null) {
        _userName = doc.data()!['name'] as String;
        return _userName!;
      }

      // Fallback to Firebase Auth display name
      final user = FirebaseAuth.instance.currentUser;
      if (user?.displayName != null) {
        _userName = user!.displayName!;
        return _userName!;
      }

      return 'مستخدم';
    } catch (e) {
      logger.e('Error getting user name: $e');
      return 'مستخدم';
    }
  }

  // Set user name (cache it and update in provider)
  Future<void> setUserName(String name) async {
    if (_currentUserId == null) return;

    _userName = name;

    try {
      // Update in Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(name);
      }
      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId!)
          .update({
        'name': name,
        'lastUpdate': FieldValue.serverTimestamp(),
      });

      notifyListeners();
    } catch (e) {
      logger.e('Error setting user name: $e');
    }
  }
  // Check if user is authenticated
  bool get isAuthenticated => _currentUserId != null;
  // Clear user data (for logout)
  void clearUserData() {
    _currentUserId = null;
    _userName = null;
    notifyListeners();
  }

  Future<void> refreshLocations() async {
    await _loadLocations();
  }

  // Add a new location
  Future<void> addLocation(Location location) async {
    try {
      // Get current username
      final String username = await getUserName();

      if (_currentUserId != null) {
        // Use the service to add the location with user info
        await _firebaseService.addLocation(location, _currentUserId!, username);
      } else {
        // Fallback if no user ID (shouldn't happen with auth flow)
        await _firebaseService.addLocation(location, 'anonymous', username);
      }

      // Reload to get the newly added location
      await _loadLocations();
    } catch (e) {
      logger.e('Error adding location: $e');
      rethrow;
    }
  }

  Future<void> deleteLocation(String locationId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if user is the creator
      final location = _locations.firstWhere(
        (loc) => loc.id == locationId,
        orElse: () => throw Exception('Location not found'),
      );

      if (!isLocationCreator(location)) {
        throw Exception('You can only delete locations you created');
      }

      // Delete from Firebase
      await _firebaseService.deleteLocation(locationId, _currentUserId!);

      // Remove from local list
      _locations.removeWhere((loc) => loc.id == locationId);
      
      // Clear any cached data for this location
      _locationComments.remove(locationId);
      _locationVotes.remove(locationId);
      
      notifyListeners();
    } catch (e) {
      logger.e('Error deleting location: $e');
      rethrow;
    }
  }

  // Toggle filters
  void toggleHistorical() {
    _showHistorical = !_showHistorical;
    notifyListeners();
  }

  void toggleForests() {
    _showForests = !_showForests;
    notifyListeners();
  }

  void toggleCities() {
    _showCities = !_showCities;
    notifyListeners();
  }
  void toggleBarbecue() {
    _showBarbecue = !_showBarbecue;
    notifyListeners();
  }

  void toggleFamily() {
    _showFamily = !_showFamily;
    notifyListeners();
  }

  void toggleViewpoint() {
    _showViewpoint = !_showViewpoint;
    notifyListeners();
  }

  void toggleBeach() {
    _showBeach = !_showBeach;
    notifyListeners();
  }

  void toggleHiking() {
    _showHiking = !_showHiking;
    notifyListeners();
  }

  void toggleCamping() {
    _showCamping = !_showCamping;
    notifyListeners();
  }

  void toggleWaterSpring() {
    _showWaterSpring = !_showWaterSpring;
    notifyListeners();
  }

  void toggleMosque() {
    _showMosque = !_showMosque;
    notifyListeners();
  }

  void toggleChurch() {
    _showChurch = !_showChurch;
    notifyListeners();
  }

  void toggleOther() {
    _showOther = !_showOther;
    notifyListeners();
  }

  void setAllFilters(bool value) {
      _showHistorical = value;
      _showForests = value;
      _showCities = value;
      _showBarbecue = value;
      _showFamily = value;
      _showViewpoint = value;
      _showBeach = value;
      _showHiking = value;
      _showCamping = value;
      _showWaterSpring = value;
      _showMosque = value;
      _showChurch = value;
      _showOther = value;
      notifyListeners();

  }

  // COMMENT METHODS

  // Get comments for a location
  Future<List<Comment>> getCommentsForLocation(String locationId) async {
    if (_locationComments.containsKey(locationId)) {
      return _locationComments[locationId]!;
    }

    try {
      final comments =
          await _firebaseService.getCommentsForLocation(locationId);
      _locationComments[locationId] = comments;
      notifyListeners();
      return comments;
    } catch (e) {
      logger.e('Error getting comments: $e');
      return [];
    }
  }

  // Add a comment to a location
  Future<void> addComment(Comment comment) async {
    try {
      await _firebaseService.addComment(comment);

      // Update local cache
      if (_locationComments.containsKey(comment.locationId)) {
        _locationComments[comment.locationId]!.insert(0, comment);
        notifyListeners();
      } else {
        await getCommentsForLocation(comment.locationId);
      }
    } catch (e) {
      logger.e('Error adding comment: $e');
      rethrow;
    }
  }

  // Delete a comment
  Future<void> deleteComment(String commentId, String locationId) async {
    try {
      await _firebaseService.deleteComment(commentId);
      
      // Update local cache
      if (_locationComments.containsKey(locationId)) {
        _locationComments[locationId]!.removeWhere((comment) => comment.id == commentId);
        notifyListeners();
      }
    } catch (e) {
      logger.d('Error deleting comment: $e');
      rethrow;
    }
  }

  // VOTE METHODS

  // Get vote summary for a location
  Future<VoteSummary> getVoteSummary(String locationId) async {
    if (_locationVotes.containsKey(locationId)) {
      return _locationVotes[locationId]!;
    }

    try {
      final voteSummary = await _firebaseService.getVoteSummary(locationId);
      _locationVotes[locationId] = voteSummary;
      notifyListeners();
      return voteSummary;
    } catch (e) {
      logger.e('Error getting vote summary: $e');
      return VoteSummary(likes: 0, dislikes: 0);
    }
  }

  // Add or update a user's vote
  Future<void> addOrUpdateVote(String locationId, VoteType voteType) async {
    if (_currentUserId == null) {
      throw Exception('User ID not set');
    }

    final vote = Vote(
      id: '', // Firestore will generate this
      locationId: locationId,
      userId: _currentUserId!,
      voteType: voteType,
      createdAt: DateTime.now(),
    );

    try {
      await _firebaseService.addOrUpdateVote(vote);

      // Update local cache
      final voteSummary = await _firebaseService.getVoteSummary(locationId);
      _locationVotes[locationId] = voteSummary;
      notifyListeners();
    } catch (e) {
      logger.e('Error adding vote: $e');
      rethrow;
    }
  }

  // Remove a user's vote
  Future<void> removeVote(String locationId) async {
    if (_currentUserId == null) {
      throw Exception('User ID not set');
    }

    try {
      await _firebaseService.removeVote(locationId, _currentUserId!);

      // Update local cache
      final voteSummary = await _firebaseService.getVoteSummary(locationId);
      _locationVotes[locationId] = voteSummary;
      notifyListeners();
    } catch (e) {
      logger.e('Error removing vote: $e');
      rethrow;
    }
  }

  // Get the current user's vote for a location
  Future<VoteType?> getUserVote(String locationId) async {
    if (_currentUserId == null) {
      return null;
    }

    try {
      final userVote =
          await _firebaseService.getUserVote(locationId, _currentUserId!);
      notifyListeners(); // Ensure UI updates if needed
      return userVote;
    } catch (e) {
      logger.e('Error getting user vote: $e');
      return null;
    }
  }

  // Update a comment
  Future<void> updateComment(Comment comment) async {
    try {
      await _firebaseService.updateComment(comment);

      // Update local cache
      if (_locationComments.containsKey(comment.locationId)) {
        final index = _locationComments[comment.locationId]!.indexWhere((c) => c.id == comment.id);
        if (index != -1) {
          _locationComments[comment.locationId]![index] = comment;
          notifyListeners();
        }
      }
    } catch (e) {
      logger.e('Error updating comment: $e');
      rethrow;
    }
  }
  
  // Update a location
  Future<void> updateLocation(Location location) async {
    try {
      await _firebaseService.updateLocation(location);
      
      // Update local cache
      final index = _locations.indexWhere((loc) => loc.id == location.id);
      if (index != -1) {
        _locations[index] = location;
        notifyListeners();
      }
    } catch (e) {
      logger.e('Error updating location: $e');
      rethrow;
    }
  }
  // Check if user is the creator of a comment
  bool isCommentCreator(Comment comment) {
    return _currentUserId != null && comment.userId == _currentUserId;
  }
  // Check if user is the creator of a location
  bool isLocationCreator(Location location) {
    return _currentUserId != null && location.createdBy == _currentUserId;
  }
}






  // final List<Location> _locations = [
  //   Location(
  //     id: '1',
  //     name: 'Old City of Jerusalem',
  //     description: 'Historic walled area with religious sites including the Western Wall, Church of the Holy Sepulchre, and Dome of the Rock.',
  //     type: LocationType.historical,
  //     latitude: 31.7767,
  //     longitude: 35.2345,
  //     createdAt: DateTime.now().subtract(const Duration(days: 100)),
  //   ),
  //   Location(
  //     id: '2',
  //     name: 'Dead Sea',
  //     description: 'Salt lake bordered by Jordan and Israel/Palestine, known for its buoyancy and mineral-rich mud. Its shores are Earth\'s lowest point on land.',
  //     type: LocationType.forest,
  //     latitude: 31.5497,
  //     longitude: 35.4730,
  //     createdAt: DateTime.now().subtract(const Duration(days: 50)),
  //   ),
  //   Location(
  //     id: '3',
  //     name: 'Tel Aviv',
  //     description: 'Coastal city known for its vibrant culture, beaches, and Bauhaus architecture.',
  //     type: LocationType.city,
  //     latitude: 32.0853,
  //     longitude: 34.7818,
  //     createdAt: DateTime.now().subtract(const Duration(days: 25)),
  //   ),
  //   Location(
  //     id: '4',
  //     name: 'Church of the Nativity',
  //     description: 'Birthplace of Jesus in Bethlehem, one of the oldest operating churches in the world.',
  //     type: LocationType.historical,
  //     latitude: 31.7042,
  //     longitude: 35.2062,
  //     createdAt: DateTime.now().subtract(const Duration(days: 200)),
  //   ),
  //   Location(
  //     id: '5',
  //     name: 'Ein Gedi Nature Reserve',
  //     description: 'Oasis near the Dead Sea with hiking trails, waterfalls, and diverse wildlife.',
  //     type: LocationType.forest,
  //     latitude: 31.4667,
  //     longitude: 35.3833,
  //     createdAt: DateTime.now().subtract(const Duration(days: 75)),
  //   ),
  //   Location(
  //     id: '6',
  //     name: 'Haifa',
  //     description: 'Northern port city built on the slopes of Mount Carmel, home to the Bahá\'í Gardens.',
  //     type: LocationType.city,
  //     latitude: 32.7940,
  //     longitude: 34.9896,
  //     createdAt: DateTime.now().subtract(const Duration(days: 120)),
  //   ),
  //   Location(
  //     id: '7',
  //     name: 'Al-Aqsa Mosque',
  //     description: 'Located on the Temple Mount in Jerusalem, one of the holiest sites in Islam.',
  //     type: LocationType.historical,
  //     latitude: 31.7761,
  //     longitude: 35.2358,
  //     createdAt: DateTime.now().subtract(const Duration(days: 150)),
  //   ),
  //   Location(
  //     id: '8',
  //     name: 'Masada',
  //     description: 'Ancient fortress on a plateau overlooking the Dead Sea, site of the last stand of Jewish rebels against the Romans.',
  //     type: LocationType.historical,
  //     latitude: 31.3158,
  //     longitude: 35.3512,
  //     createdAt: DateTime.now().subtract(const Duration(days: 180)),
  //   ),
  //   Location(
  //     id: '9',
  //     name: 'Gaza City',
  //     description: 'Largest city in the Gaza Strip, located on the Mediterranean coast.',
  //     type: LocationType.city,
  //     latitude: 31.5017,
  //     longitude: 34.4668,
  //     createdAt: DateTime.now().subtract(const Duration(days: 90)),
  //   ),
  //   Location(
  //     id: '10',
  //     name: 'Jericho',
  //     description: 'One of the oldest continuously inhabited cities in the world, located in the West Bank.',
  //     type: LocationType.city,
  //     latitude: 31.8667,
  //     longitude: 35.4500,
  //     createdAt: DateTime.now().subtract(const Duration(days: 110)),
  //   ),
  // ];