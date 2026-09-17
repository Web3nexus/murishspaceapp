import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';

import '../core/api_client.dart';
import '../config/env.dart';
import '../providers/auth_provider.dart';

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  Future<void> initialize() async {
    // Request permission for push notifications
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('[PushService] User granted permission');
      
      // Get the token and send it to the backend
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }

      // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen(_sendTokenToBackend);

      // Handle messages while the app is in the foreground
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle call events (Answer, Decline) from CallKit
      FlutterCallkitIncoming.onEvent.listen(_handleCallKitEvent);
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    debugPrint('[PushService] FCM Token: $token');
    try {
      await ApiClient.instance.post('/users/fcm-token', data: {'fcm_token': token});
    } catch (e) {
      debugPrint('[PushService] Failed to send FCM token to backend: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[PushService] Foreground message received: ${message.data}');
    _processPushPayload(message.data);
  }

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('[PushService] Background message received: ${message.data}');
    await _processPushPayload(message.data);
  }

  static Future<void> _processPushPayload(Map<String, dynamic> data) async {
    if (data['type'] == 'incoming_call') {
      final callerName = data['caller_name'] ?? 'Unknown Caller';
      final callId = data['call_id'];
      final isVideo = data['is_video'] == 'true' || data['is_video'] == true;

      final params = CallKitParams(
        id: callId.toString(),
        nameCaller: callerName,
        appName: 'Murihspace',
        avatar: data['caller_avatar'] ?? '',
        handle: 'Murihspace Call',
        type: isVideo ? 1 : 0,
        textAccept: 'Accept',
        textDecline: 'Decline',
        missedCallNotification: const NotificationParams(
          showNotification: true,
          isShowCallback: true,
          subtitle: 'Missed call',
        ),
        extra: <String, dynamic>{
          'call_id': callId,
          'room_name': data['room_name'],
          'livekit_host': data['livekit_host'],
          'livekit_token': data['livekit_token'],
        },
        headers: <String, dynamic>{},
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0F141C',
          backgroundUrl: 'assets/test.png',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          incomingCallNotificationChannelName: 'Incoming Call',
          missedCallNotificationChannelName: 'Missed Call',
        ),
        ios: const IOSParams(
          iconName: 'CallKitIcon',
          handleType: 'generic',
          supportsVideo: true,
          maximumCallGroups: 1,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'default',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: true,
          supportsHolding: true,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: 'system_ringtone_default',
        ),
      );
      
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    }
  }

  void _handleCallKitEvent(CallEvent event) async {
    switch (event.event) {
      case Event.actionCallAccept:
        debugPrint('[PushService] Call Accepted: ${event.body}');
        final callId = event.body['extra']?['call_id'];
        if (callId != null) {
          try {
            // Tell the backend we accepted, which will generate our token
            // The app's realtime provider will also pick up the status change
            // and navigate to the call screen automatically.
            await ApiClient.instance.post('/calls/$callId/accept');
          } catch (e) {
            debugPrint('[PushService] Failed to accept call: $e');
          }
        }
        break;
      case Event.actionCallDecline:
        debugPrint('[PushService] Call Declined: ${event.body}');
        // Tell backend we declined the call
        final callId = event.body['extra']?['call_id'];
        if (callId != null) {
          try {
            await ApiClient.instance.post('/calls/$callId/decline');
          } catch (_) {}
        }
        break;
      default:
        break;
    }
  }
}
