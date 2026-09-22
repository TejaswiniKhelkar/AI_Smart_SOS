import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus { online, offline }

/// Service to monitor network connectivity status.
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  NetworkStatus _currentStatus = NetworkStatus.online; // Default to online
  final _statusController = StreamController<NetworkStatus>.broadcast();

  NetworkStatus get currentStatus => _currentStatus;
  Stream<NetworkStatus> get onStatusChanged => _statusController.stream;
  bool get isOnline => _currentStatus == NetworkStatus.online;

  void init() {
    _connectivity.checkConnectivity().then(_updateStatus);
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    bool isConnected = false;
    for (var result in results) {
      if (result == ConnectivityResult.mobile || 
          result == ConnectivityResult.wifi || 
          result == ConnectivityResult.ethernet) {
        isConnected = true;
        break;
      }
    }
    
    final newStatus = isConnected ? NetworkStatus.online : NetworkStatus.offline;
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController.add(_currentStatus);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
