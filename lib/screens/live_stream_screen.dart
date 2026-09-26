import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/gift_animation_overlay.dart';
import '../components/kyc_live_gate_dialog.dart';
import '../components/send_gift_dialog.dart';
import '../config/env.dart';
import '../core/api_client.dart';
import '../core/roles.dart';
import '../models/chat_models.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/messages_provider.dart';

/// Full Interactive Live Streaming Stage with Native Hardware Camera Preview,
/// Real-Time LiveKit Session Connection, Authenticated Chat, Likes, and Ledger-Backed Gifting.
class LiveStreamScreen extends ConsumerStatefulWidget {
  final int? streamId;
  final String? trackingId;
  final String streamTitle;
  final String hostName;
  final String? communityName;
  final bool isHost;
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
  int _viewerCount = 1;
  int _likesCount = 0;
  int _totalGiftsCoins = 0;
  final Set<dynamic> _seenGiftMessageIds = {};

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

  // Pinned product available for purchase inside the stream.
  Map<String, dynamic>? _pinnedProduct;

  bool _isCameraReady = false;
  late bool _cameraOn;
  bool _isFrontCamera = true;
  bool _isSwitchingCamera = false;

  final List<Map<String, dynamic>> _chatMessages = [];
  final _chatCtrl = TextEditingController();
  final _chatFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Floating Hearts Animation State
  final List<_FloatingHeart> _hearts = [];
  final Random _random = Random();

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
    _cameraOn = widget.cameraEnabled;
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
          Navigator.of(context).pop();
          showKycRequiredLiveModal(context);
        }
        return;
      }
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
            isPublisher: liveKitData['is_publisher'] == true,
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
            isPublisher: liveKitData['is_publisher'] == true,
          );
        }
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
          Navigator.of(context).pop();
          showKycRequiredLiveModal(context);
          return;
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
      final listener = room.createListener();
      _liveKitListener = listener;
      listener
        ..on<AudioPlaybackStatusChanged>((event) async {
          if (!event.isPlaying) {
            try {
              await room.startAudio();
            } catch (_) {}
          }
        })
        ..on<TrackSubscribedEvent>((_) {
          _syncRemoteVideoTrack();
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

      await room.connect(host, token);
      if (!mounted || _isLeavingLiveKit) {
        await _disposeLiveKitConnection();
        return;
      }

      try {
        await room.startAudio();
      } catch (_) {}

      if (isPublisher) {
        final participant = room.localParticipant;
        if (participant != null) {
          try {
            await participant.setMicrophoneEnabled(widget.micEnabled);
          } catch (_) {}
          if (widget.streamMode != 'audio' && _cameraOn) {
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
        setState(() {
          _hostUserId ??=
              (streamData['user_id'] as num?)?.toInt() ??
              (streamData['user']?['id'] as num?)?.toInt();
          if (parsedHost != null) _resolvedHostName = parsedHost;
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
              final animType = coinPrice >= 1000
                  ? 'full_screen'
                  : (coinPrice >= 400
                        ? 'premium'
                        : (coinPrice <= 20 ? 'micro' : 'standard'));

              ref
                  .read(giftAnimationProvider.notifier)
                  .play(
                    GiftAnimationData(
                      giftName: giftName,
                      iconUrl: m['icon_url']?.toString(),
                      iconEmoji: '🎁',
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
            'color': const Color(0xFF007AFF),
          };
        }).toList();

        setState(() {
          _chatMessages.clear();
          _chatMessages.addAll(parsed);
        });
      }
    } catch (_) {}
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
    unawaited(_leaveViewerStream());
    unawaited(_disconnectLiveKit());
    _metricsTimer?.cancel();
    _chatCtrl.dispose();
    _chatFocusNode.dispose();
    _scrollController.dispose();

    super.dispose();
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
            : const Color(0xFF007AFF),
      });
      _chatCtrl.clear();
    });

    if (_activeStreamId != null) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post('/live/$_activeStreamId/chat', data: {'message': text});
      } catch (_) {}
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _addHeart(TapUpDetails details) async {
    setState(() {
      _likesCount += 1;
      _hearts.add(
        _FloatingHeart(
          id: DateTime.now().millisecondsSinceEpoch,
          startX: details.localPosition.dx,
          startY: details.localPosition.dy,
          color: [
            Colors.red,
            Colors.pink,
            Colors.amber,
            Colors.purple,
            Colors.cyan,
            Colors.orange,
          ][_random.nextInt(6)],
        ),
      );
    });

    if (_activeStreamId != null) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post('/live/$_activeStreamId/like', data: {'count': 1});
      } catch (_) {}
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
              'msg': '🎁 You sent ${gift.name} (+$amount Coins)!',
              'color': const Color(0xFFFF9500),
            });
          });

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
                      color: const Color(0xFF007AFF),
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
                      icon: Icons.chat_bubble_outline_rounded,
                      color: const Color(0xFF25D366),
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
                      icon: Icons.alternate_email_rounded,
                      color: const Color(0xFF1DA1F2),
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
                      icon: Icons.sms_outlined,
                      color: const Color(0xFF34C759),
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
                      icon: Icons.mail_outline_rounded,
                      color: const Color(0xFFFF9500),
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
                        color: Color(0xFF007AFF),
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
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: liveUrl));
                          HapticFeedback.mediumImpact();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '✓ Live stream link copied to clipboard!',
                              ),
                              backgroundColor: Color(0xFF34C759),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Text(
                          'Copy',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Live broadcast sent to ${conversation.title}'),
            backgroundColor: const Color(0xFF34C759),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not send the live broadcast. Please try again.',
            ),
          ),
        );
      }
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
      await _disconnectLiveKit();
      if (isHost && _activeStreamId != null) {
        try {
          final api = ref.read(apiClientProvider);
          await api.post('/live/$_activeStreamId/end');
        } catch (_) {}
      } else if (!isHost && _activeStreamId != null) {
        await _leaveViewerStream();
      }

      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final coinBalance = authUser?.coins ?? 0;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = viewInsetsBottom > 0;
    final hasChatText = _chatCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (details) {
          if (_chatFocusNode.hasFocus) {
            _chatFocusNode.unfocus();
          } else {
            _addHeart(details);
          }
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
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: const Color(
                          0xFFFF9500,
                        ).withValues(alpha: 0.2),
                        child: Icon(
                          _cameraOn
                              ? Icons.videocam_rounded
                              : Icons.mic_rounded,
                          color: const Color(0xFFFF9500),
                          size: 42,
                        ),
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 8),
                        SizedBox(width: 6),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.remove_red_eye_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_viewerCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Real Wallet Coin Balance
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('🪙 ', style: TextStyle(fontSize: 12)),
                        Text(
                          '$coinBalance Coins',
                          style: const TextStyle(
                            color: Color(0xFFFF9500),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Share Live Stream Button
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.55),
                    ),
                    icon: const Icon(
                      Icons.share_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _openShareModal,
                  ),
                  const SizedBox(width: 4),

                  // Close/End Stream Button
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.55),
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _endOrLeaveStream,
                  ),
                ],
              ),
            ),

            // 5. Live Chat Feed Overlay (dynamically lifts above keyboard)
            Positioned(
              bottom: viewInsetsBottom + 70,
              left: 16,
              right: 80,
              child: SizedBox(
                height: isKeyboardOpen ? 120 : 180,
                child: ListView.separated(
                  controller: _scrollController,
                  itemCount: _chatMessages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, idx) {
                    final msg = _chatMessages[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F141C).withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${msg['name']} ',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: msg['color'] as Color,
                              ),
                            ),
                            TextSpan(
                              text: msg['msg'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
                              ? const Color(0xFF007AFF)
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
                                ? const Color(0xFF007AFF)
                                : Colors.white70,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Theme(
                              data: ThemeData.dark().copyWith(
                                textSelectionTheme:
                                    const TextSelectionThemeData(
                                      cursorColor: Color(0xFF007AFF),
                                      selectionColor: Color(0x66007AFF),
                                      selectionHandleColor: Color(0xFF007AFF),
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
                                cursorColor: const Color(0xFF007AFF),
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
                                  color: Color(0xFF007AFF),
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

                  // Non-Host Viewers: Real Gifting Button
                  if (!widget.isHost) ...[
                    const SizedBox(width: 6),
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

class _FloatingHeart {
  final int id;
  final double startX;
  final double startY;
  final Color color;

  _FloatingHeart({
    required this.id,
    required this.startX,
    required this.startY,
    required this.color,
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
  late double _targetX;

  @override
  void initState() {
    super.initState();
    _targetX = widget.heart.startX + (Random().nextDouble() * 80 - 40);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
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
        final dy = widget.heart.startY - (progress * 240);
        final dx =
            widget.heart.startX + (progress * (_targetX - widget.heart.startX));
        final opacity = (1.0 - progress).clamp(0.0, 1.0);
        final scale = 0.8 + (progress * 0.5);

        return Positioned(
          left: dx - 12,
          top: dy - 12,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Icon(
                Icons.favorite_rounded,
                color: widget.heart.color,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShareOptionItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ShareOptionItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
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
  bool _sending = false;

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
    if (_sending) return;
    setState(() => _sending = true);
    Navigator.of(context).pop();
    await widget.onSend(conversation, widget.shareMessage);
  }

  Future<void> _sendToNewUser(ChatUser user) async {
    if (_sending) return;
    setState(() => _sending = true);
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
    Navigator.of(context).pop();
    if (conversation != null) {
      await widget.onSend(conversation, widget.shareMessage);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start a chat with this user right now.'),
        ),
      );
    }
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
                            : const Color(0xFF007AFF),
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
                      trailing: const Icon(
                        Icons.send_rounded,
                        size: 18,
                        color: Color(0xFF007AFF),
                      ),
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
                            backgroundColor: const Color(
                              0xFF007AFF,
                            ).withValues(alpha: 0.12),
                            backgroundImage:
                                u.avatarUrl != null && u.avatarUrl!.isNotEmpty
                                ? NetworkImage(u.avatarUrl!)
                                : null,
                            child: u.avatarUrl == null || u.avatarUrl!.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    color: Color(0xFF007AFF),
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
                          trailing: const Icon(
                            Icons.send_rounded,
                            size: 18,
                            color: Color(0xFF007AFF),
                          ),
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
                                ? const Color(
                                    0xFF007AFF,
                                  ).withValues(alpha: 0.15)
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
                                  ? const Color(0xFF007AFF)
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
                      backgroundColor: const Color(0xFF007AFF),
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
