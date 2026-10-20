import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';

import '../core/api_client.dart';
import '../config/router.dart';
import '../screens/call_screen.dart';
import 'call_session_manager.dart';

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Invoked when a call push arrives while the app is in the foreground so the
  /// in-app banner can be raised even if the realtime socket is down. Wired up
  /// in `main.dart`.
  void Function(Map<String, dynamic> data)? onIncomingCallForeground;

  /// Invoked when a call is declined / ended / times out from the OS call UI so
  /// any lingering in-app call state can be cleared. Wired up in `main.dart`.
  void Function(Map<String, dynamic> extra)? onExternalCallEnded;

  /// Invoked when a non-call push arrives while the app is in the foreground.
  void Function(Map<String, dynamic> data, RemoteNotification? notification)? onNotificationForeground;

  /// Invoked when the user taps an OS push notification to open the app.
  void Function(Map<String, dynamic> data)? onNotificationOpened;

  String? _lastToken;
  String? _lastVoipToken;

  bool _initialized = false;

  final Map<String, int> _backendCallByCallKitId = {};

  /// Set when the user answers from CallKit before the Flutter navigator is
  /// ready (e.g. the app was cold-started by the answer action).
  Map<String, dynamic>? _pendingAcceptedCall;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Register for push notifications. VoIP pushes (iOS) and CallKit work
    // independently of this permission, so failure here must not disable calls.
    try {
      final NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[PushService] Notification permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('[PushService] requestPermission error: $e');
    }

    try {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    // Always listen for CallKit events, even if notification permission was
    // denied — otherwise accepting a call from the lock screen would be lost.
    FlutterCallkitIncoming.onEvent.listen(_handleCallKitEvent);

    // Regular FCM token (data + notification pushes).
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
      FirebaseMessaging.instance.onTokenRefresh.listen(_sendTokenToBackend);
    } catch (e) {
      debugPrint('[PushService] FCM token error: $e');
    }

    // Messages received while the app is foregrounded.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Push notification tapped from background.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[PushService] onMessageOpenedApp: ${message.data}');
      onNotificationOpened?.call(Map<String, dynamic>.from(message.data));
    });

    // Push notification tapped from terminated state (cold start).
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('[PushService] getInitialMessage: ${message.data}');
        onNotificationOpened?.call(Map<String, dynamic>.from(message.data));
      }
    });

    await _registerVoipToken();

    // Android 13+ notification permission + Android 14+ full-screen-intent
    // permission. Both are required for the call UI to appear over the lock
    // screen / when backgrounded.
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await FlutterCallkitIncoming.requestNotificationPermission(const <String, dynamic>{
          'rationaleMessage': 'Allow Murihspace to show incoming call notifications.',
          'title': 'Notifications',
        });
      } catch (e) {
        debugPrint('[PushService] requestNotificationPermission error: $e');
      }
      try {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      } catch (e) {
        debugPrint('[PushService] requestFullIntentPermission error: $e');
      }
    }
  }

  /// Public method to sync device tokens whenever the user logs in or the app
  /// restores a session.
  Future<void> syncToken() async {
    try {
      final token = _lastToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('[PushService] syncToken error: $e');
    }
    await _registerVoipToken();
  }

  Future<void> _sendTokenToBackend(String token) async {
    _lastToken = token;
    debugPrint('[PushService] FCM token received');
    try {
      final authToken = await ApiClient.readToken();
      if (authToken == null || authToken.isEmpty) {
        debugPrint('[PushService] User not logged in yet. Token stored, will sync upon login.');
        return;
      }
      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      await ApiClient.instance.post('/profile/fcm-token', data: {
        'fcm_token': token,
        'platform': platform,
      });
      debugPrint('[PushService] Successfully registered FCM token with backend.');
    } catch (e) {
      debugPrint('[PushService] Failed to send FCM token to backend: $e');
    }
  }

  /// iOS only: fetch the PushKit VoIP token and register it with the backend so
  /// the server can deliver a VoIP push that rings the device when the app is
  /// terminated.
  Future<void> _registerVoipToken() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      if (token != null && token.isNotEmpty) {
        await _sendVoipTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('[PushService] registerVoipToken error: $e');
    }
  }

  Future<void> _sendVoipTokenToBackend(String token) async {
    if (_lastVoipToken == token) return;
    try {
      final authToken = await ApiClient.readToken();
      if (authToken == null || authToken.isEmpty) {
        debugPrint('[PushService] User not logged in yet. VoIP token stored, will sync upon login.');
        return;
      }
      await ApiClient.instance.post('/profile/fcm-token', data: {
        'fcm_token': token,
        'platform': 'ios_voip',
      });
      _lastVoipToken = token;
      debugPrint('[PushService] Successfully registered VoIP token with backend.');
    } catch (e) {
      debugPrint('[PushService] Failed to send VoIP token to backend: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[PushService] Foreground message received: ${message.data}');
    // While foregrounded the in-app ringing banner is the source of truth, so
    // do not raise the native CallKit UI (that would double up). Nudge the
    // banner in case the realtime socket missed the call broadcast.
    if (message.data['type'] == 'incoming_call') {
      try {
        onIncomingCallForeground?.call(Map<String, dynamic>.from(message.data));
      } catch (e) {
        debugPrint('[PushService] onIncomingCallForeground error: $e');
      }
    } else {
      try {
        onNotificationForeground?.call(
          Map<String, dynamic>.from(message.data),
          message.notification,
        );
      } catch (e) {
        debugPrint('[PushService] onNotificationForeground error: $e');
      }
    }
  }

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('[PushService] Background message received: ${message.data}');
    await _processPushPayload(message.data);
  }

  static Future<void> _processPushPayload(Map<String, dynamic> data) async {
    if (data['type'] != 'incoming_call') return;

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
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Incoming Call',
        missedCallNotificationChannelName: 'Missed Call',
        textAccept: 'Accept',
        textDecline: 'Decline',
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

  void _handleCallKitEvent(CallEvent? event) async {
    if (event == null) return;

    if (event is CallEventActionDidUpdateDevicePushTokenVoip) {
      debugPrint('[PushService] VoIP token updated');
      await _registerVoipToken();
      return;
    }

    if (event is CallEventActionCallIncoming) {
      // Record the CallKit-ID → backend-ID mapping so decline/end/timeout
      // events (which may only carry the CallKit UUID) resolve correctly.
      final params = event.callKitParams;
      final callId = int.tryParse((params.extra?['call_id'] ?? '').toString());
      if (callId != null && callId > 0) {
        _backendCallByCallKitId[params.id] = callId;
      }
      return;
    }

    if (event is CallEventActionCallAccept) {
      debugPrint('[PushService] Call Accepted: ${event.callKitParams.id}');
      final params = event.callKitParams;
      final extra = params.extra ?? const <String, dynamic>{};
      final callId = int.tryParse((extra['call_id'] ?? params.id)?.toString() ?? '');
      if (callId == null || callId <= 0) return;

      // Remember the CallKit-ID → backend-ID mapping so later decline/end/
      // timeout events (which may only carry the CallKit UUID) resolve to the
      // backend call id.
      _backendCallByCallKitId[params.id] = callId;

      // The session is already up for this call (e.g. a duplicate accept from
      // the OS UI while the call is ringing/connecting). Do not re-accept or
      // re-open the screen; just keep the session.
      if (CallSessionManager.instance.isActive &&
          CallSessionManager.instance.activeCallId == callId) {
        return;
      }

      // If the push did not carry a LiveKit token (FCM data push omits it for
      // security), use the one minted by the accept endpoint.
      String? livekitToken = extra['livekit_token']?.toString();
      String? livekitHost = extra['livekit_host']?.toString();
      try {
        final res = await ApiClient.instance.post('/calls/$callId/accept');
        final payload = ApiClient.instance.unwrap(res);
        if (payload is Map) {
          livekitToken ??= payload['livekit_token']?.toString();
          livekitHost ??= payload['livekit_host']?.toString();
        }
      } catch (e) {
        // An already-accepted call (e.g. answered on another device) must not
        // hang up the connected session; open/bounce to it instead.
        if (!(CallSessionManager.instance.isActive &&
            CallSessionManager.instance.activeCallId == callId)) {
          debugPrint('[PushService] Failed to accept call: $e');
          if (params.id.isNotEmpty) {
            await _endCallKitCall(params.id);
          }
          return;
        }
      }

      await _openAcceptedCall({
        'call_id': callId,
        'name': params.nameCaller ?? 'Contact',
        'avatar': params.avatar ?? '',
        'is_video': params.type == 1,
        'token': livekitToken,
        'host': livekitHost,
      });
      return;
    }

    if (event is CallEventActionCallDecline) {
      final callKitId = event.callKitParams.id;
      final callId = event.callKitParams.extra?['call_id'] ??
          _backendCallByCallKitId[callKitId] ??
          callKitId;
      debugPrint('[PushService] Call Declined: $callId');
      await _notifyCallEnded(callId, declined: true);
      return;
    }

    if (event is CallEventActionCallEnded) {
      final callKitId = event.callKitParams.id;
      final callId = event.callKitParams.extra?['call_id'] ??
          _backendCallByCallKitId[callKitId] ??
          callKitId;
      debugPrint('[PushService] Call Ended: $callId');
      await _notifyCallEnded(callId, declined: false);
      return;
    }

    if (event is CallEventActionCallTimeout) {
      final callKitId = event.id;
      // The timeout event only exposes the CallKit UUID — resolve the backend
      // call id from the mapping recorded at accept time when available.
      final callId = _backendCallByCallKitId[callKitId] ?? callKitId;
      debugPrint('[PushService] Call Timeout: $callId');
      // A timeout is the caller missing the call, not the user declining it, so
      // surface it as an ended (not declined) notification.
      await _notifyCallEnded(callId, declined: false);
      return;
    }
  }

  /// Ends a CallKit call via flutter_callkit_incoming and, as a best-effort
  /// fallback, tells the iOS fallback provider to end any call it reported
  /// (cold-start path where the plugin did not report the call).
  Future<void> _endCallKitCall(String id) async {
    try {
      await FlutterCallkitIncoming.endCall(id);
    } catch (e) {
      debugPrint('[PushService] endCall error: $e');
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await const MethodChannel('murihspace/voip_fallback').invokeMethod('endActive');
      } catch (_) {
        // Fallback bridge not registered (no fallback-reported call) — ignore.
      }
    }
  }

  Future<void> _notifyCallEnded(dynamic callId, {required bool declined}) async {
    final id = int.tryParse(callId?.toString() ?? '');
    if (id != null && id > 0) {
      try {
        await ApiClient.instance.post('/calls/$id/${declined ? 'decline' : 'end'}');
      } catch (e) {
        debugPrint('[PushService] Failed to notify call end: $e');
      }
    }
    try {
      onExternalCallEnded?.call({'call_id': callId});
    } catch (e) {
      debugPrint('[PushService] onExternalCallEnded error: $e');
    }
  }

  Future<void> _openAcceptedCall(Map<String, dynamic> call) async {
    final callId = (call['call_id'] as num?)?.toInt();
    if (callId == null || callId <= 0) return;

    final callerName = call['name']?.toString() ?? 'Contact';
    final callerAvatar = call['avatar']?.toString();
    final isVideo = call['is_video'] == true;
    final livekitToken = call['token']?.toString();
    final livekitHost = call['host']?.toString();

    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      // App was cold-started by the answer action; the navigator is not mounted
      // yet. Replay once the app resumes / first frame is drawn — the session is
      // initialized in the replay so initOrAttachCall runs exactly once.
      _pendingAcceptedCall = {
        ...call,
        '_queuedAt': DateTime.now().millisecondsSinceEpoch,
      };
      return;
    }

    // Bring the in-app call session + LiveKit connection up so answering from
    // the OS CallKit UI (lock screen / background / terminated) actually connects.
    CallSessionManager.instance.initOrAttachCall(
      contactName: callerName,
      avatarUrl: (callerAvatar != null && callerAvatar.isNotEmpty) ? callerAvatar : null,
      isVideo: isVideo,
      callId: callId,
      isIncoming: true,
      isAccepted: true,
      livekitToken: livekitToken,
      livekitHost: livekitHost,
    );

    try {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            contactName: callerName,
            avatarUrl: (callerAvatar != null && callerAvatar.isNotEmpty) ? callerAvatar : null,
            isVideo: isVideo,
            callId: callId,
            isIncoming: true,
            isAccepted: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[PushService] Failed to open call screen: $e');
    }
  }

  /// Called when the app becomes visible (and after first frame) to surface a
  /// call the user accepted while the app was terminated.
  Future<void> processPendingAcceptedCall() async {
    final pending = _pendingAcceptedCall;
    if (pending == null) return;
    _pendingAcceptedCall = null;

    final queuedAt = pending['_queuedAt'] as int? ?? 0;
    final ageMs = DateTime.now().millisecondsSinceEpoch - queuedAt;
    if (ageMs > 60000) {
      // The accept happened too long ago while the app was down — don't open a
      // stale (likely already-ended) call screen.
      debugPrint('[PushService] Dropping stale accepted call ($ageMs ms old)');
      return;
    }

    final call = Map<String, dynamic>.from(pending)..remove('_queuedAt');
    await _openAcceptedCall(call);
  }
}
