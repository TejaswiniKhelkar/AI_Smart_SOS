import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'network_service.dart';
import 'alert_service.dart';
import 'contact_service.dart';
import 'sms_service.dart';
import 'live_location_service.dart';

enum QueueItemType { sosAlert, contactSync, contactAdd, contactUpdate, contactDelete, smsDelivery, liveLocation }
enum QueueItemStatus { pending, syncing, failed }

class QueueItem {
  final String id;
  final QueueItemType type;
  final DateTime timestamp;
  final Map<String, dynamic> payload;
  int retryCount;
  QueueItemStatus status;
  DateTime? lastRetryTime;
  String? errorReason;

  QueueItem({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.payload,
    this.retryCount = 0,
    this.status = QueueItemStatus.pending,
    this.lastRetryTime,
    this.errorReason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'payload': payload,
        'retryCount': retryCount,
        'status': status.name,
        'lastRetryTime': lastRetryTime?.toIso8601String(),
        'errorReason': errorReason,
      };

  factory QueueItem.fromJson(Map<String, dynamic> json) {
    return QueueItem(
      id: json['id'],
      type: QueueItemType.values.byName(json['type']),
      timestamp: DateTime.parse(json['timestamp']),
      payload: json['payload'],
      retryCount: json['retryCount'] ?? 0,
      status: QueueItemStatus.values.byName(json['status'] ?? 'pending'),
      lastRetryTime: json['lastRetryTime'] != null
          ? DateTime.parse(json['lastRetryTime'])
          : null,
      errorReason: json['errorReason'],
    );
  }
}

/// Service to manage the offline synchronization queue.
class SyncQueueService {
  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;
  SyncQueueService._internal();

  static const String _queueKey = 'offline_sync_queue';
  bool _isProcessing = false;
  
  /// Callback to execute when an item is processed successfully.
  /// The caller must register handlers for the types they care about.
  final Map<QueueItemType, Future<bool> Function(Map<String, dynamic> payload)> _handlers = {};

  void registerHandler(QueueItemType type, Future<bool> Function(Map<String, dynamic> payload) handler) {
    _handlers[type] = handler;
  }

  void init() {
    registerHandler(QueueItemType.sosAlert, (payload) async {
      return await AlertService.syncAlertToFirebase(payload);
    });
    
    registerHandler(QueueItemType.contactSync, (payload) async {
      return await ContactService.syncContactsToFirebase(payload);
    });

    registerHandler(QueueItemType.smsDelivery, (payload) async {
      final eventId = payload['eventId'] as String;
      final latitude = payload['latitude'] as double;
      final longitude = payload['longitude'] as double;
      final googleMapsLink = payload['googleMapsLink'] as String;

      final result = await SmsService.sendEmergencySMS(
        eventId: eventId,
        latitude: latitude,
        longitude: longitude,
        googleMapsLink: googleMapsLink,
      );

      if (result.overallStatus == 'sent' || result.overallStatus == 'failed_no_provider') {
        // Successfully processed (even if no provider, we don't retry)
        // Update the SosAlert history if it exists
        final alerts = await AlertService.getAlerts();
        final index = alerts.indexWhere((a) => a.id == eventId);
        if (index != -1) {
          final alert = alerts[index];
          
          final contactStatuses = <Map<String, dynamic>>[];
          final contacts = await ContactService.getContacts();
          for (var c in contacts) {
            final num = SmsService.formatPhoneNumber(c.phone);
            final status = result.contactStatuses[num] ?? 'failed';
            contactStatuses.add({
              'name': c.name,
              'phone': num,
              'status': status,
            });
          }

          final updatedAlert = alert.copyWith(
            smsDeliveryStatus: result.overallStatus,
            contactDeliveryStatuses: contactStatuses,
          );
          await AlertService.saveAlert(updatedAlert);
        }
        return true;
      }
      
      return false; // Retry later
    });

    registerHandler(QueueItemType.liveLocation, (payload) async {
      return await LiveLocationService.syncLocationToFirebase(payload);
    });

    NetworkService().onStatusChanged.listen((status) {
      if (status == NetworkStatus.online) {
        processQueue();
      }
    });
  }

  Future<void> enqueue(QueueItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getQueue();
    items.add(item);
    await _saveQueue(prefs, items);
    
    if (NetworkService().isOnline) {
      processQueue();
    }
  }

  Future<List<QueueItem>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_queueKey);
    if (encoded == null || encoded.isEmpty) return [];
    
    try {
      final List<dynamic> list = json.decode(encoded);
      return list.map((e) => QueueItem.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error decoding queue: $e');
      return [];
    }
  }

  Future<void> _saveQueue(SharedPreferences prefs, List<QueueItem> items) async {
    final encoded = json.encode(items.map((i) => i.toJson()).toList());
    await prefs.setString(_queueKey, encoded);
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final items = await getQueue();
      
      if (items.isEmpty) {
        _isProcessing = false;
        return;
      }

      final itemsToKeep = <QueueItem>[];
      bool changed = false;

      for (var item in items) {
        // Skip items that are currently syncing or have max retries
        if (item.status == QueueItemStatus.syncing || item.retryCount >= 5) {
          itemsToKeep.add(item);
          continue;
        }

        final handler = _handlers[item.type];
        if (handler == null) {
          debugPrint('No handler registered for queue item type: ${item.type}');
          item.errorReason = 'No handler registered';
          item.status = QueueItemStatus.failed;
          itemsToKeep.add(item);
          changed = true;
          continue;
        }

        item.status = QueueItemStatus.syncing;
        changed = true;

        try {
          final success = await handler(item.payload);
          if (!success) {
            item.status = QueueItemStatus.failed;
            item.retryCount++;
            item.lastRetryTime = DateTime.now();
            item.errorReason = 'Handler returned false';
            itemsToKeep.add(item);
          }
          // If success, we don't add it back to itemsToKeep (effectively removing it)
        } catch (e) {
          item.status = QueueItemStatus.failed;
          item.retryCount++;
          item.lastRetryTime = DateTime.now();
          item.errorReason = e.toString();
          itemsToKeep.add(item);
        }
      }

      if (changed) {
        await _saveQueue(prefs, itemsToKeep);
      }
    } finally {
      _isProcessing = false;
    }
  }
}
