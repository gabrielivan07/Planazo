import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  FirebaseMessaging? _messaging;
  StreamSubscription<String>? _tokenSubscription;
  bool _available = false;

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;
      _available = true;

      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      _tokenSubscription = _messaging!.onTokenRefresh.listen((token) {
        registerToken(token).ignore();
      });
    } catch (_) {
      // Firebase requiere archivos nativos de cada proyecto. La app sigue
      // funcionando con notificaciones in-app si aún no fueron configurados.
      _available = false;
    }
  }

  Future<void> registerCurrentUser() async {
    if (!_available || _messaging == null) return;
    final token = await _messaging!.getToken();
    if (token != null) await registerToken(token);
  }

  Future<void> registerToken(String token) async {
    final uid = SupabaseService.instance.currentUserId;
    if (!_available || uid == null || token.trim().isEmpty) return;

    final platform = kIsWeb
        ? 'web'
        : defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : defaultTargetPlatform == TargetPlatform.iOS
                ? 'ios'
                : 'otro';

    await SupabaseService.instance.client.rpc('upsert_mi_push_token', params: {
      'p_token': token,
      'p_plataforma': platform,
    });
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
  }
}
