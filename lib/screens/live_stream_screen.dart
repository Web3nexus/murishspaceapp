import '../core/design_tokens.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';

import '../components/animated_action_feedback.dart';
import '../components/gift_animation_overlay.dart';
import '../components/kyc_live_gate_dialog.dart';
import '../components/live_stream_top_header.dart';
import '../components/send_gift_dialog.dart';
import '../config/env.dart';
import '../services/live_session_manager.dart';
import '../core/api_client.dart';
import '../core/roles.dart';
import '../core/realtime_client.dart';
import '../models/chat_models.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/live_discovery_provider.dart';
import '../providers/messages_provider.dart';
import '../providers/realtime_provider.dart';
import '../providers/wallet_provider.dart';

/// Full Interactive Live Streaming Stage with Native Hardware Camera Preview,
/// Real-Time LiveKit Session Connection, Authenticated Chat, Likes, and Ledger-Backed Gifting.
class LiveStreamScreen extends ConsumerStatefulWidget {
  final int? streamId;
  final String? trackingId;
  final String streamTitle;
  final String hostName;
  final String? communityName;
  final bool isHost;
  final String? hostAvatarUrl;
  final bool cameraEnabled;
  final bool micEnabled;
  final String streamMode;
  final Map<String, dynamic>? backgroundSound;
  final Map<String, dynamic>? pinnedProduct;

  const LiveStreamScreen({
    super.key,
    this.streamId,
    this.trackingId,
    this.streamTitle = 'Live Broadcast',
    this.hostName = 'Creator',
    this.hostAvatarUrl,
    this.communityName,
    this.isHost = true,
    this.cameraEnabled = true,
    this.micEnabled = true,
    this.streamMode = 'video',
    this.backgroundSound,
    this.pinnedProduct,
  });

  @override
  ConsumerState<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends ConsumerState<LiveStreamScreen>
    with TickerProviderStateMixin {
  int? _activeStreamId;
  String? _trackingId;
  int? _hostUserId;
  String? _resolvedHostName;
  String? _hostAvatarUrl;
  int _viewerCount = 1;
  int _likesCount = 0;
  int _totalGiftsCoins = 0;
  final Set<dynamic> _seenGiftMessageIds = {};
  bool _hostEndedStream = false;

  /// First character of the host's name, ignoring any leading "@" so a handle
  /// like "@vincent" yields "V".
  String get _hostInitial {
    final name = _effectiveHostName.trim();
    final stripped = name.startsWith('@') ? name.substring(1).trim() : name;
    return stripped.isNotEmpty ? stripped[0] : 'H';
  }

  String get _effectiveHostName {
    if (_resolvedHostName != null && _resolvedHostName!.isNotEmpty) {
      return _resolvedHostName!;
    }
    if (widget.isHost) {
      final me = ref.read(authProvider).user;
      if (me != null) {
        if (me.username.isNotEmpty) return '@${me.username}';
        if (me.name.isNotEmpty) return me.name;
      }
    }
    if (widget.hostName.isNotEmpty &&
        widget.hostName != 'Creator' &&
        widget.hostName != 'Creator Live') {
      return widget.hostName;
    }
    final me = ref.read(authProvider).user;
    if (me != null) {
      if (me.username.isNotEmpty) return '@${me.username}';
      if (me.name.isNotEmpty) return me.name;
    }
    return widget.hostName.isNotEmpty ? widget.hostName : 'Host';
  }

  String? _parseHostName(dynamic streamData) {
    if (streamData is! Map) return null;
    final hostObj = streamData['host'] ?? streamData['user'];
    if (hostObj is Map) {
      final uName = hostObj['username']?.toString().trim();
      final rName = hostObj['name']?.toString().trim();
      if (uName != null && uName.isNotEmpty) {
        return '@$uName';
      } else if (rName != null && rName.isNotEmpty) {
        return rName;
      }
    }
    return null;
  }

  String? _parseHostAvatarUrl(dynamic streamData) {
    if (streamData is! Map) return null;
    final hostObj = streamData['host'] ?? streamData['user'];
    if (hostObj is Map) {
      final url = hostObj['avatar_url']?.toString().trim();
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  // Pinned product available for purchase inside the stream.
  Map<String, dynamic>? _pinnedProduct;

  bool _isCameraReady = false;
  late bool _cameraOn;
  late bool _micOn;
  bool _isFrontCamera = true;
  bool _isSwitchingCamera = false;

  final List<Map<String, dynamic>> _chatMessages = [];
  final _chatCtrl = TextEditingController();
  final _chatFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Floating Hearts Animation State
  final List<_FloatingHeart> _hearts = [];
  final Random _random = Random();

  StreamSubscription<RealtimeEvent>? _realtimeSub;
  String? _subscribedLiveChannel;
  int _pendingLikesBatch = 0;
  Timer? _likeDebounceTimer;
  Map<String, dynamic>? _pinnedComment;

  // Host participant management / moderation roster.
  String? _subscribedLiveRoomChannel;
  StreamSubscription<RealtimeEvent>? _liveRoomSub;
  final List<Map<String, dynamic>> _participants = [];
  bool _isFetchingParticipants = false;
  bool _isParticipantBusy = false;
  bool _isParticipantsSheetOpen = false;
  StateSetter? _participantsModalSetState;
  bool _selfIsCoHost = false;

  Timer? _metricsTimer;
  String? _connectionError;
  bool _leaveSent = false;
  Room? _liveKitRoom;
  EventsListener<RoomEvent>? _liveKitListener;
  VideoTrack? _remoteVideoTrack;
  VideoTrack? _localVideoTrack;
  bool _isConnectingLiveKit = false;
  bool _isLeavingLiveKit = false;

  @override
  void initState() {
    super.initState();
    _activeStreamId = widget.streamId;
    _trackingId = widget.trackingId;
    _hostAvatarUrl = widget.hostAvatarUrl;
    _cameraOn = widget.cameraEnabled;
    _micOn = widget.micEnabled;
    _pinnedProduct = widget.pinnedProduct;

    _chatCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _chatFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _initHardwareAndBackend();
  }

  Future<void> _initHardwareAndBackend() async {
    // 0. KYC check if user is host
    if (widget.isHost) {
      final user = ref.read(authProvider).user;
      final kycStatus = user?.kycStatus.toLowerCase() ?? 'unsubmitted';
      final role = user?.role ?? UserRole.member;
      final isPrivileged =
          role == UserRole.creator ||
          role == UserRole.vendor ||
          role == UserRole.admin;
      if (!isPrivileged && kycStatus != 'verified' && kycStatus != 'approved') {
        if (mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/app/home');
          }
          showKycRequiredLiveModal(context);
        }
        return;
      }

      // Request microphone and camera permissions
      try {
        await Permission.microphone.request();
        if (widget.streamMode != 'audio') {
          await Permission.camera.request();
        }
      } catch (_) {}
    }

    // 1. Connect to backend LiveStream API
    await _connectToBackendStream();

    // 3. Start real-time polling timer for chat and viewer count updates
    _metricsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollLiveMetricsAndChat();
    });
  }

  void _applyPinnedProduct(dynamic pinnedRaw) {
    if (!mounted) return;
    final next = pinnedRaw is Map<String, dynamic> ? pinnedRaw : null;
    final nextSig = next == null ? null : jsonEncode(next);
    final oldSig = _pinnedProduct == null ? null : jsonEncode(_pinnedProduct);
    if (nextSig == oldSig) return;
    setState(() => _pinnedProduct = next);
  }

