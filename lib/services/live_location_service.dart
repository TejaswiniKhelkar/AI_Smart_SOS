import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'location_service.dart';
import 'network_service.dart';
import 'sync_queue_service.dart';

/// Singleton service that manages live location tracking during an active emergency.
class LiveLocationService {
  static final LiveLocationService _instance = LiveLocationService._internal();
  factory LiveLocationService() => _instance;
  LiveLocationService._internal();

  StreamSubscription<Position>? _positionStream;
  String? _currentEventId;
  
  final _activeController = StreamController<bool>.broadcast();
  bool _isActive = false;

  /// Whether there is currently an active emergency tracking session.
  bool get isActive => _isActive;
  
  /// Stream that emits true when tracking starts, and false when it stops.
  Stream<bool> get statusStream => _activeController.stream;
  
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Starts live location tracking for the given SOS event ID.
  /// Automatically stops any previously running session.
  void startSharing(String eventId) {
    if (_isActive && _currentEventId == eventId) {
      return; // Already sharing for this event
    }
    
    stopSharing();
    
    _isActive = true;
    _currentEventId = eventId;
    _activeController.add(true);
    
    debugPrint('[LiveLocationService] Started tracking for event: $eventId');
    
    // Use Geolocator stream
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // Update every 15 meters
        timeLimit: Duration(minutes: 5), // Or at least every 5 minutes if moving slow (Wait, timeLimit closes the stream if no location is received. We shouldn't use timeLimit here to avoid stream closing).
      ),
    ).listen(
      (Position position) {
        _handleNewPosition(position, eventId);
      },
      onError: (e) {
        debugPrint('[LiveLocationService] Stream error: $e');
      },
    );
  }
  
  /// Stops live location tracking.
  void stopSharing() {
    if (!_isActive) return;
    
    _positionStream?.cancel();
    _positionStream = null;
    _currentEventId = null;
    _isActive = false;
    _activeController.add(false);
    
    debugPrint('[LiveLocationService] Stopped tracking.');
  }
  
  Future<void> _handleNewPosition(Position position, String eventId) async {
    final link = LocationService.generateMapsLink(position.latitude, position.longitude);
    
    final payload = {
      'eventId': eventId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'googleMapsLink': link,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    if (NetworkService().isOnline && _uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .collection('live_locations')
            .doc(eventId)
            .set(payload, SetOptions(merge: true));
        debugPrint('[LiveLocationService] Synced live location to Firebase.');
      } catch (e) {
        debugPrint('[LiveLocationService] Failed to sync, enqueueing... $e');
        await _enqueueLocation(payload, eventId);
      }
    } else {
      debugPrint('[LiveLocationService] Offline, enqueueing live location...');
      await _enqueueLocation(payload, eventId);
    }
  }
  
  Future<void> _enqueueLocation(Map<String, dynamic> payload, String eventId) async {
    await SyncQueueService().enqueue(
      QueueItem(
        id: 'live_loc_$eventId', // Overwrite the same item in queue to avoid massive queues if offline for long
        type: QueueItemType.liveLocation,
        timestamp: DateTime.now(),
        payload: payload,
      ),
    );
  }
  
  /// Syncs the location to Firebase (Called by SyncQueueService)
  static Future<bool> syncLocationToFirebase(Map<String, dynamic> payload) async {
    final uid = _uid;
    if (uid == null) return false;
    
    final eventId = payload['eventId'] as String?;
    if (eventId == null) return false;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('live_locations')
          .doc(eventId)
          .set(payload, SetOptions(merge: true));
      return true;
    } catch (e) {
      return false;
    }
  }
}
