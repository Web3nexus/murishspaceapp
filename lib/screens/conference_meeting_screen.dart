import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/env.dart';
import '../core/api_client.dart';
import '../core/design_tokens.dart';
import '../core/roles.dart';
import '../components/brand.dart';
import '../components/gift_animation_overlay.dart';
import '../components/send_gift_dialog.dart';
import '../providers/auth_provider.dart';

/// Whether the caller has landed on the meeting pre-join lobby or is already
/// inside a connected room.
enum _MeetingStage { preJoin, connecting, connected, ended }

/// A single message rendered in the in-meeting chat panel.
class _MeetingMessage {
  final String sender;
  final String text;
  final bool isMine;
  final DateTime time;

  const _MeetingMessage({
    required this.sender,
    required this.text,
    required this.isMine,
    required this.time,
  });
}

/// A floating emoji particle (reactions and raise-hand animations).
class _FloatingReaction {
  final int id;
  final String emoji;
  final double dx; // 0..1 horizontal position fraction

  const _FloatingReaction({
    required this.id,
    required this.emoji,
    required this.dx,
  });
}

/// LiveKit-backed multi-user voice/video conference room.
///
/// Unlike the old mock this connects to the real backend (`POST
/// /meetings/instant` or `GET /meetings/{code}/token`), pulls participants
/// from the LiveKit room, and gives working Mute / Camera / Raise Hand / Gift /
/// Leave controls plus an in-room chat + emoji reactions that are broadcast to
/// every participant over the LiveKit data channel.
class ConferenceMeetingScreen extends ConsumerStatefulWidget {
  /// Optional meeting code to join immediately (used by `/app/meeting/:code`).
  final String? joinCode;
  final String? meetingTitle;
  final int? hostUserId;

  const ConferenceMeetingScreen({
    super.key,
    this.joinCode,
    this.meetingTitle,
    this.hostUserId,
  });

  @override
  ConsumerState<ConferenceMeetingScreen> createState() =>
      _ConferenceMeetingScreenState();
}