  Future<void> _connectToBackendStream() async {
    try {
      final activeLive = LiveSessionManager.instance;
      if (activeLive.isActive &&
          activeLive.liveKitRoom != null &&
          ((_activeStreamId != null && activeLive.activeStreamId == _activeStreamId) ||
           (_trackingId != null && activeLive.trackingId == _trackingId))) {
        _liveKitRoom = activeLive.liveKitRoom;
        _attachRoomListeners(_liveKitRoom!);
        activeLive.setMinimized(false);
        _syncLocalVideoTrack();
        _syncRemoteVideoTrack();
        if (_activeStreamId != null) {
          _subscribeToRealtimeChannel(_activeStreamId!);
          _subscribeToLiveRoomChannel(_activeStreamId!);
        }
        await _pollLiveMetricsAndChat();
        return;
      }

      final api = ref.read(apiClientProvider);

      if (widget.isHost && _activeStreamId == null) {
        // Start stream on backend
        final res = await api.post(
          '/live/start',
          data: {
            'title': widget.streamTitle,
            'stream_mode': widget.streamMode,
            'background_sound': widget.backgroundSound?['title'],
            'pinned_product_id': widget.pinnedProduct != null
                ? int.tryParse(widget.pinnedProduct!['id'].toString())
                : null,
          },
        );

        final streamData = res.data['data']?['stream'] ?? res.data['stream'];
        _applyPinnedProduct(
          res.data['data']?['pinned_product'] ?? res.data['pinned_product'],
        );
        if (streamData != null && mounted) {
          final parsedHost = _parseHostName(streamData);
          setState(() {
            _activeStreamId = (streamData['id'] as num?)?.toInt();
            _trackingId ??= (streamData['tracking_id'] as String?)?.trim();
            _hostUserId =
                (streamData['user_id'] as num?)?.toInt() ??
                (streamData['user']?['id'] as num?)?.toInt();
            if (parsedHost != null) _resolvedHostName = parsedHost;
            _viewerCount = (streamData['viewers_count'] as num?)?.toInt() ?? 1;
            _likesCount = (streamData['likes_count'] as num?)?.toInt() ?? 0;
            _totalGiftsCoins =
                (streamData['total_coins_earned'] as num?)?.toInt() ?? 0;
          });
        }
        final liveKitData = res.data['data']?['livekit'] ?? res.data['livekit'];
        if (liveKitData is Map) {
          await _connectToLiveKit(
            liveKitData,
            isPublisher: widget.isHost ||
                liveKitData['is_publisher'] == true ||
                liveKitData['is_publisher'] == 1,
          );
        }
      } else if (_activeStreamId != null) {
        // Join stream as viewer
        final res = await api.post('/live/$_activeStreamId/join');
        final streamData = res.data['data']?['stream'] ?? res.data['stream'];
        _applyPinnedProduct(
          res.data['data']?['pinned_product'] ?? res.data['pinned_product'],
        );
        if (streamData != null && mounted) {
          final parsedHost = _parseHostName(streamData);
          setState(() {
            _hostUserId =
                (streamData['user_id'] as num?)?.toInt() ??
                (streamData['user']?['id'] as num?)?.toInt();
            if (parsedHost != null) _resolvedHostName = parsedHost;
            _trackingId ??= (streamData['tracking_id'] as String?)?.trim();
            _viewerCount = (streamData['viewers_count'] as num?)?.toInt() ?? 1;
            _likesCount = (streamData['likes_count'] as num?)?.toInt() ?? 0;
            _totalGiftsCoins =
                (streamData['total_coins_earned'] as num?)?.toInt() ?? 0;
          });
        }
        final liveKitData = res.data['data']?['livekit'] ?? res.data['livekit'];
        if (liveKitData is Map) {
          await _connectToLiveKit(
            liveKitData,
            isPublisher: widget.isHost ||
                liveKitData['is_publisher'] == true ||
                liveKitData['is_publisher'] == 1,
          );
        }
      } else if (_trackingId != null && _trackingId!.isNotEmpty) {
        // Resolve stream by tracking ID / token
        final resolveRes = await api.get(
          '/live/resolve/${Uri.encodeComponent(_trackingId!)}',
        );
        final payload = ApiClient.instance.unwrap(resolveRes) as Map<String, dynamic>;
        final streamData = payload['stream'] as Map<String, dynamic>?;
        if (streamData != null && mounted) {
          final parsedHost = _parseHostName(streamData);
          final parsedAvatar = _parseHostAvatarUrl(streamData);
          setState(() {
            _activeStreamId = (streamData['id'] as num?)?.toInt();
            _hostUserId = (streamData['user_id'] as num?)?.toInt() ??
                (streamData['user']?['id'] as num?)?.toInt();
            if (parsedHost != null) _resolvedHostName = parsedHost;
            if (parsedAvatar != null) _hostAvatarUrl = parsedAvatar;
            _viewerCount = (streamData['viewers_count'] as num?)?.toInt() ?? 1;
            _likesCount = (streamData['likes_count'] as num?)?.toInt() ?? 0;
            _totalGiftsCoins =
                (streamData['total_coins_earned'] as num?)?.toInt() ?? 0;
          });
        }
        if (_activeStreamId != null) {
          final joinRes = await api.post('/live/$_activeStreamId/join');
          final joinStreamData = joinRes.data['data']?['stream'] ?? joinRes.data['stream'];
          _applyPinnedProduct(
            joinRes.data['data']?['pinned_product'] ?? joinRes.data['pinned_product'],
          );
          if (joinStreamData != null && mounted) {
            final parsedHost = _parseHostName(joinStreamData);
            if (parsedHost != null) setState(() => _resolvedHostName = parsedHost);
          }
          final liveKitData = joinRes.data['data']?['livekit'] ?? joinRes.data['livekit'];
          if (liveKitData is Map) {
            await _connectToLiveKit(
              liveKitData,
              isPublisher: false,
            );
          }
        }
      }

      if (_activeStreamId != null) {
        _subscribeToRealtimeChannel(_activeStreamId!);
        _subscribeToLiveRoomChannel(_activeStreamId!);
        LiveSessionManager.instance.startLiveSession(
          streamId: _activeStreamId!,
          trackingId: _trackingId,
          streamTitle: widget.streamTitle,
          hostName: _effectiveHostName,
          hostAvatarUrl: _hostAvatarUrl,
          isHost: widget.isHost,
          streamMode: widget.streamMode,
          room: _liveKitRoom,
          videoTrack: _remoteVideoTrack ?? (widget.isHost ? _localVideoTrack : null),
        );
      }

      await _pollLiveMetricsAndChat();
    } catch (e) {
      String errorMessage = 'Failed to connect to live stream.';
      if (e is DioException) {
        final responseData = e.response?.data;
        if (responseData is Map && responseData['message'] != null) {
          errorMessage = responseData['message'].toString();
        } else if (responseData is Map && responseData['error'] != null) {
          errorMessage = responseData['error'].toString();
        } else if (e.message != null && e.message!.isNotEmpty) {
          errorMessage = e.message!;
        } else {
          final status = e.response?.statusCode;
          errorMessage = status != null
              ? 'Unable to connect to live room (Server error $status).'
              : 'Network error connecting to live stream. Please check your connection.';
        }
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }

      final errStr = errorMessage.toLowerCase();
      if (widget.isHost && (errStr.contains('kyc') || errStr.contains('403'))) {
        if (mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/app/home');
          }
          showKycRequiredLiveModal(context);
          return;
        }
      }
      // A broadcast that ended (410) or was removed (404) must not linger in the
      // session-wide "Live Now" cache, and the viewer should be cleanly returned to home.
      if (e is DioException) {
        final status = e.response?.statusCode;
        final responseData = e.response?.data;
        final isEnded = status == 410 ||
            (responseData is Map && responseData['code'] == 'STREAM_ENDED');
        if (isEnded || status == 404) {
          final idToRemove = _activeStreamId ?? widget.streamId;
          if (idToRemove != null) {
            ref.read(liveDiscoveryProvider.notifier).removeStream(idToRemove);
          }
          ref.read(liveDiscoveryProvider.notifier).refresh(silent: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This live broadcast has ended.')),
            );
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/app/home');
            }
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _connectionError = errorMessage;
        });
      }
    }
  }

  Future<void> _disposeLiveKitConnection() async {
    final listener = _liveKitListener;
    final room = _liveKitRoom;
    final localVideoTrack = _localVideoTrack;
    _liveKitListener = null;
    _liveKitRoom = null;
    _remoteVideoTrack = null;
    _localVideoTrack = null;
    _isCameraReady = false;
    listener?.dispose();
    room?.disconnect();
    room?.dispose();
    if (localVideoTrack is LocalVideoTrack) {
      try {
        await localVideoTrack.stop();
      } catch (_) {}
    }
  }

  void _attachRoomListeners(Room room) {
    _liveKitListener?.dispose();
    final listener = room.createListener();
    _liveKitListener = listener;
    listener
      ..on<AudioPlaybackStatusChanged>((event) async {
        if (!event.isPlaying) {
          try {
            await room.startAudio();
            await AudioManager.instance.setSpeakerOutputPreferred(true, force: true);
            await Hardware.instance.setSpeakerphoneOn(true);
          } catch (_) {}
        }
      })
      ..on<TrackSubscribedEvent>((event) async {
        if (event.track is AudioTrack) {
          try {
            await event.track.start();
            await AudioManager.instance.setSpeakerOutputPreferred(true, force: true);
            await Hardware.instance.setSpeakerphoneOn(true);
          } catch (e) {
            debugPrint('[LiveKit] Error starting subscribed audio track: $e');
          }
        }
        _syncRemoteVideoTrack();
      })
      ..on<TrackUnmutedEvent>((event) async {
        final track = event.publication.track;
        if (track is AudioTrack) {
          try {
            await track.start();
            await AudioManager.instance.setSpeakerOutputPreferred(true, force: true);
            await Hardware.instance.setSpeakerphoneOn(true);
          } catch (_) {}
        }
      })
      ..on<TrackUnsubscribedEvent>((_) {
        _syncRemoteVideoTrack();
      })
      ..on<ParticipantConnectedEvent>((_) {
        _syncRemoteVideoTrack();
      })
      ..on<ParticipantDisconnectedEvent>((_) {
        _syncRemoteVideoTrack();
      })
      ..on<RoomDisconnectedEvent>((_) {
        if (_isLeavingLiveKit) return;
        unawaited(_disposeLiveKitConnection());
        if (mounted) {
          setState(() {
            _connectionError = 'The live video connection ended.';
          });
        }
      });
  }

  Future<void> _connectToLiveKit(
    Map<dynamic, dynamic> credentials, {
    required bool isPublisher,
  }) async {
    if (_isConnectingLiveKit ||
        (_liveKitRoom?.connectionState == ConnectionState.connected)) {
      return;
    }

    final token = credentials['token']?.toString().trim() ?? '';
    var host = credentials['host']?.toString().trim() ?? '';
    if (host.isEmpty || host.contains('localhost') || host.contains('127.0.0.1')) {
      host = Env.apiEnv == 'production' || Env.apiEnv == 'prod'
          ? 'wss://live.murihspace.com'
          : 'wss://live-staging.murihspace.com';
    }

    if (token.isEmpty || host.isEmpty) {
      if (mounted) {
        setState(() {
          _connectionError = 'Live video credentials are unavailable.';
        });
      }
      return;
    }

    if (host.startsWith('https://')) {
      host = 'wss://${host.substring(8)}';
    } else if (host.startsWith('http://')) {
      host = 'ws://${host.substring(7)}';
    }
    host = host.replaceAll(RegExp(r'/+$'), '');

    _isConnectingLiveKit = true;
    try {
      final room = Room(
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioCaptureOptions: const AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
            highPassFilter: true,
          ),
          defaultAudioPublishOptions: isPublisher
              ? const AudioPublishOptions(
                  name: 'microphone',
                  dtx: false,
                  encoding: AudioEncoding.presetSpeech,
                )
              : const AudioPublishOptions(),
        ),
      );
      _liveKitRoom = room;
      _attachRoomListeners(room);

      await room.connect(host, token);
      if (!mounted || _isLeavingLiveKit) {
        await _disposeLiveKitConnection();
        return;
      }

      try {
        await room.startAudio();
        await AudioManager.instance.setSpeakerOutputPreferred(true, force: true);
        await Hardware.instance.setSpeakerphoneOn(true);
      } catch (e) {
        debugPrint('[LiveKit] Error starting audio: $e');
      }

      // Start and route existing remote audio tracks to speakerphone
      for (final p in room.remoteParticipants.values) {
        for (final pub in p.audioTrackPublications) {
          if (pub.subscribed && pub.track != null) {
            try {
              await pub.track!.start();
              await AudioManager.instance.setSpeakerOutputPreferred(true, force: true);
              await Hardware.instance.setSpeakerphoneOn(true);
            } catch (e) {
              debugPrint('[LiveKit] Error starting existing audio track: $e');
            }
          }
        }
      }

      if (isPublisher || widget.isHost) {
        final participant = room.localParticipant;
        if (participant != null) {
          if (_micOn) {
            try {
              final micGranted = await Permission.microphone.isGranted ||
                  (await Permission.microphone.request()).isGranted;
              if (micGranted) {
                await participant.setMicrophoneEnabled(true);
              } else {
                await participant.setMicrophoneEnabled(true);
              }
            } catch (e) {
              try {
                await participant.setMicrophoneEnabled(true);
              } catch (_) {}
            }
          }
          if (widget.streamMode != 'audio' && _cameraOn) {
            try {
              final camGranted = await Permission.camera.isGranted ||
                  (await Permission.camera.request()).isGranted;
              if (camGranted) {
                await participant.setCameraEnabled(
                  true,
                  cameraCaptureOptions: const CameraCaptureOptions(
                    cameraPosition: CameraPosition.front,
                  ),
                );
              } else {
                await participant.setCameraEnabled(
                  true,
                  cameraCaptureOptions: const CameraCaptureOptions(
                    cameraPosition: CameraPosition.front,
                  ),
                );
              }
            } catch (e) {
              try {
                await participant.setCameraEnabled(
                  true,
                  cameraCaptureOptions: const CameraCaptureOptions(
                    cameraPosition: CameraPosition.front,
                  ),
                );
              } catch (_) {}
            }
          }
        }
      }

      _syncLocalVideoTrack();
      _syncRemoteVideoTrack();
    } catch (e) {
      await _disposeLiveKitConnection();
      if (mounted && !_isLeavingLiveKit) {
        setState(() {
          _connectionError = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      _isConnectingLiveKit = false;
    }
  }

  void _syncLocalVideoTrack() {
    if (!mounted) return;
    VideoTrack? nextTrack;
    final room = _liveKitRoom;
    final publications = room?.localParticipant?.videoTrackPublications;
    if (widget.isHost && _cameraOn && publications != null) {
      for (final publication in publications) {
        final track = publication.track;
        if (!publication.muted && track is VideoTrack) {
          nextTrack = track;
          break;
        }
      }
    }
    if (identical(_localVideoTrack, nextTrack) &&
        _isCameraReady == (nextTrack != null)) {
      return;
    }
    setState(() {
      _localVideoTrack = nextTrack;
      _isCameraReady = nextTrack != null;
    });
    LiveSessionManager.instance.updateVideoTrack(
      _remoteVideoTrack ?? (widget.isHost ? _localVideoTrack : null),
    );
  }

  void _syncRemoteVideoTrack() {
    if (!mounted) return;
    VideoTrack? nextTrack;
    final room = _liveKitRoom;
    if (room != null) {
      for (final participant in room.remoteParticipants.values) {
        for (final publication in participant.videoTrackPublications) {
          final track = publication.track;
          if (publication.subscribed &&
              !publication.muted &&
              track is VideoTrack) {
            nextTrack = track;
            break;
          }
        }
        if (nextTrack != null) break;
      }
    }
    if (identical(_remoteVideoTrack, nextTrack)) return;
    setState(() {
      _remoteVideoTrack = nextTrack;
    });
    LiveSessionManager.instance.updateVideoTrack(
      _remoteVideoTrack ?? (widget.isHost ? _localVideoTrack : null),
    );
  }

  Future<void> _disconnectLiveKit() async {
    _isLeavingLiveKit = true;
    await _disposeLiveKitConnection();
  }

  Future<void> _pollLiveMetricsAndChat() async {
    if (_activeStreamId == null || !mounted) return;

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/live/$_activeStreamId');
      final streamData = res.data['data']?['stream'] ?? res.data['stream'];
      _applyPinnedProduct(
        res.data['data']?['pinned_product'] ?? res.data['pinned_product'],
      );

      if (streamData != null && mounted) {
        final parsedHost = _parseHostName(streamData);
        final parsedAvatar = _parseHostAvatarUrl(streamData);
        setState(() {
          _hostUserId ??=
              (streamData['user_id'] as num?)?.toInt() ??
              (streamData['user']?['id'] as num?)?.toInt();
          if (parsedHost != null) _resolvedHostName = parsedHost;
          if (parsedAvatar != null) _hostAvatarUrl = parsedAvatar;
          _trackingId ??= (streamData['tracking_id'] as String?)?.trim();
          _viewerCount =
              (streamData['viewers_count'] as num?)?.toInt() ?? _viewerCount;
          _likesCount =
              (streamData['likes_count'] as num?)?.toInt() ?? _likesCount;
          _totalGiftsCoins =
              (streamData['total_coins_earned'] as num?)?.toInt() ??
              _totalGiftsCoins;
        });
      }

      // Fetch latest chat messages
      final chatRes = await api.get('/live/$_activeStreamId/chat');
      final msgList =
          (chatRes.data['data']?['data'] ?? chatRes.data['data']) as List?;
      if (msgList != null && mounted) {
        final currentUserId = ref.read(authProvider).user?.id;

        // Check for newly arrived gifts to play the celebration animation
        for (final m in msgList) {
          if (m is! Map<String, dynamic>) continue;
          final id = m['id'];
          final type = m['type']?.toString();
          final text = m['message']?.toString() ?? '';
          final user = m['user'] as Map<String, dynamic>?;
          final senderId = (user?['id'] as num?)?.toInt();

          final isGiftMessage =
              type == 'gift' ||
              text.contains('🎁') ||
              text.contains('sent a gift');
          if (isGiftMessage &&
              id != null &&
              !_seenGiftMessageIds.contains(id)) {
            _seenGiftMessageIds.add(id);

            // If not sent by current user (since sender already triggered immediate animation)
            if (senderId != currentUserId) {
              final senderName = user?['name'] ?? 'A Viewer';
              final giftName = m['gift_name']?.toString() ?? 'Celebration Gift';
              final coinPrice = (m['coin_price'] as num?)?.toInt() ?? 100;
              final animType = m['animation_type']?.toString().isNotEmpty == true
                  ? m['animation_type']!.toString()
                  : (coinPrice >= 1000
                        ? 'full_screen'
                        : (coinPrice >= 400
                              ? 'premium'
                              : (coinPrice <= 20 ? 'micro' : 'standard')));

              ref
                  .read(giftAnimationProvider.notifier)
                  .play(
                    GiftAnimationData(
                      giftName: giftName,
                      iconUrl: (m['gift_icon_url'] ??
                              m['icon_url'])
                          ?.toString(),
                      iconEmoji: GiftOption.emojiFor(giftName),
                      coinPrice: coinPrice,
                      senderName: senderName,
                      recipientName: _effectiveHostName,
                      animationType: animType,
                    ),
                  );
            }
          }
        }

        final parsed = msgList.map((m) {
          final user = m['user'] as Map<String, dynamic>?;
          return {
            'id': m['id'],
            'name': user?['name'] ?? 'Viewer',
            'role': user?['role'] ?? 'Member',
            'msg': m['message'] ?? '',
            'color': DesignTokens.primary,
          };
        }).toList();

        final hadNewMessages = parsed.length > _chatMessages.length ||
            (parsed.isNotEmpty && _chatMessages.isEmpty);
        setState(() {
          _chatMessages.clear();
          _chatMessages.addAll(parsed);
        });
        if (hadNewMessages) {
          _scrollToBottom();
        }
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _leaveViewerStream() async {
    if (_leaveSent || widget.isHost || _activeStreamId == null) return;
    _leaveSent = true;
    try {
      await ref.read(apiClientProvider).post('/live/$_activeStreamId/leave');
    } catch (_) {}
  }

  @override
  void dispose() {
    final isMinimized = LiveSessionManager.instance.isMinimized;
    if (!isMinimized) {
      LiveSessionManager.instance.onTeardown = null;
      unawaited(_leaveViewerStream());
      final streamIdToEnd = _activeStreamId ?? widget.streamId;
      if (widget.isHost && streamIdToEnd != null && !_hostEndedStream) {
        _hostEndedStream = true;
        unawaited(ref.read(apiClientProvider).post('/live/$streamIdToEnd/end'));
        ref.read(liveDiscoveryProvider.notifier).removeStream(streamIdToEnd);
        ref.read(liveDiscoveryProvider.notifier).refresh(silent: true);
      }
      unawaited(_disconnectLiveKit());
      LiveSessionManager.instance.closeLive();
    }
    _metricsTimer?.cancel();
    _likeDebounceTimer?.cancel();
    _likeDebounceTimer = null;
    // Flush the like batch pending in the debounce window so likes aren't lost
    // when the viewer leaves mid-rap.
    unawaited(_flushPendingLikes());
    _realtimeSub?.cancel();
    if (_subscribedLiveChannel != null) {
      try {
        ref.read(realtimeProvider).unsubscribe(_subscribedLiveChannel!);
      } catch (_) {}
    }
    _liveRoomSub?.cancel();
    if (_subscribedLiveRoomChannel != null) {
      try {
        ref.read(realtimeProvider).unsubscribe(_subscribedLiveRoomChannel!);
      } catch (_) {}
    }
    _chatCtrl.dispose();
    _chatFocusNode.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  Future<void> _toggleMic() async {
    final participant = _liveKitRoom?.localParticipant;
    final next = !_micOn;
    setState(() => _micOn = next);
    if (participant != null) {
      try {
        if (next) {
          final granted = await Permission.microphone.isGranted ||
              (await Permission.microphone.request()).isGranted;
          if (granted) {
            await participant.setMicrophoneEnabled(true);
          } else {
            await participant.setMicrophoneEnabled(true);
          }
        } else {
          await participant.setMicrophoneEnabled(false);
        }
      } catch (e) {
        try {
          await participant.setMicrophoneEnabled(next);
        } catch (_) {}
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_isSwitchingCamera) return;
    final localTrack = _localVideoTrack;
    final participant = _liveKitRoom?.localParticipant;
    if (localTrack is! LocalVideoTrack || participant == null) return;

    setState(() => _isSwitchingCamera = true);
    try {
      final nextPosition = _isFrontCamera
          ? CameraPosition.back
          : CameraPosition.front;
      await localTrack.setCameraPosition(nextPosition);
      if (mounted) {
        setState(() {
          _isFrontCamera = !_isFrontCamera;
          _isSwitchingCamera = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSwitchingCamera = false);
      }
    }
  }

  Future<void> _sendChat() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).user;
    setState(() {
      _chatMessages.add({
        'name': user?.name ?? 'You',
        'role': widget.isHost ? 'Host' : 'Viewer',
        'msg': text,
        'color': widget.isHost
            ? const Color(0xFFFF3B30)
            : DesignTokens.primary,
      });
      _chatCtrl.clear();
    });

    if (_activeStreamId != null) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post('/live/$_activeStreamId/chat', data: {'message': text});
      } catch (_) {}
    }

    _scrollToBottom();
  }

  void _spawnVisualHeart({double? x, double? y}) {
    if (!mounted) return;
    if (_hearts.length > 25) {
      _hearts.removeAt(0);
    }
    final screenSize = MediaQuery.of(context).size;
    final startX = x ?? (screenSize.width - 50 + (_random.nextDouble() * 30 - 15));
    final startY = y ?? (screenSize.height - 120);

    setState(() {
      _hearts.add(
        _FloatingHeart(
          id: DateTime.now().microsecondsSinceEpoch + _random.nextInt(1000),
          startX: startX,
          startY: startY,
          color: const [
            Color(0xFFFF2D55),
            Color(0xFFFF375F),
            Color(0xFFFF9500),
            Color(0xFFFFCC00),
            Color(0xFFAF52DE),
            Color(0xFF5856D6),
            Color(0xFF30D158),
            DesignTokens.primary,
          ][_random.nextInt(8)],
          swayAmplitude: 14.0 + _random.nextDouble() * 14.0,
          swayPhase: _random.nextDouble() * 2 * pi,
          size: 26.0 + _random.nextDouble() * 10.0,
        ),
      );
    });
  }

  void _addHeart({double? x, double? y}) {
    _spawnVisualHeart(x: x, y: y);
    setState(() => _likesCount += 1);

    _pendingLikesBatch += 1;
    _likeDebounceTimer?.cancel();
    _likeDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_flushPendingLikes());
    });
  }

  Future<void> _flushPendingLikes() async {
    final count = _pendingLikesBatch;
    _pendingLikesBatch = 0;
    if (_activeStreamId != null && count > 0) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post('/live/$_activeStreamId/like', data: {'count': count});
      } catch (_) {}
    }
  }

  void _subscribeToRealtimeChannel(int streamId) {
    if (_subscribedLiveChannel == 'live-stream.$streamId') return;
    if (_subscribedLiveChannel != null) {
      ref.read(realtimeProvider).unsubscribe(_subscribedLiveChannel!);
    }
    _subscribedLiveChannel = 'live-stream.$streamId';
    final realtime = ref.read(realtimeProvider);
    realtime.subscribe(_subscribedLiveChannel!);

    _realtimeSub?.cancel();
    _realtimeSub = realtime.events.listen((event) {
      if (event.channel != _subscribedLiveChannel) return;
      final eventName = event.event.replaceFirst(RegExp(r'^\.+'), '');
      final data = event.data is Map ? Map<String, dynamic>.from(event.data as Map) : <String, dynamic>{};

      if (eventName == 'LiveStreamLiked' || event.event.contains('LiveStreamLiked')) {
        _handleRealtimeLike(data);
      } else if (eventName == 'LiveStreamGiftSent' || event.event.contains('LiveStreamGiftSent')) {
        _handleRealtimeGift(data);
      } else if (eventName == 'LiveStreamChatMessage' || event.event.contains('LiveStreamChatMessage')) {
        _handleRealtimeChatMessage(data);
      } else if (eventName == 'LiveStreamProductPinned' || event.event.contains('LiveStreamProductPinned')) {
        _handleRealtimeProductPinned(data);
      } else if (eventName == 'LiveStreamProductUnpinned' || event.event.contains('LiveStreamProductUnpinned')) {
        _handleRealtimeProductUnpinned();
      } else if (eventName == 'LiveStreamCommentPinned' || event.event.contains('LiveStreamCommentPinned')) {
        _handleRealtimeCommentPinned(data);
      } else if (eventName == 'LiveStreamCommentUnpinned' || event.event.contains('LiveStreamCommentUnpinned')) {
        _handleRealtimeCommentUnpinned();
      } else if (eventName == 'LiveStreamViewerCountUpdated' || event.event.contains('LiveStreamViewerCountUpdated')) {
        _handleRealtimeViewerCount(data);
      } else if (eventName == 'LiveStreamEnded' || event.event.contains('LiveStreamEnded')) {
        _handleRealtimeStreamEnded(data);
      }
    });
  }

  void _handleRealtimeStreamEnded(Map<String, dynamic> data) {
    if (!mounted) return;
    final streamId = _activeStreamId ?? widget.streamId;
    if (streamId != null) {
      ref.read(liveDiscoveryProvider.notifier).removeStream(streamId);
      ref.read(liveDiscoveryProvider.notifier).refresh(silent: true);
    }
    LiveSessionManager.instance.closeLive();
    unawaited(_disconnectLiveKit());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The host has ended this live broadcast.')),
    );
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/app/home');
    }
  }

  /// Private `live-room.{id}` channel: carries roster and moderation events for
  /// the host, moderators, and active participants. A promoted co-host learns
  /// here that they may now publish, so their microphone can be enabled without
  /// the user manually rejoining.
  void _subscribeToLiveRoomChannel(int streamId) {
    final channelName = 'private-live-room.$streamId';
    if (_subscribedLiveRoomChannel == channelName) return;
    if (_subscribedLiveRoomChannel != null) {
      ref.read(realtimeProvider).unsubscribe(_subscribedLiveRoomChannel!);
    }
    _subscribedLiveRoomChannel = channelName;
    final realtime = ref.read(realtimeProvider);
    realtime.subscribe(channelName);

    _liveRoomSub?.cancel();
    _liveRoomSub = realtime.events.listen((event) {
      if (event.channel != _subscribedLiveRoomChannel) return;
      final eventName = event.event.replaceFirst(RegExp(r'^\.+'), '');
      if (eventName != 'LiveStreamParticipantPresence' &&
          !event.event.contains('LiveStreamParticipantPresence')) {
        return;
      }
      final data = event.data is Map
          ? Map<String, dynamic>.from(event.data as Map)
          : <String, dynamic>{};
      _handleParticipantPresence(data);
    });
  }

  void _handleParticipantPresence(Map<String, dynamic> data) {
    if (!mounted) return;
    final participant = (data['participant'] ?? data['participant_payload']) is Map
        ? Map<String, dynamic>.from((data['participant'] ?? data['participant_payload']) as Map)
        : <String, dynamic>{};
    final userId = (participant['user_id'] as num?)?.toInt();

    // Keep an open roster sheet fresh.
    if (_isParticipantsSheetOpen && userId != null) {
      final index = _participants.indexWhere((p) => (p['user_id'] as num?)?.toInt() == userId);
      if (index >= 0) {
        _participants[index] = {..._participants[index], ...participant};
      } else {
        _participants.add(participant);
      }
      _participantsModalSetState?.call(() {});
    }

    // React to our own role change so a promoted co-host can speak.
    final myId = ref.read(authProvider).user?.id;
    final isSelf = myId != null && userId != null && userId == myId;
    if (!isSelf) return;

    final role = participant['role']?.toString();
    final restricted = participant['is_restricted'] == true;
    final canPublish = !restricted && (role == 'co_host' || role == 'moderator' || role == 'host');
    final wasPublisher = _selfIsCoHost;
    setState(() => _selfIsCoHost = canPublish);

    if (canPublish && !wasPublisher && !widget.isHost) {
      unawaited(_ensureMicEnabled());
    } else if (!canPublish && !widget.isHost) {
      unawaited(_forceMicDisabled());
    }
  }

  /// Enables the local microphone for a newly-promoted co-host/moderator.
  Future<void> _ensureMicEnabled() async {
    final participant = _liveKitRoom?.localParticipant;
    if (participant == null) return;
    try {
      await participant.setMicrophoneEnabled(true);
      if (mounted) setState(() => _micOn = true);
    } catch (_) {}
  }

  /// Revokes local publishing when the host restricts or demotes us.
  Future<void> _forceMicDisabled() async {
    final participant = _liveKitRoom?.localParticipant;
    if (participant == null) return;
    try {
      await participant.setMicrophoneEnabled(false);
    } catch (_) {}
    if (mounted) setState(() => _micOn = false);
  }

  bool get _canModerate =>
      widget.isHost ||
      _selfIsCoHost ||
      (_hostUserId != null && ref.read(authProvider).user?.id == _hostUserId);

  Future<void> _fetchParticipants() async {
    final streamId = _activeStreamId;
    if (streamId == null) return;
    setState(() => _isFetchingParticipants = true);
    try {
      final res = await ref.read(apiClientProvider).get('/live/$streamId/participants');
      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final payload = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;
      final list = payload['participants'] is List ? payload['participants'] as List : const [];
      if (!mounted) return;
      setState(() {
        _participants
          ..clear()
          ..addAll(list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
      });
      _participantsModalSetState?.call(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load participants.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingParticipants = false);
        _participantsModalSetState?.call(() {});
      }
    }
  }

  Future<void> _openParticipantsSheet() async {
    if (!_canModerate) return;
    setState(() => _isParticipantsSheetOpen = true);
    await _fetchParticipants();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          _participantsModalSetState = setModalState;
          return _LiveParticipantsSheet(
            participants: _participants,
            isFetching: _isFetchingParticipants,
            isBusy: _isParticipantBusy,
            hostUserId: _hostUserId,
            onPromote: (userId) => _moderateParticipant(userId, role: 'co_host'),
            onDemote: (userId) => _moderateParticipant(userId, role: 'viewer'),
            onToggleRestrict: (userId, restricted) =>
                _moderateParticipant(userId, restricted: restricted),
            onRemove: (userId) => _moderateParticipant(userId, remove: true),
            onRefresh: _fetchParticipants,
          );
        },
      ),
    );
    _participantsModalSetState = null;
    if (mounted) setState(() => _isParticipantsSheetOpen = false);
  }

  Future<void> _moderateParticipant(
    int userId, {
    String? role,
    bool? restricted,
    bool remove = false,
  }) async {
    final streamId = _activeStreamId;
    if (streamId == null || _isParticipantBusy) return;
    setState(() => _isParticipantBusy = true);
    _participantsModalSetState?.call(() {});
    try {
      final path = remove
          ? '/live/$streamId/participants/$userId'
          : role != null
              ? '/live/$streamId/participants/$userId/role'
              : '/live/$streamId/participants/$userId/restrict';
      final data = remove
          ? null
          : role != null
              ? {'role': role}
              : {'restricted': restricted ?? true};
      final api = ref.read(apiClientProvider);
      final res = remove
          ? await api.delete(path)
          : await api.post(path, data: data);
      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final payload = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;
      final list = payload['participants'] is List ? payload['participants'] as List : null;
      if (!mounted) return;
      if (list != null) {
        setState(() {
          _participants
            ..clear()
            ..addAll(list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        });
        _participantsModalSetState?.call(() {});
      } else {
        await _fetchParticipants();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isParticipantBusy = false);
        _participantsModalSetState?.call(() {});
      }
    }
  }

  void _handleRealtimeLike(Map<String, dynamic> data) {
    if (!mounted) return;
    final totalLikes = (data['total_likes'] as num?)?.toInt();
    final count = (data['count'] as num?)?.toInt() ?? 1;

    setState(() {
      if (totalLikes != null) {
        _likesCount = totalLikes;
      } else {
        _likesCount += count;
      }
      final spawnCount = min(count, 5);
      for (int i = 0; i < spawnCount; i++) {
        _spawnVisualHeart();
      }
    });
  }

  void _handleRealtimeGift(Map<String, dynamic> data) {
    if (!mounted) return;
    final totalCoins = (data['total_coins_earned'] as num?)?.toInt();
    final gift = data['gift'] is Map ? Map<String, dynamic>.from(data['gift'] as Map) : <String, dynamic>{};
    final sender = data['sender'] is Map ? Map<String, dynamic>.from(data['sender'] as Map) : <String, dynamic>{};

    final giftName = gift['name']?.toString() ?? 'Virtual Gift';
    final senderName = sender['name']?.toString() ?? 'Someone';
    final coinPrice = (gift['coin_price'] as num?)?.toInt() ?? 100;
    final animType = gift['animation_tier']?.toString() ??
        (coinPrice >= 1000 ? 'full_screen' : (coinPrice >= 400 ? 'premium' : 'standard'));

    setState(() {
      if (totalCoins != null) {
        _totalGiftsCoins = totalCoins;
      }
    });

    ref.read(giftAnimationProvider.notifier).play(
      GiftAnimationData(
        giftName: giftName,
        iconEmoji: '🎁',
        iconUrl: gift['icon_url']?.toString(),
        coinPrice: coinPrice,
        senderName: senderName,
        recipientName: _effectiveHostName,
        animationType: animType,
      ),
    );
  }

  void _handleRealtimeChatMessage(Map<String, dynamic> data) {
    if (!mounted) return;
    final msg = data['message'] is Map ? Map<String, dynamic>.from(data['message'] as Map) : <String, dynamic>{};
    final msgId = msg['id'];
    if (msgId != null && _seenGiftMessageIds.contains(msgId)) return;
    if (msgId != null) _seenGiftMessageIds.add(msgId);

    final user = msg['user'] is Map ? Map<String, dynamic>.from(msg['user'] as Map) : <String, dynamic>{};
    final userName = user['name']?.toString() ?? 'Viewer';
    final text = msg['message']?.toString() ?? '';
    final isHost = user['role'] == 'creator' || user['id'] == _hostUserId;

    setState(() {
      _chatMessages.add({
        'id': msgId,
        'name': userName,
        'role': isHost ? 'Host' : (msg['gift_id'] != null ? 'Gift' : 'Viewer'),
        'msg': text,
        'avatar': user['avatar_url'] ?? user['avatar'],
        'color': isHost ? const Color(0xFFFF2D55) : DesignTokens.primary,
      });
    });
    _scrollToBottom();
  }

  void _handleRealtimeProductPinned(Map<String, dynamic> data) {
    if (!mounted) return;
    final product = data['product'] is Map ? Map<String, dynamic>.from(data['product'] as Map) : null;
    if (product != null) {
      _applyPinnedProduct(product);
    }
  }

  void _handleRealtimeProductUnpinned() {
    if (!mounted) return;
    setState(() => _pinnedProduct = null);
  }

  void _handleRealtimeCommentPinned(Map<String, dynamic> data) {
    if (!mounted) return;
    final comment = data['comment'] is Map ? Map<String, dynamic>.from(data['comment'] as Map) : null;
    setState(() => _pinnedComment = comment);
  }

  void _handleRealtimeCommentUnpinned() {
    if (!mounted) return;
    setState(() => _pinnedComment = null);
  }

  void _handleRealtimeViewerCount(Map<String, dynamic> data) {
    if (!mounted) return;
    final count = (data['viewers_count'] as num?)?.toInt();
    if (count != null) {
      setState(() => _viewerCount = count);
    }
  }

  void _openGiftingModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SendGiftDialog(
        recipientId: _hostUserId ?? 1,
        recipientName: _effectiveHostName,
        onGiftSent: (gift, amount) {
          // Update user wallet state and total stream coins
          ref.read(authProvider.notifier).refreshProfile();

          setState(() {
            _totalGiftsCoins += amount;
            _chatMessages.add({
              'name': 'System',
              'role': 'Gift',
              'msg': '🎁 You sent ${gift.name} (🪙 +$amount MSH)!',
              'color': const Color(0xFFFF9500),
            });
          });
          _scrollToBottom();

          if (_activeStreamId != null) {
            try {
              final api = ref.read(apiClientProvider);
              api.post(
                '/live/$_activeStreamId/gift',
                data: {'gift_id': gift.id, 'message': 'Sent ${gift.name}'},
              );
            } catch (_) {}
          }
        },
      ),
    );
  }

  String _streamProductPrice(Map<String, dynamic> product) {
    final symbol =
        product['symbol']?.toString() ??
        (product['currency'] == 'NGN'
            ? '₦'
            : (product['currency'] == 'EUR'
                  ? '€'
                  : (product['currency'] == 'GBP' ? '£' : '\$')));
    final raw = product['price'];
    final price = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0;
    return '$symbol${price.toStringAsFixed(2)}';
  }

  Widget _streamProductImage(Map<String, dynamic> product, double size) {
    final images =
        (product['images'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final cover =
        product['cover_url']?.toString() ??
        (images.isNotEmpty ? images.first : null);
    final url = ApiClient.resolveUrl(cover);
    final fallback = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Color(0xFFFF9500)),
      child: Icon(
        Icons.shopping_bag_rounded,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  void _openProductBuySheet() {
    final product = _pinnedProduct;
    final streamId = _activeStreamId;
    if (product == null || streamId == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LiveProductBuySheet(
        streamId: streamId,
        product: product,
        isHost: widget.isHost,
        onPurchased: () {
          ref.read(authProvider.notifier).refreshProfile();
        },
      ),
    );
  }

  Future<void> _openShareModal() async {
    // The share link must resolve to the real stream (activity) and its host
    // (user). Never fabricate an id: wait for the backend to assign one.
    int? streamId = _activeStreamId ?? widget.streamId;
    streamId ??= await _waitForStreamId();

    if ((streamId == null || streamId <= 0) &&
        (_trackingId == null || _trackingId!.trim().isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Initializing live broadcast room. Please try sharing again in a moment.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final liveUrl = Env.liveStreamUrl(
      streamId ?? 0,
      hostUserId: _hostUserId,
      trackingId: _trackingId,
    );
    final shareMessage =
        '🔴 Watch $_effectiveHostName live on MurihSpace: "${widget.streamTitle}"\n$liveUrl';

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
        final textPrimary = isDark ? Colors.white : Colors.black;
        final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Title Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sensors, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share Live Broadcast',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Invite friends to join $_effectiveHostName\'s stream',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // In-app Sharing: Friends, Groups & Communities
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Send to',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ShareOptionItem(
                      icon: Icons.person_add_alt_1_rounded,
                      color: DesignTokens.primary,
                      label: 'Friends',
                      onTap: () {
                        Navigator.pop(ctx);
                        _openLiveShareRecipientSheet(
                          title: 'Send to a friend',
                          conversationTypes: const ['direct'],
                          allowsUserSearch: true,
                          shareMessage: shareMessage,
                        );
                      },
                    ),
                    _ShareOptionItem(
                      icon: Icons.groups_rounded,
                      color: const Color(0xFF34C759),
                      label: 'Groups',
                      onTap: () {
                        Navigator.pop(ctx);
                        _openLiveShareRecipientSheet(
                          title: 'Share to a group',
                          conversationTypes: const ['group'],
                          allowsUserSearch: false,
                          shareMessage: shareMessage,
                        );
                      },
                    ),
                    _ShareOptionItem(
                      icon: Icons.public_rounded,
                      color: const Color(0xFFFF9500),
                      label: 'Communities',
                      onTap: () {
                        Navigator.pop(ctx);
                        _openLiveShareRecipientSheet(
                          title: 'Share to a community',
                          conversationTypes: const ['community'],
                          allowsUserSearch: false,
                          shareMessage: shareMessage,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Quick Share Options (2nd)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Share to apps',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ShareOptionItem(
                      icon: FontAwesomeIcons.whatsapp,
                      color: const Color(0xFF25D366),
                      iconColor: const Color(0xFF25D366),
                      label: 'WhatsApp',
                      onTap: () async {
                        Navigator.pop(ctx);
                        final waUrl = Uri.parse(
                          'https://wa.me/?text=${Uri.encodeComponent(shareMessage)}',
                        );
                        if (await canLaunchUrl(waUrl)) {
                          await launchUrl(
                            waUrl,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                    _ShareOptionItem(
                      icon: FontAwesomeIcons.xTwitter,
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFF0F1419),
                      iconColor: isDark ? Colors.white : Colors.black,
                      label: 'X (Twitter)',
                      onTap: () async {
                        Navigator.pop(ctx);
                        final xUrl = Uri.parse(
                          'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(shareMessage)}',
                        );
                        if (await canLaunchUrl(xUrl)) {
                          await launchUrl(
                            xUrl,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                    _ShareOptionItem(
                      icon: FontAwesomeIcons.solidCommentDots,
                      color: const Color(0xFF34C759),
                      iconColor: const Color(0xFF34C759),
                      label: 'Messages',
                      onTap: () async {
                        Navigator.pop(ctx);
                        final smsUrl = Uri.parse(
                          'sms:?body=${Uri.encodeComponent(shareMessage)}',
                        );
                        if (await canLaunchUrl(smsUrl)) {
                          await launchUrl(smsUrl);
                        }
                      },
                    ),
                    _ShareOptionItem(
                      icon: FontAwesomeIcons.solidEnvelope,
                      color: const Color(0xFFEA4335),
                      iconColor: const Color(0xFFEA4335),
                      label: 'Email',
                      onTap: () async {
                        Navigator.pop(ctx);
                        final mailUrl = Uri.parse(
                          'mailto:?subject=${Uri.encodeComponent('Join $_effectiveHostName\'s Live on MurihSpace')}&body=${Uri.encodeComponent(shareMessage)}',
                        );
                        if (await canLaunchUrl(mailUrl)) {
                          await launchUrl(mailUrl);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Link Copy Box (3rd)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Copy link',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        color: DesignTokens.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          liveUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedActionFeedbackButton(
                        idleLabel: 'Copy',
                        idleIcon: Icons.copy_rounded,
                        activeLabel: 'Copied!',
                        activeIcon: Icons.check_rounded,
                        onAction: () async {
                          await Clipboard.setData(ClipboardData(text: liveUrl));
                        },
                        onComplete: () {
                          if (Navigator.canPop(ctx)) {
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Waits a short while for the backend to assign the stream id so the share
  /// link is always tied to the real stream instead of a placeholder id.
  Future<int?> _waitForStreamId() async {
    for (var i = 0; i < 10 && _activeStreamId == null && mounted; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return _activeStreamId ?? widget.streamId;
  }

  void _openLiveShareRecipientSheet({
    required String title,
    required List<String> conversationTypes,
    required bool allowsUserSearch,
    required String shareMessage,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LiveShareRecipientSheet(
        title: title,
        conversationTypes: conversationTypes,
        allowsUserSearch: allowsUserSearch,
        shareMessage: shareMessage,
        onSend: _sendLiveToConversation,
      ),
    );
  }

  /// Sends the live broadcast link as a message into the chosen conversation.
  Future<void> _sendLiveToConversation(
    Conversation conversation,
    String shareMessage,
  ) async {
    if (conversation.id <= 0) return;
    try {
      await ref
          .read(conversationMessagesProvider(conversation.id).notifier)
          .sendMessage(content: shareMessage, attachmentType: 'live_stream');
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _endOrLeaveStream() async {
    final isHost = widget.isHost;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isHost ? 'End Live Broadcast?' : 'Leave Live Stream?'),
        content: Text(
          isHost
              ? 'Ending the broadcast will notify all viewers and save your stream statistics.'
              : 'Are you sure you want to leave this live room?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isHost ? 'End Stream' : 'Leave Room'),
          ),
        ],
      ),
    );

    if (shouldLeave == true && mounted) {
      LiveSessionManager.instance.onTeardown = null;
      LiveSessionManager.instance.closeLive();
      await _disconnectLiveKit();
      final streamIdToEnd = _activeStreamId ?? widget.streamId ?? LiveSessionManager.instance.activeStreamId;
      if (isHost && streamIdToEnd != null) {
        _hostEndedStream = true;
        try {
          final api = ref.read(apiClientProvider);
          await api.post('/live/$streamIdToEnd/end');
        } catch (e) {
          debugPrint('[LiveStream] End stream error: $e');
        }
      } else if (!isHost && streamIdToEnd != null) {
        await _leaveViewerStream();
      }

      // Immediately purge the ended broadcast from discovery cache and request a silent refresh
      if (streamIdToEnd != null) {
        ref.read(liveDiscoveryProvider.notifier).removeStream(streamIdToEnd);
      }
      ref.read(liveDiscoveryProvider.notifier).refresh(silent: true);

      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/app/home');
        }
      }
    }
  }

  void _minimizeLiveStream() {
    if (_activeStreamId == null) return;
    final api = ref.read(apiClientProvider);
    final realtime = ref.read(realtimeProvider);
    final streamId = _activeStreamId!;
    final isHost = widget.isHost;
    final liveChannel = _subscribedLiveChannel;
    final roomChannel = _subscribedLiveRoomChannel;

    LiveSessionManager.instance.onTeardown = () async {
      if (!isHost && !_leaveSent) {
        _leaveSent = true;
        try {
          await api.post('/live/$streamId/leave');
        } catch (_) {}
      }
      await _disconnectLiveKit();
      _realtimeSub?.cancel();
      if (liveChannel != null) {
        try {
          realtime.unsubscribe(liveChannel);
        } catch (_) {}
      }
      _liveRoomSub?.cancel();
      if (roomChannel != null) {
        try {
          realtime.unsubscribe(roomChannel);
        } catch (_) {}
      }
    };
    LiveSessionManager.instance.minimizeLive(context);
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final walletCoins = ref.watch(walletProvider).coinsBalance;
    final authCoins = authUser?.coins ?? 0;
    final coinBalance = walletCoins > 0 ? walletCoins : authCoins;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = viewInsetsBottom > 0;
    final hasChatText = _chatCtrl.text.trim().isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!widget.isHost &&
            _activeStreamId != null &&
            LiveSessionManager.instance.isActive) {
          _minimizeLiveStream();
        } else {
          await _endOrLeaveStream();
        }
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (details) {
          if (_chatFocusNode.hasFocus) {
            _chatFocusNode.unfocus();
          } else {
            _addHeart(x: details.localPosition.dx, y: details.localPosition.dy);
          }
          // Resume audio if system suspended it
          try {
            _liveKitRoom?.startAudio();
            AudioManager.instance.setSpeakerOutputPreferred(true, force: true);
            Hardware.instance.setSpeakerphoneOn(true);
          } catch (_) {}
        },
        child: Stack(
          children: [
            if (widget.isHost && _localVideoTrack != null && _cameraOn)
              SizedBox.expand(
                child: Transform.scale(
                  scaleX: _isFrontCamera ? -1 : 1,
                  child: VideoTrackRenderer(
                    _localVideoTrack!,
                    fit: widget.streamMode == 'audio'
                        ? VideoViewFit.contain
                        : VideoViewFit.cover,
                  ),
                ),
              )
            else if (!widget.isHost && _remoteVideoTrack != null)
              SizedBox.expand(
                child: VideoTrackRenderer(
                  _remoteVideoTrack!,
                  fit: _remoteVideoTrack!.source == TrackSource.screenShareVideo
                      ? VideoViewFit.contain
                      : VideoViewFit.cover,
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1C1C1E), Color(0xFF0A0D12)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LiveRingAvatar(
                        avatarUrl: _hostAvatarUrl,
                        // _effectiveHostName can be a "@username" handle — strip the
                        // prefix so the fallback shows the host's initial, not "@".
                        fallbackInitial: _hostInitial,
                        radius: 46,
                        isLive: true,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.streamTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hosted by $_effectiveHostName${widget.communityName != null ? ' in ${widget.communityName}' : ''}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      if (_connectionError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF3B30,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _connectionError!,
                            style: const TextStyle(
                              color: Color(0xFFFF3B30),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // 2. Floating Animated Hearts Layer
            ..._hearts.map(
              (heart) => _FloatingHeartWidget(
                key: ValueKey(heart.id),
                heart: heart,
                onComplete: () {
                  if (mounted) setState(() => _hearts.remove(heart));
                },
              ),
            ),

            // 3. Pinned product available for in-stream purchase
            if (_pinnedProduct != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 58,
                left: 16,
                child: GestureDetector(
                  onTap: _openProductBuySheet,
                  child: Container(
                    width: 210,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14181F).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      children: [
                        _streamProductImage(_pinnedProduct!, 40),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _pinnedProduct!['title']?.toString() ??
                                    _pinnedProduct!['name']?.toString() ??
                                    'Product',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _streamProductPrice(_pinnedProduct!),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFF9500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isHost
                                ? Colors.white24
                                : const Color(0xFFFF9500),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.isHost ? 'Pinned' : 'Buy',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: widget.isHost
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 4. Top Header Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: LiveStreamTopHeader(
                viewerCount: _viewerCount,
                coinBalance: coinBalance,
                onShare: _openShareModal,
                onMinimize: _minimizeLiveStream,
                onClose: _endOrLeaveStream,
              ),
            ),

            // 4b. Host engagement counters (likes + gift coins).
            if (widget.isHost)
              Positioned(
                top: MediaQuery.of(context).padding.top +
                    (_pinnedProduct != null ? 126 : 58),
                left: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LiveStatChip(
                      icon: Icons.favorite_rounded,
                      color: const Color(0xFFFF2D55),
                      value: _likesCount,
                    ),
                    const SizedBox(width: 8),
                    _LiveStatChip(
                      icon: Icons.monetization_on_rounded,
                      color: const Color(0xFFFFCC00),
                      value: _totalGiftsCoins,
                    ),
                  ],
                ),
              ),

            // 5. TikTok-Style Live Chat Feed Overlay (Transparent, popping below, constrained height, no scrollbars)
            Positioned(
              bottom: viewInsetsBottom + 66,
              left: 16,
              width: min(MediaQuery.of(context).size.width * 0.78, 300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pinnedComment != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: DesignTokens.primary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: DesignTokens.primary.withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.push_pin, size: 12, color: Color(0xFF64D2FF)),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '${_pinnedComment!['user']?['name'] ?? 'Viewer'}: ${_pinnedComment!['message'] ?? ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(
                    height: isKeyboardOpen ? 130 : 210,
                    child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.white],
                    stops: [0.0, 0.20],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: ScrollConfiguration(
                    behavior:
                        const ScrollBehavior().copyWith(scrollbars: false),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: ListView.separated(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _chatMessages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 5),
                      itemBuilder: (context, idx) {
                        final msg = _chatMessages[idx];
                        final isHost =
                            msg['name'] == widget.hostName ||
                            msg['role'] == 'Host';
                        final isGift =
                            (msg['msg'] as String).contains('🎁') ||
                            msg['type'] == 'gift';

                        return _TikTokLiveMessageBubble(
                          key: ValueKey(msg['id'] ?? idx),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isGift
                                    ? const Color(
                                        0xFFFF9500,
                                      ).withValues(alpha: 0.30)
                                    : Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isGift
                                      ? const Color(
                                          0xFFFF9500,
                                        ).withValues(alpha: 0.45)
                                      : Colors.white.withValues(alpha: 0.10),
                                  width: 0.5,
                                ),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text:
                                          '${msg['name']}${isHost ? ' (Host)' : ''}: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                        color: isHost
                                            ? const Color(0xFFFFCC00)
                                            : const Color(0xFF38BDF8),
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextSpan(
                                      text: msg['msg'] as String,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black87,
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

            // 6. Facebook-Style Bottom Controls & High-Contrast Chat Input Bar
            Positioned(
              bottom:
                  viewInsetsBottom +
                  (isKeyboardOpen
                      ? 8
                      : (MediaQuery.of(context).padding.bottom + 12)),
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E232B).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(23),
                        border: Border.all(
                          color: _chatFocusNode.hasFocus
                              ? DesignTokens.primary
                              : Colors.white.withValues(alpha: 0.25),
                          width: _chatFocusNode.hasFocus ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: _chatFocusNode.hasFocus
                                ? DesignTokens.primary
                                : Colors.white70,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Theme(
                              data: ThemeData.dark().copyWith(
                                textSelectionTheme:
                                    const TextSelectionThemeData(
                                      cursorColor: DesignTokens.primary,
                                      selectionColor: Color(0x66007AFF),
                                      selectionHandleColor: DesignTokens.primary,
                                    ),
                              ),
                              child: TextField(
                                controller: _chatCtrl,
                                focusNode: _chatFocusNode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                cursorColor: DesignTokens.primary,
                                cursorWidth: 2.0,
                                decoration: const InputDecoration(
                                  hintText: 'Say something live…',
                                  hintStyle: TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  isDense: true,
                                  filled: false,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                onSubmitted: (_) => _sendChat(),
                              ),
                            ),
                          ),
                          if (hasChatText) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: _sendChat,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: DesignTokens.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Share Button in Bottom Bar (hidden while typing to maximize input area if needed)
                  if (!isKeyboardOpen) ...[
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF1E232B,
                        ).withValues(alpha: 0.92),
                        padding: const EdgeInsets.all(10),
                      ),
                      icon: const Icon(
                        Icons.share_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _openShareModal,
                    ),
                  ],

                  // Host Controls: Microphone Toggle
                  if (widget.isHost) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: _micOn
                            ? const Color(0xFF1E232B).withValues(alpha: 0.92)
                            : const Color(0xFFFF3B30),
                        padding: const EdgeInsets.all(10),
                      ),
                      icon: Icon(
                        _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _toggleMic,
                    ),
                  ],

                  // Host Controls: Switch Camera
                  if (widget.isHost &&
                      _cameraOn &&
                      widget.streamMode != 'audio') ...[
                    const SizedBox(width: 6),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF1E232B,
                        ).withValues(alpha: 0.92),
                        padding: const EdgeInsets.all(10),
                      ),
                      icon: Icon(
                        _isSwitchingCamera
                            ? Icons.hourglass_top
                            : Icons.flip_camera_ios_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _toggleCamera,
                    ),
                  ],

                  // Host Controls: Manage Participants
                  if (widget.isHost) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF1E232B,
                        ).withValues(alpha: 0.92),
                        padding: const EdgeInsets.all(10),
                      ),
                      icon: const Icon(
                        Icons.groups_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _openParticipantsSheet,
                    ),
                  ],

                  // Non-Host Viewers: Real Gifting Button & Heart/Like Button
                  if (!widget.isHost) ...[                    const SizedBox(width: 6),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9500),
                        padding: const EdgeInsets.all(10),
                      ),
                      icon: const Icon(
                        Icons.card_giftcard_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _openGiftingModal,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2D55).withValues(alpha: 0.22),
                        padding: const EdgeInsets.all(10),
                      ),
                      icon: const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFFF2D55),
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _addHeart();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _FloatingHeart {
  final int id;
  final double startX;
  final double startY;
  final Color color;
  final double swayAmplitude;
  final double swayPhase;
  final double size;

  _FloatingHeart({
    required this.id,
    required this.startX,
    required this.startY,
    required this.color,
    this.swayAmplitude = 14.0,
    this.swayPhase = 0.0,
    this.size = 28.0,
  });
}

class _FloatingHeartWidget extends StatefulWidget {
  final _FloatingHeart heart;
  final VoidCallback onComplete;

  const _FloatingHeartWidget({
    super.key,
    required this.heart,
    required this.onComplete,
  });

  @override
  State<_FloatingHeartWidget> createState() => _FloatingHeartWidgetState();
}

class _FloatingHeartWidgetState extends State<_FloatingHeartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final progress = _anim.value;
        // Ascends vertically UPWARDS by 420px (never downwards or sideways)
        final dy = widget.heart.startY - (progress * 420);
        // Gentle sinusoidal wave oscillating around startX (never drifts away)
        final sway = sin(progress * 2.5 * pi + widget.heart.swayPhase) *
            widget.heart.swayAmplitude;
        final dx = widget.heart.startX + sway;

        // TikTok pop-in scale curve
        final scale = progress < 0.15
            ? (progress / 0.15) * 1.18
            : (progress < 0.75 ? 1.0 : 1.0 - (progress - 0.75) * 1.2);

        // Fade in rapidly, stay solid, then fade out smoothly at the top
        final opacity = progress > 0.65
            ? ((1.0 - progress) / 0.35).clamp(0.0, 1.0)
            : (progress / 0.1).clamp(0.0, 1.0);

        final rotation = sin(progress * pi + widget.heart.swayPhase) * 0.15;

        return Positioned(
          left: dx - (widget.heart.size / 2),
          top: dy - (widget.heart.size / 2),
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale.clamp(0.0, 1.5),
                child: Icon(
                  Icons.favorite_rounded,
                  color: widget.heart.color,
                  size: widget.heart.size,
                  shadows: [
                    Shadow(
                      color: widget.heart.color.withValues(alpha: 0.6),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A smooth pop-in animation for incoming TikTok live comments
class _TikTokLiveMessageBubble extends StatefulWidget {
  final Widget child;

  const _TikTokLiveMessageBubble({super.key, required this.child});

  @override
  State<_TikTokLiveMessageBubble> createState() =>
      _TikTokLiveMessageBubbleState();
}

class _TikTokLiveMessageBubbleState extends State<_TikTokLiveMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _slideAnim = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnim.value),
          child: Opacity(
            opacity: _fadeAnim.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _ShareOptionItem extends StatelessWidget {
  final dynamic icon;
  final Color color;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;

  const _ShareOptionItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget iconWidget;
    if (icon is FaIconData) {
      iconWidget = FaIcon(
        icon as FaIconData,
        color: iconColor ?? color,
        size: 22,
      );
    } else if (icon is IconData) {
      iconWidget = Icon(
        icon as IconData,
        color: iconColor ?? color,
        size: 24,
      );
    } else if (icon is Widget) {
      iconWidget = icon as Widget;
    } else {
      iconWidget = const SizedBox();
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: iconWidget,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// Recipient picker used to share a live broadcast into a direct chat
/// (friend), a group, or a community conversation.
class _LiveShareRecipientSheet extends ConsumerStatefulWidget {
  final String title;
  final String shareMessage;
  final List<String> conversationTypes;
  final bool allowsUserSearch;
  final Future<void> Function(Conversation conversation, String shareMessage)
  onSend;

  const _LiveShareRecipientSheet({
    required this.title,
    required this.shareMessage,
    required this.conversationTypes,
    required this.allowsUserSearch,
    required this.onSend,
  });

  @override
  ConsumerState<_LiveShareRecipientSheet> createState() =>
      _LiveShareRecipientSheetState();
}

class _LiveShareRecipientSheetState
    extends ConsumerState<_LiveShareRecipientSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<ChatUser> _userResults = const [];
  bool _searchingUsers = false;
  int? _activeSendingId;
  final Set<int> _sentIds = {};

  String get _categoryLabel {
    if (widget.conversationTypes.contains('direct')) return 'friend';
    if (widget.conversationTypes.contains('group')) return 'group';
    return 'community';
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    if (ref.read(conversationsProvider).conversations.isEmpty) {
      ref.read(conversationsProvider.notifier).refresh();
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final q = _searchCtrl.text.trim();
    if (!widget.allowsUserSearch || q.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _searchUsers(q));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) return;
    setState(() => _searchingUsers = true);
    try {
      final res = await ApiClient.instance.dio.get(
        '/search',
        queryParameters: {'q': query, 'type': 'users', 'per_page': 15},
      );
      final payload = ApiClient.instance.unwrap(res);
      dynamic raw = payload;
      if (payload is Map<String, dynamic>) {
        if (payload['users'] is List) {
          raw = payload['users'];
        } else if (payload['results'] is Map<String, dynamic> &&
            (payload['results'] as Map<String, dynamic>)['users'] is List) {
          raw = (payload['results'] as Map<String, dynamic>)['users'];
        } else if (payload['data'] is List) {
          raw = payload['data'];
        }
      }
      final users = raw is List
          ? raw
                .map(ChatUser.fromJson)
                .where((u) => u.id != 0 && u.name.isNotEmpty)
                .toList()
          : <ChatUser>[];
      if (mounted) {
        setState(() {
          _userResults = users;
          _searchingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searchingUsers = false);
    }
  }

  Future<void> _select(Conversation conversation) async {
    if (_activeSendingId != null || _sentIds.contains(conversation.id)) return;
    setState(() => _activeSendingId = conversation.id);
    try {
      await widget.onSend(conversation, widget.shareMessage);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _activeSendingId = null;
        _sentIds.add(conversation.id);
      });
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) setState(() => _activeSendingId = null);
    }
  }

  Future<void> _sendToNewUser(ChatUser user) async {
    if (_activeSendingId != null || _sentIds.contains(user.id)) return;
    setState(() => _activeSendingId = user.id);
    try {
      final conversation = await ref
          .read(conversationsProvider.notifier)
          .openDirectChat(
            user.id,
            name: user.name,
            username: user.username,
            avatarUrl: user.avatarUrl,
            allowOfflineFallback: false,
          );
      if (!mounted) return;
      if (conversation != null) {
        await widget.onSend(conversation, widget.shareMessage);
        HapticFeedback.mediumImpact();
        if (!mounted) return;
        setState(() {
          _activeSendingId = null;
          _sentIds.add(user.id);
        });
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) setState(() => _activeSendingId = null);
      }
    } catch (_) {
      if (mounted) setState(() => _activeSendingId = null);
    }
  }

  Widget _buildTrailingAction(int id) {
    final isSent = _sentIds.contains(id);
    final isSending = _activeSendingId == id;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
      child: isSent
          ? Container(
              key: const ValueKey('sent'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Sent',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : isSending
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: DesignTokens.primary,
                  ),
                )
              : Container(
                  key: const ValueKey('send'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: DesignTokens.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send_rounded, color: DesignTokens.primary, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Send',
                        style: TextStyle(
                          color: DesignTokens.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final query = _searchCtrl.text.trim().toLowerCase();

    final conversations = ref
        .watch(conversationsProvider)
        .conversations
        .where((c) => widget.conversationTypes.contains(c.type))
        .where((c) => query.isEmpty || c.title.toLowerCase().contains(query))
        .toList();

    final showUserResults = widget.allowsUserSearch && query.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.sensors,
                    color: Color(0xFFFF3B30),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Send the live broadcast to a $_categoryLabel',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search (friends only)
            if (widget.allowsUserSearch)
              TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search friends by name or username',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            const SizedBox(height: 8),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (conversations.isEmpty &&
                      (!showUserResults || _userResults.isEmpty))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 42,
                              color: textSecondary,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No ${_categoryLabel}s to send to',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.allowsUserSearch
                                  ? 'Search for a friend above to get started.'
                                  : 'You are not part of any $_categoryLabel chats yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ...conversations.map(
                    (c) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 4,
                      ),
                      leading: _RecipientAvatar(
                        title: c.title,
                        avatarUrl: c.avatarUrl,
                        color: widget.conversationTypes.contains('group')
                            ? const Color(0xFF34C759)
                            : widget.conversationTypes.contains('community')
                            ? const Color(0xFFFF9500)
                            : DesignTokens.primary,
                      ),
                      title: Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        widget.conversationTypes.contains('direct')
                            ? '@${c.otherUser?.username ?? 'friend'}'
                            : '${c.memberCount ?? 0} members',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                      trailing: _buildTrailingAction(c.id),
                      onTap: () => _select(c),
                    ),
                  ),
                  if (showUserResults) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        _searchingUsers ? 'Searching…' : 'People on MurihSpace',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_searchingUsers)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      ..._userResults.map(
                        (u) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 1,
                            horizontal: 4,
                          ),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: DesignTokens.primary.withValues(alpha: 0.12),
                            backgroundImage:
                                u.avatarUrl != null && u.avatarUrl!.isNotEmpty
                                ? NetworkImage(u.avatarUrl!)
                                : null,
                            child: u.avatarUrl == null || u.avatarUrl!.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    color: DesignTokens.primary,
                                    size: 20,
                                  )
                                : null,
                          ),
                          title: Text(
                            u.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '@${u.username}',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                          trailing: _buildTrailingAction(u.id),
                          onTap: () => _sendToNewUser(u),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular avatar for share recipients with an initials fallback.
class _RecipientAvatar extends StatelessWidget {
  final String title;
  final String? avatarUrl;
  final Color color;

  const _RecipientAvatar({
    required this.title,
    required this.avatarUrl,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final initials = title.trim().isEmpty
        ? '?'
        : title.trim().substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 22,
      backgroundColor: color.withValues(alpha: 0.15),
      backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
          ? NetworkImage(avatarUrl!)
          : null,
      child: avatarUrl == null || avatarUrl!.isEmpty
          ? Text(
              initials,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            )
          : null,
    );
  }
}

/// In-stream purchase sheet. Funds are processed entirely inside the app via
/// the backend `POST /live/{id}/purchase` endpoint.
class _LiveProductBuySheet extends ConsumerStatefulWidget {
  final int streamId;
  final Map<String, dynamic> product;
  final bool isHost;
  final VoidCallback onPurchased;

  const _LiveProductBuySheet({
    required this.streamId,
    required this.product,
    required this.isHost,
    required this.onPurchased,
  });

  @override
  ConsumerState<_LiveProductBuySheet> createState() =>
      _LiveProductBuySheetState();
}

class _LiveProductBuySheetState extends ConsumerState<_LiveProductBuySheet> {
  int _quantity = 1;
  bool _buying = false;
  bool _downloading = false;
  String? _idempotencyKey;
  Map<String, dynamic>? _result;
  String? _error;

  int? get _productId => int.tryParse(widget.product['id'].toString());
  String get _productType =>
      (widget.product['product_type'] ?? widget.product['type'])?.toString() ??
      'physical';
  bool get _isDigital => _productType == 'digital';
  bool get _isFree =>
      widget.product['is_free'] == true ||
      ((widget.product['price'] as num?)?.toDouble() ?? 1) == 0;

  String get _symbol {
    final currency = widget.product['currency']?.toString();
    return widget.product['symbol']?.toString() ??
        (currency == 'NGN'
            ? '₦'
            : (currency == 'EUR' ? '€' : (currency == 'GBP' ? '£' : '\$')));
  }

  String _fmt(num value) => '$_symbol${value.toStringAsFixed(2)}';

  double get _basePrice {
    final raw = widget.product['price'];
    return raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  Future<void> _purchase() async {
    if (widget.isHost || _buying || _productId == null) return;
    _idempotencyKey ??= ApiClient.generateIdempotencyKey();
    setState(() {
      _buying = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        '/live/${widget.streamId}/purchase',
        data: {
          'product_id': _productId,
          'product_type': _productType,
          'quantity': _quantity,
          'idempotency_key': _idempotencyKey,
        },
      );
      final payload = ApiClient.instance.unwrap(res);
      if (!mounted) return;
      widget.onPurchased();
      setState(() {
        _buying = false;
        if (payload is Map<String, dynamic>) _result = payload;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _buying = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _buying = false;
          _error = 'Could not complete your purchase. Please try again.';
        });
      }
    }
  }

  Future<void> _download() async {
    final url = _result?['download_url']?.toString();
    if (url == null || url.isEmpty || _downloading) return;
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      final resolved = ApiClient.resolveUrl(url) ?? url;
      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          '${dir.path}/purchase_${DateTime.now().millisecondsSinceEpoch}';
      final response = await ApiClient.instance.dio.download(
        resolved,
        filePath,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              filePath,
              mimeType: response.headers
                  .value('content-type')
                  ?.split(';')
                  .first
                  .trim(),
            ),
          ],
          text: 'Your purchased file from MurihSpace',
        ),
      );
      if (mounted) setState(() => _downloading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = 'Download failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F7);

    final order = _result?['order'];
    final orderTotal =
        (order is Map<String, dynamic> ? order['total'] : null) as num?;
    final orderNumber =
        (order is Map<String, dynamic> ? order['order_number'] : null)
            ?.toString();
    final paid = _result != null;

    final images =
        (widget.product['images'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final cover =
        widget.product['cover_url']?.toString() ??
        (images.isNotEmpty ? images.first : null);
    final coverUrl = ApiClient.resolveUrl(cover);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.shopping_bag_rounded,
                  color: Color(0xFFFF9500),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Shop this stream',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: textSecondary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: coverUrl != null && coverUrl.isNotEmpty
                        ? Image.network(
                            coverUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 64,
                              height: 64,
                              color: const Color(0xFFFF9500),
                              child: const Icon(
                                Icons.shopping_bag_rounded,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Container(
                            width: 64,
                            height: 64,
                            color: const Color(0xFFFF9500),
                            child: const Icon(
                              Icons.shopping_bag_rounded,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product['title']?.toString() ??
                              widget.product['name']?.toString() ??
                              'Product',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fmt(_basePrice),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF9500),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _isDigital
                                ? DesignTokens.primary.withValues(alpha: 0.15)
                                : const Color(
                                    0xFF34C759,
                                  ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _isDigital
                                ? 'Digital · Instant delivery'
                                : 'Physical · Escrow protected',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _isDigital
                                  ? DesignTokens.primary
                                  : const Color(0xFF34C759),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (!_isDigital) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Quantity',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      color: Color(0xFFFF9500),
                    ),
                    onPressed: _quantity > 1
                        ? () => setState(() {
                            _quantity -= 1;
                            _idempotencyKey = null;
                          })
                        : null,
                  ),
                  Text(
                    '$_quantity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_rounded,
                      color: Color(0xFFFF9500),
                    ),
                    onPressed: _quantity < 100
                        ? () => setState(() {
                            _quantity += 1;
                            _idempotencyKey = null;
                          })
                        : null,
                  ),
                ],
              ),
            ],

            if (!_isDigital &&
                (widget.product['description']?.toString() ?? '')
                    .isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.product['description'].toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
            ],

            if (paid) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF34C759).withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF34C759),
                      size: 28,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      orderNumber != null
                          ? 'Order $orderNumber confirmed!'
                          : 'Order confirmed!',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF34C759),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (orderTotal != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Paid ${_fmt(orderTotal)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF34C759),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _isDigital
                          ? 'Your download is ready below.'
                          : 'Funds are held securely in escrow until your order is delivered.',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (_isDigital) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _download,
                    icon: _downloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 20),
                    label: Text(
                      _downloading ? 'Downloading…' : 'Download Product',
                    ),
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 18),
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFFF3B30),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9500),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: widget.isHost || _buying ? null : _purchase,
                  child: _buying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.isHost
                              ? 'Pinned to your stream'
                              : _isDigital
                              ? (_isFree
                                    ? 'Claim for Free'
                                    : 'Pay ${_fmt(_basePrice)}')
                              : 'Pay ${_fmt(_basePrice * _quantity)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              if (!_isDigital)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'You\'ll complete shipping after checkout.',
                    style: TextStyle(
                      fontSize: 10,
                      color: textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: textSecondary),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// TikTok-style animated live ring around a circular avatar.
/// The ring is a conic-gradient (red→orange→pink→red) that rotates slowly.
/// Usage:
///   _LiveRingAvatar(avatarUrl: host.avatarUrl, radius: 28, isLive: true)
/// ─────────────────────────────────────────────────────────────────────────────
class _LiveRingAvatar extends StatefulWidget {
  final String? avatarUrl;
  final String fallbackInitial;
  final double radius;
  final bool isLive;

  const _LiveRingAvatar({
    this.avatarUrl,
    this.fallbackInitial = '?',
    this.radius = 28,
    this.isLive = true,
  });

  @override
  State<_LiveRingAvatar> createState() => _LiveRingAvatarState();
}

class _LiveRingAvatarState extends State<_LiveRingAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  /// Set when the avatar image fails to load, so the initial can be shown
  /// instead of an empty, background-coloured circle.
  bool _imageFailed = false;

  /// Absolute URL for the avatar, or null when unusable. Relative paths such as
  /// /storage/avatar.jpg need the API host prepended or NetworkImage cannot
  /// resolve them.
  String? get _resolvedAvatarUrl {
    final raw = widget.avatarUrl;
    if (raw == null || raw.isEmpty) return null;
    return ApiClient.resolveUrl(raw);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.isLive) _controller.repeat();
  }

  @override
  void didUpdateWidget(_LiveRingAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.avatarUrl != oldWidget.avatarUrl) {
      _imageFailed = false;
    }
    if (widget.isLive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isLive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringSize = widget.radius * 2 + 6.0; // ring is 3px on each side
    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Spinning conic-gradient ring
          if (widget.isLive)
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                return Transform.rotate(
                  angle: _controller.value * 2 * 3.141592653589793,
                  child: Container(
                    width: ringSize,
                    height: ringSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFFEF4444), // red-500
                          Color(0xFFF97316), // orange-500
                          Color(0xFFEC4899), // pink-500
                          Color(0xFFEF4444), // back to red
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
          else
            Container(
              width: ringSize,
              height: ringSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF6B7280), // gray-500 when offline
              ),
            ),

          // White gap ring
          Container(
            width: ringSize - 4,
            height: ringSize - 4,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
            ),
          ),

          // Actual avatar image
          Builder(
            builder: (context) {
              final avatarUrl = _imageFailed ? null : _resolvedAvatarUrl;
              return CircleAvatar(
                radius: widget.radius - 3,
                backgroundColor: const Color(0xFF1C2030),
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                onBackgroundImageError: avatarUrl != null
                    ? (_, _) => setState(() => _imageFailed = true)
                    : null,
                child: avatarUrl == null
                    ? Text(
                        widget.fallbackInitial.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: widget.radius * 0.6,
                        ),
                      )
                    : null,
              );
            },
          ),

          // "LIVE" badge below the avatar
          if (widget.isLive)
            Positioned(
              bottom: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black, width: 1.2),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 7,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact pill showing an engagement counter (likes / gift coins) on the host
/// overlay.
class _LiveStatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;

  const _LiveStatChip({
    required this.icon,
    required this.color,
    required this.value,
  });

  String get _formatted {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            _formatted,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Host/moderator bottom sheet listing the broadcast roster with moderation
/// actions (promote to co-host, revoke publishing, remove).
class _LiveParticipantsSheet extends StatelessWidget {
  final List<Map<String, dynamic>> participants;
  final bool isFetching;
  final bool isBusy;
  final int? hostUserId;
  final ValueChanged<int> onPromote;
  final ValueChanged<int> onDemote;
  final void Function(int userId, bool restricted) onToggleRestrict;
  final ValueChanged<int> onRemove;
  final Future<void> Function() onRefresh;

  const _LiveParticipantsSheet({
    required this.participants,
    required this.isFetching,
    required this.isBusy,
    required this.hostUserId,
    required this.onPromote,
    required this.onDemote,
    required this.onToggleRestrict,
    required this.onRemove,
    required this.onRefresh,
  });

  String _roleLabel(String? role) {
    switch (role) {
      case 'host':
        return 'Host';
      case 'co_host':
        return 'Co-host';
      case 'moderator':
        return 'Moderator';
      default:
        return 'Viewer';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = participants
        .where((p) => p['is_active'] == true)
        .length;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF121620),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                child: Row(
                  children: [
                    const Icon(Icons.groups_rounded,
                        color: Color(0xFF64D2FF), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Participants',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$activeCount',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white70, size: 20),
                      onPressed: isFetching ? null : () => onRefresh(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isFetching && participants.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: DesignTokens.primary,
                        ),
                      )
                    : participants.isEmpty
                        ? const Center(
                            child: Text(
                              'No participants yet.',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding:
                                const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: participants.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final p = participants[index];
                              final userId =
                                  (p['user_id'] as num?)?.toInt() ?? 0;
                              final isOwner =
                                  hostUserId != null && userId == hostUserId;
                              final role = p['role']?.toString();
                              final isActive = p['is_active'] == true;
                              final isRestricted = p['is_restricted'] == true;
                              final name =
                                  p['name']?.toString() ?? 'Viewer';
                              final avatar = p['avatar_url']?.toString();
                              final isCoHost = role == 'co_host';

                              return Opacity(
                                opacity: isActive ? 1 : 0.5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withValues(alpha: 0.05),
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.06),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: DesignTokens.primary,
                                        backgroundImage:
                                            (avatar != null &&
                                                    avatar.isNotEmpty)
                                                ? NetworkImage(avatar)
                                                : null,
                                        child: (avatar == null ||
                                                avatar.isEmpty)
                                            ? Text(
                                                name.isNotEmpty
                                                    ? name[0]
                                                        .toUpperCase()
                                                    : 'V',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              isOwner
                                                  ? 'Host'
                                                  : _roleLabel(role),
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.5),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isOwner) ...[
                                        if (isCoHost)
                                          _SheetAction(
                                            label: 'Unfeature',
                                            color: Colors.white70,
                                            onTap: isBusy
                                                ? null
                                                : () => onDemote(userId),
                                          )
                                        else
                                          _SheetAction(
                                            label: 'Co-host',
                                            color: const Color(0xFF34D399),
                                            onTap: isBusy
                                                ? null
                                                : () => onPromote(userId),
                                          ),
                                        const SizedBox(width: 6),
                                        _SheetAction(
                                          label: isRestricted
                                              ? 'Restore'
                                              : 'Mute',
                                          color: isRestricted
                                              ? Colors.white70
                                              : const Color(0xFFFBBF24),
                                          onTap: isBusy
                                              ? null
                                              : () => onToggleRestrict(
                                                  userId, !isRestricted),
                                        ),
                                        const SizedBox(width: 6),
                                        _SheetAction(
                                          label: 'Remove',
                                          color: const Color(0xFFF87171),
                                          onTap: isBusy
                                              ? null
                                              : () => onRemove(userId),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _SheetAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
