import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../data/local/app_database.dart';
import '../data/sync/sync_engine.dart';

/// État réseau réel (via connectivity_plus) et nombre d'actions en attente de
/// synchronisation (via la table PendingOperations) — remplace l'ancienne
/// simulation manuelle.
class NetworkState extends ChangeNotifier {
  final Connectivity _connectivity;
  final AppDatabase _db;
  final SyncEngine _syncEngine;

  bool _isOnline = true;
  int _pendingCount = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<int>? _pendingCountSub;

  NetworkState(this._connectivity, this._db, this._syncEngine) {
    _init();
  }

  bool get isOnline => _isOnline;
  int get pendingCount => _pendingCount;

  Future<void> _init() async {
    _isOnline = _isConnected(await _connectivity.checkConnectivity());
    notifyListeners();
    if (_isOnline) unawaited(_syncEngine.drain());

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final wasOffline = !_isOnline;
      _isOnline = _isConnected(results);
      notifyListeners();
      if (wasOffline && _isOnline) unawaited(_syncEngine.drain());
    });

    _pendingCountSub = _db.watchPendingCount().listen((count) {
      _pendingCount = count;
      notifyListeners();
    });
  }

  bool _isConnected(List<ConnectivityResult> results) => results.any((r) => r != ConnectivityResult.none);

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _pendingCountSub?.cancel();
    super.dispose();
  }
}