class _ConferenceMeetingScreenState
    extends ConsumerState<ConferenceMeetingScreen>
    with TickerProviderStateMixin {
  final _rng = Random();

  // Tally rail pulse: the room admitting out loud that it is on air.
  late final AnimationController _tallyPulse;
  late final Animation<double> _tallyOpacity;

  // Pre-join form state
  final _titleCtrl = TextEditingController();
  final _joinCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  // Connection state
  _MeetingStage _stage = _MeetingStage.preJoin;
  String _code = '';
  String _token = '';
  String _host = '';
  String _title = '';
  String _meetingUrl = '';
  int _meetingSeconds = 0;
  Timer? _meetingTimer;

  // Local media state
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _handRaised = false;

  // LiveKit WebRTC state
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  VideoTrack? _localVideoTrack;
  String _myName = 'You';
  String? _activeSpeaker;
  int? _hostUserId;

  // Room data (chat / emoji / raise hand)
  final List<_MeetingMessage> _messages = [];
  final Set<String> _raisedHands = {};
  final List<_FloatingReaction> _reactions = [];
  int _reactionCounter = 0;
  bool _showChat = false;
  bool _copiedInvite = false;
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  static const _quickEmojis = ['👍', '❤️', '😂', '🔥', '🎉', '🙌', '✋', '👏'];

  @override
  void initState() {
    super.initState();
    _tallyPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _tallyOpacity = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _tallyPulse, curve: Curves.easeInOut),
    );
    if (widget.joinCode != null && widget.joinCode!.trim().isNotEmpty) {
      _joinCtrl.text = widget.joinCode!.trim();
      _busy = true;
      Future.microtask(_joinMeeting);
    }
  }

  @override
  void dispose() {
    _tallyPulse.dispose();
    _meetingTimer?.cancel();
    _listener?.dispose();
    _listener = null;
    _room?.disconnect();
    _room?.dispose();
    _room = null;
    if (_localVideoTrack is LocalVideoTrack) {
      try {
        (_localVideoTrack as LocalVideoTrack).stop();
      } catch (_) {}
    }
    _titleCtrl.dispose();
    _joinCtrl.dispose();
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Meeting lifecycle ───────────────────────────────────────────────────

  Future<void> _startMeeting() async {
    final user = ref.read(authProvider).user;
    final canHost =
        user?.role == UserRole.creator ||
        user?.role == UserRole.vendor ||
        user?.role == UserRole.admin;
    if (!canHost) {
      setState(
        () => _error =
            'Hosting instant meetings is reserved for Creator & Vendor accounts. Please upgrade to host meetings.',
      );
      return;
    }

    final title = _titleCtrl.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.dio.post(
        '/meetings/instant',
        data: {'title': title},
      );
      final data = ApiClient.instance.unwrap(res) is Map<String, dynamic>
          ? ApiClient.instance.unwrap(res) as Map<String, dynamic>
          : <String, dynamic>{};
      if (data.containsKey('token') && data.containsKey('host')) {
        setState(() {
          _code = data['code']?.toString() ?? '';
          _token = data['token'].toString();
          _host = data['host']?.toString() ?? '';
          _title =
              data['title']?.toString() ??
              widget.meetingTitle ??
              'MurihSpace Meeting';
          _meetingUrl = data['meeting_url']?.toString() ?? '';
          _hostUserId =
              (data['host_user_id'] as num?)?.toInt() ?? widget.hostUserId;
          _busy = false;
        });
        await _connect();
      } else {
        throw ApiException(message: 'Missing meeting credentials from server.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is ApiException
              ? e.message
              : 'Could not start meeting. Check your connection.';
        });
      }
    }
  }

  Future<void> _joinMeeting() async {
    final raw = _joinCtrl.text.trim();
    var code = raw
        .replaceAll(RegExp(r'^https?://[^/]+/app/meeting/'), '')
        .trim();
    code = code.replaceAll(RegExp(r'^/app/meeting/'), '').trim().toLowerCase();
    if (code.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.dio.get('/meetings/$code/token');
      final data = ApiClient.instance.unwrap(res) is Map<String, dynamic>
          ? ApiClient.instance.unwrap(res) as Map<String, dynamic>
          : <String, dynamic>{};
      if (data.containsKey('token') && data.containsKey('host')) {
        setState(() {
          _code = code;
          _token = data['token'].toString();
          _host = data['host']?.toString() ?? '';
          _title = widget.meetingTitle ?? 'MurihSpace Meeting';
          _meetingUrl = '';
          _hostUserId =
              (data['host_user_id'] as num?)?.toInt() ?? widget.hostUserId;
          _busy = false;
        });
        await _connect();
      } else {
        throw ApiException(message: 'Invalid meeting invite code.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is ApiException
              ? e.message
              : 'Could not join this meeting. Check the code and try again.';
        });
      }
    }
  }

  Future<void> _connect() async {
    if (_token.isEmpty || _host.isEmpty) return;

    await Permission.microphone.request();
    if (!_isCameraOff) {
      await Permission.camera.request();
    }

    setState(() => _stage = _MeetingStage.connecting);

    var wsHost = _host.trim();
    if (wsHost.startsWith('https://')) {
      wsHost = 'wss://${wsHost.substring(8)}';
    } else if (wsHost.startsWith('http://')) {
      wsHost = 'ws://${wsHost.substring(7)}';
    }
    wsHost = wsHost.replaceAll(RegExp(r'/+$'), '');

    try {
      final room = Room(
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'microphone',
            encoding: AudioEncoding.presetSpeech,
          ),
          defaultAudioCaptureOptions: AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          ),
        ),
      );
      _room = room;
      final listener = room.createListener();
      _listener = listener;

      listener
        ..on<AudioPlaybackStatusChanged>((event) async {
          if (!event.isPlaying) {
            try {
              await room.startAudio();
            } catch (_) {}
          }
        })
        ..on<ParticipantConnectedEvent>((event) {
          if (mounted) setState(() {});
          _resolveHostFromRoom(room);
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          final identity = event.participant.identity;
          if (mounted) {
            setState(() {
              _raisedHands.remove(identity);
              if (_activeSpeaker == identity) _activeSpeaker = null;
            });
          }
        })
        ..on<ParticipantMetadataUpdatedEvent>(
          (event) => _resolveHostFromRoom(room),
        )
        ..on<TrackSubscribedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<TrackUnsubscribedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<ActiveSpeakersChangedEvent>((event) {
          if (!mounted) return;
          setState(() {
            _activeSpeaker = event.speakers.isEmpty
                ? null
                : event.speakers.first.identity;
          });
        })
        ..on<DataReceivedEvent>((event) => _onDataReceived(event))
        ..on<RoomDisconnectedEvent>((event) {
          if (!mounted || _stage != _MeetingStage.connected) return;
          _leaveMeeting(showToast: true, reason: 'Disconnected from meeting');
        });

      await room.connect(wsHost, _token);
      try {
        await room.startAudio();
      } catch (_) {}
      _resolveHostFromRoom(room);

      final lp = room.localParticipant;
      if (lp != null) {
        _myName = lp.name.isNotEmpty ? lp.name : 'You';
        await lp.setMicrophoneEnabled(true);
        if (_isMuted) await lp.setMicrophoneEnabled(false);
        if (!_isCameraOff) {
          await lp.setCameraEnabled(true);
          final pubs = lp.videoTrackPublications;
          if (pubs.isNotEmpty) {
            final t = pubs.first.track;
            setState(() => _localVideoTrack = t is VideoTrack ? t : null);
          }
        }
      }

      if (mounted) {
        setState(() => _stage = _MeetingStage.connected);
        _startMeetingTimer();
        _spawnReaction('👋');
      }
    } catch (e) {
      debugPrint('[Meeting] Connect error: $e');
      if (mounted) {
        setState(() {
          _stage = _MeetingStage.preJoin;
          _error = 'Could not connect to the meeting room. Please try again.';
        });
      }
    }
  }

  void _startMeetingTimer() {
    _meetingTimer?.cancel();
    _meetingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _stage == _MeetingStage.connected) {
        setState(() => _meetingSeconds++);
      }
    });
  }

  void _leaveMeeting({bool showToast = false, String reason = ''}) {
    _meetingTimer?.cancel();
    _listener?.dispose();
    _listener = null;
    _room?.disconnect();
    _room?.dispose();
    _room = null;
    if (mounted) {
      setState(() => _stage = _MeetingStage.ended);
      if (showToast && reason.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(reason)));
      }
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/app/conference');
          }
        }
      });
    }
  }

  // ── Controls ───────────────────────────────────────────────────────────

  /// Derives the host's user id from the LiveKit room so meeting attendees can
  /// send gifts. The host's participant identity is their user id (set by
  /// `/meetings/instant`, while other members join via `/meetings/{code}/token`)
  /// and their metadata carries `"role": "host"` — there is no persisted
  /// meeting record for the join endpoint to look up.
  void _resolveHostFromRoom(Room room) {
    final candidates = <Participant?>[
      room.localParticipant,
      ...room.remoteParticipants.values,
    ];
    for (final candidate in candidates) {
      final participant = candidate;
      if (participant == null) continue;
      try {
        final meta = participant.metadata;
        if (meta == null || meta.isEmpty) continue;
        final decoded = jsonDecode(meta);
        if (decoded is Map && decoded['role'] == 'host') {
          final id = int.tryParse(participant.identity);
          if (id != null && id > 0) {
            _hostUserId = id;
            return;
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _toggleMic() async {
    setState(() => _isMuted = !_isMuted);
    final lp = _room?.localParticipant;
    if (lp == null) return;
    try {
      await lp.setMicrophoneEnabled(!_isMuted);
    } catch (e) {
      debugPrint('[Meeting] Mic error: $e');
    }
  }

  Future<void> _toggleCamera() async {
    setState(() => _isCameraOff = !_isCameraOff);
    final lp = _room?.localParticipant;
    if (lp == null) return;
    try {
      await lp.setCameraEnabled(!_isCameraOff);
      if (!_isCameraOff) {
        final pubs = lp.videoTrackPublications;
        if (pubs.isNotEmpty) {
          final t = pubs.first.track;
          setState(() => _localVideoTrack = t is VideoTrack ? t : null);
        }
      }
    } catch (e) {
      debugPrint('[Meeting] Camera error: $e');
    }
  }

  Future<void> _toggleRaiseHand() async {
    final next = !_handRaised;
    setState(() => _handRaised = next);
    if (next) _spawnReaction('✋');
    final identity = _room?.localParticipant?.identity;
    if (identity != null) {
      setState(() {
        next ? _raisedHands.add(identity) : _raisedHands.remove(identity);
      });
    }
    await _sendData({'type': 'raise', 'from': _myName, 'state': next});
  }

  void _sendGift() {
    final hostId = _hostUserId;
    final myId = ref.read(authProvider).user?.id;
    if (hostId == null || hostId <= 0 || hostId == myId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gifting is unavailable for this meeting.'),
        ),
      );
      return;
    }
    SendGiftDialog.show(
      context,
      recipientId: hostId,
      recipientName: 'Meeting Host',
      onGiftSent: (gift, amount) {
        ref
            .read(giftAnimationProvider.notifier)
            .play(
              GiftAnimationData(
                giftName: gift.name,
                iconUrl: gift.iconUrl,
                iconEmoji: gift.icon,
                coinPrice: amount,
                senderName: 'You',
                recipientName: 'Meeting Host',
                animationType: gift.animationType,
              ),
            );
        final emoji = gift.icon;
        _spawnReaction(emoji);
        _sendData({'type': 'reaction', 'from': _myName, 'emoji': emoji});
      },
    );
  }

  void _sendReaction(String emoji) {
    _spawnReaction(emoji);
    _sendData({'type': 'reaction', 'from': _myName, 'emoji': emoji});
  }

  void _sendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    _chatCtrl.clear();
    final msg = _MeetingMessage(
      sender: _myName,
      text: text,
      isMine: true,
      time: DateTime.now(),
    );
    setState(() => _messages.add(msg));
    _scrollToBottom();
    _sendData({'type': 'chat', 'from': _myName, 'text': text});
  }

  // ── Data channel (chat / emoji / raise hand) ───────────────────────────

  Future<void> _sendData(Map<String, dynamic> payload) async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    try {
      await lp.publishData(utf8.encode(jsonEncode(payload)), reliable: true);
    } catch (e) {
      debugPrint('[Meeting] publishData error: $e');
    }
  }

  void _onDataReceived(DataReceivedEvent event) {
    if (!mounted) return;
    try {
      final payload =
          jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
      final type = payload['type']?.toString();
      final participant = event.participant;
      final sender = participant == null
          ? 'Guest'
          : (participant.name.isNotEmpty
                ? participant.name
                : participant.identity);
      switch (type) {
        case 'chat':
          final text = payload['text']?.toString() ?? '';
          if (text.isEmpty) return;
          setState(
            () => _messages.add(
              _MeetingMessage(
                sender: sender,
                text: text,
                isMine: false,
                time: DateTime.now(),
              ),
            ),
          );
          _scrollToBottom();
        case 'reaction':
          _spawnReaction(payload['emoji']?.toString() ?? '👍');
        case 'raise':
          final identity = event.participant?.identity ?? '';
          final state = payload['state'] == true;
          if (identity.isEmpty) break;
          setState(() {
            state ? _raisedHands.add(identity) : _raisedHands.remove(identity);
          });
          if (state) _spawnReaction('✋');
      }
    } catch (_) {}
  }

  void _spawnReaction(String emoji) {
    if (!mounted) return;
    setState(() {
      _reactions.insert(
        0,
        _FloatingReaction(
          id: _reactionCounter++,
          emoji: emoji,
          dx: 0.08 + _rng.nextDouble() * 0.84,
        ),
      );
      if (_reactions.length > 24) _reactions.removeRange(24, _reactions.length);
    });
  }

  void _removeReaction(int id) {
    if (!mounted) return;
    setState(() => _reactions.removeWhere((r) => r.id == id));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Invite / share ─────────────────────────────────────────────────────

  Future<void> _copyInviteLink() async {
    if (_copiedInvite) return;
    final path = _meetingUrl.isNotEmpty ? _meetingUrl : '/app/meeting/$_code';
    final url = '$webBaseUrl$path';
    await Clipboard.setData(ClipboardData(text: url));
    HapticFeedback.mediumImpact();
    if (mounted) {
      setState(() => _copiedInvite = true);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _copiedInvite = false);
      });
    }
  }

  String get webBaseUrl => Env.webBaseUrl.replaceAll(RegExp(r'/+$'), '');

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  int get _participantCount => _tiles.length;

  String? get _localIdentity => _room?.localParticipant?.identity;

  bool get _localIsHost {
    final hostId = _hostUserId;
    if (hostId == null || hostId <= 0) return false;
    final identity = _localIdentity;
    return identity != null && identity == hostId.toString();
  }

  bool get _localIsSpeaking {
    final identity = _localIdentity;
    return identity != null && _activeSpeaker == identity;
  }

  String get _connectionLabel {
    switch (_room?.connectionState) {
      case ConnectionState.connecting:
        return 'CONNECTING';
      case ConnectionState.reconnecting:
        return 'RECONNECTING';
      case ConnectionState.disconnected:
        return 'OFFLINE';
      default:
        return 'ON AIR';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The connected room stays ink at every theme: video is watched, not read.
    final scaffoldBg = switch (_stage) {
      _MeetingStage.preJoin || _MeetingStage.connecting ||
      _MeetingStage.ended => isDark
          ? DesignTokens.roomGround
          : const Color(0xFFF4F6FA),
      _MeetingStage.connected => DesignTokens.roomGround,
    };

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: switch (_stage) {
        _MeetingStage.preJoin ||
        _MeetingStage.connecting => _buildPreJoin(context),
        _MeetingStage.connected => _buildRoom(context),
        _MeetingStage.ended => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildPreJoin(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DesignTokens.roomGround : const Color(0xFFF4F6FA);
    final textPrimary = isDark
        ? DesignTokens.roomTextPrimary
        : DesignTokens.navy;
    final textSecondary = isDark
        ? DesignTokens.roomTextSecondary
        : const Color(0xFF5A6E86);
    final inputFill = isDark ? DesignTokens.roomChrome : Colors.white;
    final inputBorder = isDark
        ? DesignTokens.roomBorder
        : const Color(0xFFE3E8F0);
    final authUser = ref.watch(authProvider).user;
    final userName = authUser?.name.isNotEmpty == true ? authUser!.name : 'You';
    final userAvatar = authUser?.avatarUrl;
    final canHostMeetings =
        authUser?.role == UserRole.creator ||
        authUser?.role == UserRole.vendor ||
        authUser?.role == UserRole.admin;

    return SafeArea(
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/app/conference');
              }
            },
          ),
          title: Text(
            'Meetings & Conference',
            style: TextStyle(
              color: textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(
                  0xFF007AFF,
                ).withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 13,
                    color: Color(0xFF007AFF),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Private HD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: _stage == _MeetingStage.connecting
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // System logo loader: brand mark ringed by a slim spinner.
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const SizedBox.expand(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0x14007AFF),
                              ),
                            ),
                          ),
                          const SizedBox.expand(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.fromBorderSide(
                                  BorderSide(color: Color(0x33007AFF)),
                                ),
                              ),
                            ),
                          ),
                          BrandIcon(size: 50),
                          const SizedBox.expand(
                            child: Padding(
                              padding: EdgeInsets.all(2),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Color(0xFF00C6FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Joining your meeting…',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Setting up a private, encrypted room.',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    // Hero Icon
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: isDark
                            ? DesignTokens.roomChrome
                            : DesignTokens.navy,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? DesignTokens.roomBorder
                              : DesignTokens.navy.withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: DesignTokens.navy.withValues(
                              alpha: isDark ? 0.4 : 0.18,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        color: DesignTokens.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      canHostMeetings
                          ? 'Host a Live Conference'
                          : 'Join a Video Conference',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      canHostMeetings
                          ? 'Private HD rooms with crystal clear audio, chat, emoji reactions, and gifting.'
                          : 'Enter a room code or invite link to join a private meeting.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Feature / Trust badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildFeatureBadge(
                          icon: Icons.lock_outline_rounded,
                          label: 'End-to-End Encrypted',
                          color: const Color(0xFF34C759),
                          isDark: isDark,
                        ),
                        _buildFeatureBadge(
                          icon: Icons.bolt_rounded,
                          label: 'Ultra HD Calls',
                          color: const Color(0xFF007AFF),
                          isDark: isDark,
                        ),
                        _buildFeatureBadge(
                          icon: Icons.favorite_outline_rounded,
                          label: 'Live Reactions',
                          color: const Color(0xFFFF2D55),
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Pre-join Audio & Video readiness check card
                    _modernCard(
                      context,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(
                                  0xFF007AFF,
                                ).withValues(alpha: 0.15),
                                backgroundImage:
                                    (userAvatar != null &&
                                        userAvatar.isNotEmpty)
                                    ? NetworkImage(userAvatar)
                                    : null,
                                child:
                                    (userAvatar == null || userAvatar.isEmpty)
                                    ? Text(
                                        (userName.isNotEmpty
                                                ? userName[0]
                                                : 'U')
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Color(0xFF007AFF),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Audio & Video Check',
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'Joining as $userName',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF34C759,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF34C759),
                                      size: 12,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Ready',
                                      style: TextStyle(
                                        color: Color(0xFF34C759),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () =>
                                      setState(() => _isMuted = !_isMuted),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isMuted
                                          ? const Color(
                                              0xFFFF3B30,
                                            ).withValues(alpha: 0.1)
                                          : const Color(
                                              0xFF34C759,
                                            ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _isMuted
                                            ? const Color(
                                                0xFFFF3B30,
                                              ).withValues(alpha: 0.3)
                                            : const Color(
                                                0xFF34C759,
                                              ).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isMuted
                                              ? Icons.mic_off_rounded
                                              : Icons.mic_rounded,
                                          color: _isMuted
                                              ? const Color(0xFFFF3B30)
                                              : const Color(0xFF34C759),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              _isMuted
                                                  ? 'Mic Muted'
                                                  : 'Mic Ready',
                                              style: TextStyle(
                                                color: _isMuted
                                                    ? const Color(0xFFFF3B30)
                                                    : const Color(0xFF34C759),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => setState(
                                    () => _isCameraOff = !_isCameraOff,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isCameraOff
                                          ? const Color(
                                              0xFFFF3B30,
                                            ).withValues(alpha: 0.1)
                                          : const Color(
                                              0xFF007AFF,
                                            ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _isCameraOff
                                            ? const Color(
                                                0xFFFF3B30,
                                              ).withValues(alpha: 0.3)
                                            : const Color(
                                                0xFF007AFF,
                                              ).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isCameraOff
                                              ? Icons.videocam_off_rounded
                                              : Icons.videocam_rounded,
                                          color: _isCameraOff
                                              ? const Color(0xFFFF3B30)
                                              : const Color(0xFF007AFF),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              _isCameraOff
                                                  ? 'Cam Off'
                                                  : 'Cam Ready',
                                              style: TextStyle(
                                                color: _isCameraOff
                                                    ? const Color(0xFFFF3B30)
                                                    : const Color(0xFF007AFF),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    if (canHostMeetings) ...[
                      // Start new meeting card (Creators / Vendors / Admins)
                      _modernCard(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF007AFF,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: Color(0xFF007AFF),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Start an Instant Meeting',
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        'Create a new room and share code with guests',
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _titleCtrl,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _startMeeting(),
                              decoration: InputDecoration(
                                hintText: 'Meeting title or topic (optional)',
                                hintStyle: TextStyle(
                                  color: textSecondary.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                                prefixIcon: Icon(
                                  Icons.meeting_room_outlined,
                                  color: textSecondary,
                                  size: 20,
                                ),
                                isDense: true,
                                filled: true,
                                fillColor: inputFill,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: inputBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: inputBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF007AFF),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF007AFF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _busy ? null : _startMeeting,
                                icon: _busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.video_call_rounded,
                                        size: 20,
                                      ),
                                label: Text(
                                  _busy
                                      ? 'Starting meeting…'
                                      : 'Start Instant Meeting',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ] else ...[
                      // Upgrade prompt card for members who want to host
                      _modernCard(
                        context,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF007AFF,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.video_camera_front_rounded,
                                color: Color(0xFF007AFF),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Want to host your own meetings?',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Upgrade to Creator or Vendor to host encrypted meetings, record calls, and manage rooms.',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 11.5,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF007AFF),
                                side: const BorderSide(
                                  color: Color(0xFF007AFF),
                                  width: 1.2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => context.push('/upgrade-account'),
                              child: const Text(
                                'Upgrade',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Join by code card
                    _modernCard(
                      context,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF34C759,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.tag_rounded,
                                  color: Color(0xFF34C759),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Join with Code or Link',
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'Enter room code or paste an invite link',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _joinCtrl,
                            style: TextStyle(color: textPrimary, fontSize: 14),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _joinMeeting(),
                            decoration: InputDecoration(
                              hintText: 'e.g. abc-defg-hij or paste a link',
                              hintStyle: TextStyle(
                                color: textSecondary.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.link_rounded,
                                color: textSecondary,
                                size: 20,
                              ),
                              suffixIcon: TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  foregroundColor: const Color(0xFF007AFF),
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.content_paste_rounded,
                                  size: 14,
                                ),
                                label: const Text('Paste'),
                                onPressed: () async {
                                  final data = await Clipboard.getData(
                                    Clipboard.kTextPlain,
                                  );
                                  if (data?.text != null &&
                                      data!.text!.trim().isNotEmpty) {
                                    setState(() {
                                      _joinCtrl.text = data.text!.trim();
                                    });
                                  }
                                },
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: inputFill,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: inputBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: inputBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFF34C759),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textPrimary,
                                side: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFCBD5E1),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _busy ? null : _joinMeeting,
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Join Meeting',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFF3B30,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(
                              0xFFFF3B30,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFFF3B30),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFFF3B30),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFFFF3B30),
                                size: 16,
                              ),
                              onPressed: () => setState(() => _error = null),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _modernCard(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.roomChrome : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? DesignTokens.roomBorder
              : const Color(0xFFE3E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : DesignTokens.navy.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFeatureBadge({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.roomChrome : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? DesignTokens.roomBorder : const Color(0xFFE3E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? DesignTokens.roomTextSecondary
                  : const Color(0xFF5A6E86),
            ),
          ),
        ],
      ),
    );
  }

  /// The room's truth in one strip: a 3pt tally bar that lights while the
  /// local participant is on air, over a slate carrying connection state,
  /// the elapsed clock and the head count.
  Widget _buildTallyRail() {
    final localSpeaking = _localIsSpeaking;
    final remoteSpeaking = _activeSpeaker != null && !localSpeaking;
    final onAir = _connectionLabel == 'ON AIR';
    final railColor = localSpeaking
        ? DesignTokens.signal
        : remoteSpeaking
        ? DesignTokens.primary
        : DesignTokens.roomBorder;

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (localSpeaking && !_tallyPulse.isAnimating && !reduceMotion) {
      _tallyPulse.repeat(reverse: true);
    } else if (!localSpeaking && _tallyPulse.isAnimating) {
      _tallyPulse.stop();
      _tallyPulse.value = 1.0;
    }

    return ColoredBox(
      color: DesignTokens.roomChrome,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _tallyOpacity,
            builder: (context, child) => Opacity(
              opacity: localSpeaking ? _tallyOpacity.value : 1.0,
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: double.infinity,
              color: railColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: onAir
                        ? DesignTokens.signal
                        : DesignTokens.roomBorder,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  _connectionLabel,
                  style: TextStyle(
                    color: onAir
                        ? DesignTokens.signal
                        : DesignTokens.roomTextSecondary,
                    fontSize: 10,
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  _formatDuration(_meetingSeconds),
                  style: const TextStyle(
                    color: DesignTokens.roomTextPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(
                  Icons.groups_rounded,
                  size: 14,
                  color: DesignTokens.roomTextSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  '$_participantCount',
                  style: const TextStyle(
                    color: DesignTokens.roomTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                if (_localIsHost)
                  _slate('HOST', DesignTokens.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomHeader() {
    final chipBg = Colors.white.withValues(alpha: 0.08);
    final chipBorder = Colors.white.withValues(alpha: 0.18);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _title.isEmpty ? 'MurihSpace Meeting' : _title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DesignTokens.roomTextPrimary,
              ),
            ),
          ),
          if (_code.isNotEmpty) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: _copyInviteLink,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: chipBorder, width: 0.7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _code,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _copiedInvite
                          ? Icons.check_rounded
                          : Icons.copy_rounded,
                      size: 11,
                      color: _copiedInvite
                          ? DesignTokens.success
                          : DesignTokens.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
          IconButton(
            tooltip: _copiedInvite ? 'Copied!' : 'Copy invite link',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _copiedInvite ? Icons.check_rounded : Icons.copy_rounded,
                key: ValueKey(_copiedInvite),
                color: _copiedInvite
                    ? DesignTokens.success
                    : DesignTokens.roomTextPrimary,
                size: 20,
              ),
            ),
            onPressed: _copyInviteLink,
          ),
          IconButton(
            tooltip: 'Invite link',
            icon: const Icon(
              Icons.share_rounded,
              color: DesignTokens.roomTextPrimary,
              size: 20,
            ),
            onPressed: _copyInviteLink,
          ),
        ],
      ),
    );
  }

  Widget _buildRoom(BuildContext context) {
    final tiles = _tiles;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final crossAxisCount = constraints.maxWidth >= 1080
              ? 4
              : wide
              ? 3
              : 2;
          // Clamp the chat panel so the header + chat + control dock always fit
          // on short viewports (e.g. when the keyboard is open). The flexible
          // video grid absorbs whatever remains.
          final chatPanelHeight = _showChat
              ? (constraints.maxHeight - 216.0).clamp(112.0, 310.0)
              : 0.0;

          final stage = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Stack(
              children: [
                GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: crossAxisCount > 2 ? 1.0 : 0.92,
                  ),
                  itemCount: tiles.length,
                  itemBuilder: (context, index) => _buildTile(tiles[index]),
                ),
                // Floating emoji particles overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: Stack(
                      children: _reactions
                          .map(
                            (r) => _ReactionParticle(
                              key: ValueKey(r.id),
                              emoji: r.emoji,
                              dx: r.dx,
                              onDone: () => _removeReaction(r.id),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          );

          return Column(
            children: [
              _buildTallyRail(),
              _buildRoomHeader(),
              Expanded(
                child: wide && _showChat
                    ? Row(
                        children: [
                          Expanded(child: stage),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 320,
                            child: _buildChatPanel(
                              context,
                              height: double.infinity,
                            ),
                          ),
                        ],
                      )
                    : stage,
              ),
              if (!wide && _showChat) ...[
                _buildChatPanel(context, height: chatPanelHeight),
                const SizedBox(height: 8),
              ],
              _buildControlDock(context),
            ],
          );
        },
      ),
    );
  }

  /// A tracked uppercase slate: the broadcast label language of this world.
  Widget _slate(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: DesignTokens.roomGround),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: const TextStyle(
              color: DesignTokens.roomGround,
              fontSize: 9,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(_TileData tile) {
    final isSpeaking =
        tile.identity.isNotEmpty && _activeSpeaker == tile.identity;
    final handRaised =
        tile.isLocal && _handRaised ||
        (!tile.isLocal &&
            tile.identity.isNotEmpty &&
            _raisedHands.contains(tile.identity));
    final hostId = _hostUserId;
    final isHostTile =
        hostId != null && hostId > 0 && tile.identity == hostId.toString();

    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.roomChrome,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          // Speaking is the live state; the host wears a steady tally hairline.
          color: isSpeaking
              ? DesignTokens.signal
              : isHostTile
              ? DesignTokens.signal.withValues(alpha: 0.55)
              : DesignTokens.roomBorder,
          width: isSpeaking ? 2.5 : (isHostTile ? 1.5 : 1),
        ),
        boxShadow: isSpeaking
            ? [
                BoxShadow(
                  color: DesignTokens.signal.withValues(alpha: 0.32),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (tile.hasVideo && tile.videoTrack != null)
            VideoTrackRenderer(
              tile.videoTrack!,
              fit: tile.videoTrack!.source == TrackSource.screenShareVideo
                  ? VideoViewFit.contain
                  : VideoViewFit.cover,
            )
          else
            Center(
              child: CircleAvatar(
                radius: 28,
                backgroundColor: DesignTokens.primary.withValues(alpha: 0.22),
                child: Text(
                  tile.name.isEmpty
                      ? '?'
                      : tile.name
                            .substring(0, tile.name.length >= 2 ? 2 : 1)
                            .toUpperCase(),
                  style: const TextStyle(
                    color: DesignTokens.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          if (isHostTile)
            Positioned(
              top: 6,
              left: 6,
              child: _slate('HOST', DesignTokens.signal),
            ),
          if (handRaised)
            Positioned(
              top: 6,
              right: 6,
              child: _slate(
                'HAND UP',
                DesignTokens.signal,
                icon: Icons.pan_tool_alt_rounded,
              ),
            ),
          // Name + mic status overlay
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.66),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tile.isLocal ? 'You' : tile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isSpeaking)
                    const Icon(
                      Icons.graphic_eq_rounded,
                      color: DesignTokens.signal,
                      size: 14,
                    )
                  else
                    Icon(
                      tile.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: tile.muted
                          ? DesignTokens.danger
                          : DesignTokens.roomTextSecondary,
                      size: 13,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel(BuildContext context, {required double height}) {
    const inputBg = DesignTokens.roomPanel;
    const hintColor = DesignTokens.roomTextSecondary;

    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: DesignTokens.roomChrome,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.roomBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 4),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: DesignTokens.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'In-Meeting Chat',
                  style: TextStyle(
                    color: DesignTokens.roomTextPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: hintColor,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _showChat = false),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: DesignTokens.roomBorder),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: TextStyle(color: hintColor, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Align(
                          alignment: msg.isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.72,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: msg.isMine
                                  ? DesignTokens.primary
                                  : DesignTokens.roomPanel,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!msg.isMine)
                                  Text(
                                    msg.sender,
                                    style: const TextStyle(
                                      color: Color(0xFF7AB8FF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                if (!msg.isMine) const SizedBox(height: 2),
                                Text(
                                  msg.text,
                                  style: TextStyle(
                                    color: msg.isMine
                                        ? Colors.white
                                        : DesignTokens.roomTextPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Quick reactions
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickEmojis.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final emoji = _quickEmojis[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _sendReaction(emoji),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatCtrl,
                    style: const TextStyle(
                      color: DesignTokens.roomTextPrimary,
                      fontSize: 13,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendChat(),
                    decoration: const InputDecoration(
                      hintText: 'Send a message to the meeting…',
                      hintStyle: TextStyle(color: hintColor, fontSize: 12.5),
                      isDense: true,
                      filled: true,
                      fillColor: inputBg,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendChat,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  style: IconButton.styleFrom(
                    backgroundColor: DesignTokens.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The dock is a floating pill of state-labelled controls: icon above a
  /// tracked uppercase micro-label, coloured by what the control is doing.
  Widget _buildControlDock(BuildContext context) {
    final neutral = DesignTokens.roomTextPrimary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: DesignTokens.roomChrome,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: DesignTokens.roomBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _controlBtn(
              icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: _isMuted ? 'MUTED' : 'MUTE',
              color: _isMuted ? DesignTokens.danger : neutral,
              onTap: _toggleMic,
            ),
            _controlBtn(
              icon: _isCameraOff
                  ? Icons.videocam_off_rounded
                  : Icons.videocam_rounded,
              label: _isCameraOff ? 'CAM OFF' : 'CAMERA',
              color: _isCameraOff ? DesignTokens.danger : neutral,
              onTap: _toggleCamera,
            ),
            _controlBtn(
              icon: Icons.pan_tool_alt_rounded,
              label: _handRaised ? 'HAND UP' : 'RAISE',
              color: _handRaised ? DesignTokens.signal : neutral,
              onTap: _toggleRaiseHand,
            ),
            _controlBtn(
              icon: Icons.card_giftcard_rounded,
              label: 'GIFT',
              color: DesignTokens.primary,
              onTap: _sendGift,
            ),
            _controlBtn(
              icon: Icons.chat_bubble_rounded,
              label: 'CHAT',
              color: _showChat ? DesignTokens.primary : neutral,
              onTap: () => setState(() => _showChat = !_showChat),
            ),
            _controlBtn(
              icon: Icons.call_end_rounded,
              label: 'LEAVE',
              color: DesignTokens.danger,
              onTap: () => _leaveMeeting(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_TileData> get _tiles {
    final tiles = <_TileData>[];
    final room = _room;
    if (room != null) {
      final local = room.localParticipant;
      if (local != null) {
        tiles.add(
          _TileData(
            name: 'You',
            identity: local.identity,
            isLocal: true,
            hasVideo: !_isCameraOff && _localVideoTrack != null,
            videoTrack: _localVideoTrack,
            muted: _isMuted,
          ),
        );
      }
      for (final p in room.remoteParticipants.values) {
        Track? vTrack;
        var hasAudio = false;
        for (final pub in p.videoTrackPublications) {
          if (pub.subscribed && pub.track != null && !pub.muted) {
            vTrack = pub.track;
            break;
          }
        }
        for (final pub in p.audioTrackPublications) {
          if (pub.subscribed && pub.track != null && !pub.muted) {
            hasAudio = true;
            break;
          }
        }
        tiles.add(
          _TileData(
            name: p.name.isNotEmpty ? p.name : p.identity,
            identity: p.identity,
            isLocal: false,
            hasVideo: vTrack != null,
            videoTrack: vTrack is VideoTrack ? vTrack : null,
            muted: !hasAudio,
          ),
        );
      }
    }
    return tiles;
  }
}

class _TileData {
  final String name;
  final String identity;
  final bool isLocal;
  final bool hasVideo;
  final VideoTrack? videoTrack;
  final bool muted;

  const _TileData({
    required this.name,
    required this.identity,
    required this.isLocal,
    required this.hasVideo,
    this.videoTrack,
    required this.muted,
  });
}

/// Floating emoji particle that rises and fades on its own, then removes
/// itself via [onDone] (used for reactions and raise-hand animations).
class _ReactionParticle extends StatefulWidget {
  final String emoji;
  final double dx; // 0..1
  final VoidCallback onDone;

  const _ReactionParticle({
    super.key,
    required this.emoji,
    required this.dx,
    required this.onDone,
  });

  @override
  State<_ReactionParticle> createState() => _ReactionParticleState();
}

class _ReactionParticleState extends State<_ReactionParticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1800 + _rng.nextInt(700)),
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    final startDelay = Duration(milliseconds: _rng.nextInt(120));
    Future.delayed(startDelay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final t = _progress.value;
        final rise = t * (size.height * 0.35);
        final wobble = sin(t * pi * 3) * 14;
        return Positioned(
          left: widget.dx * size.width + wobble,
          bottom: 60 + rise,
          child: Opacity(
            opacity: (1 - t) * 0.95,
            child: Transform.scale(
              scale: 0.6 + 0.8 * t.clamp(0, 1),
              child: Text(
                widget.emoji,
                style: TextStyle(fontSize: 26 + 10 * t),
              ),
            ),
          ),
        );
      },
    );
  }
}
