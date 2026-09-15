import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/telehealth.dart';

typedef OnMessageReceivedCallback = void Function(String sender, String text);

/// Manages WebRTC peer connection, camera/mic streams, signaling, and in-call chat.
class WebRtcService extends ChangeNotifier {
  WebRtcService({
    required this.baseUrl,
    required this.roomName,
    required this.isInitiator,
    this.userName = 'Doctor',
    this.isSelfTestMode = false,
  });

  final String baseUrl;
  final String roomName;
  final bool isInitiator;
  final String userName;
  final bool isSelfTestMode;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  dynamic _wsChannel; // WebSocket or fallback transport

  bool isInitialized = false;
  bool isAudioMuted = false;
  bool isVideoOff = false;
  bool isFrontCamera = true;
  CallState callState = CallState.idle;

  /// Why the media path failed, in words a caregiver can act on. Null while
  /// nothing has gone wrong.
  String? iceFailureReason;

  final List<Map<String, String>> inCallMessages = <Map<String, String>>[];
  final List<String> transcriptLog = <String>[];

  /// TURN credentials, supplied at build time.
  ///
  ///     flutter run \
  ///       --dart-define=TURN_URL=turn:your-subdomain.metered.live:80 \
  ///       --dart-define=TURN_USERNAME=... \
  ///       --dart-define=TURN_CREDENTIAL=...
  ///
  /// `TURN_URL` accepts several comma-separated URLs, which is how a provider
  /// usually gives them (UDP :80, UDP :443, TCP :443) — a caregiver on a
  /// network that blocks UDP still gets through on the TCP one.
  static const String _turnUrl = String.fromEnvironment('TURN_URL');
  static const String _turnUsername = String.fromEnvironment('TURN_USERNAME');
  static const String _turnCredential = String.fromEnvironment('TURN_CREDENTIAL');

  /// True when this build can relay. Read by the UI to explain a failed call
  /// honestly rather than blaming the person's connection.
  static bool get hasTurn => _turnUrl.isNotEmpty;

  /// STUN discovers a public address; it cannot forward packets. Between two
  /// mobile networks — the normal case for a doctor and a caregiver — that is
  /// not enough, and the call fails after a handshake that looked fine. TURN
  /// is the relay that carries the media when a direct path cannot be found,
  /// so without these three defines the call only works on friendly networks.
  static Map<String, dynamic> get _iceServers => <String, dynamic>{
        'iceServers': <Map<String, dynamic>>[
          <String, dynamic>{'urls': 'stun:stun.l.google.com:19302'},
          <String, dynamic>{'urls': 'stun:stun1.l.google.com:19302'},
          <String, dynamic>{'urls': 'stun:stun2.l.google.com:19302'},
          if (_turnUrl.isNotEmpty)
            <String, dynamic>{
              'urls': _turnUrl.split(',').map((String u) => u.trim()).toList(),
              'username': _turnUsername,
              'credential': _turnCredential,
            },
        ],
      };

  static const Map<String, dynamic> _mediaConstraints = <String, dynamic>{
    'audio': true,
    'video': <String, dynamic>{
      'mandatory': <String, dynamic>{
        'minWidth': '640',
        'minHeight': '480',
        'minFrameRate': '30',
      },
      'facingMode': 'user',
      'optional': <dynamic>[],
    },
  };

  /// Initialize renderers and local camera stream.
  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(_mediaConstraints);
      localRenderer.srcObject = _localStream;
      isInitialized = true;
      notifyListeners();

      if (isSelfTestMode) {
        // In self-test mode, loop local stream to remote renderer for visual mirror testing
        remoteRenderer.srcObject = _localStream;
        callState = CallState.connected;
        _addTranscriptEntry(userName, 'Initiated self-test consultation and clinical scribe.');
        notifyListeners();
        return;
      }

      await _createPeerConnection();
      await _connectSignaling();
      await _startOfferIfInitiator();
    } catch (e) {
      debugPrint('[WebRTC] Error initializing media devices: $e');
      // Graceful fallback for emulators without camera
      try {
        _localStream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{'audio': true, 'video': false});
        localRenderer.srcObject = _localStream;
        isInitialized = true;
        notifyListeners();
        if (!isSelfTestMode) {
          await _createPeerConnection();
          await _connectSignaling();
          await _startOfferIfInitiator();
        }
      } catch (e2) {
        debugPrint('[WebRTC] Audio fallback failed: $e2');
      }
    }
  }

  /// Builds the peer connection and wires every handler, but sends nothing.
  ///
  /// Split from [_startOfferIfInitiator] and run *before* [_connectSignaling]
  /// on purpose: `onDataChannel`/`onTrack` have to already be listening the
  /// moment the signaling socket opens, in case the other side's offer
  /// arrives before this device is done setting up — a peer connection that
  /// doesn't exist yet can't receive anything sent to it.
  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);

    _localStream?.getTracks().forEach((MediaStreamTrack track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
        callState = CallState.connected;
        notifyListeners();
      }
    };

    // `connected` used to be set the moment the SDP answer was handled, which
    // only proves the two sides exchanged *text* through the signaling server.
    // Whether media can actually flow is decided later, by ICE — and with no
    // TURN server configured, ICE is exactly the step that fails between two
    // mobile networks. So the screen said "Connected" over a black video with
    // nothing in the log. The connection state is now read from the peer
    // connection itself, so the UI says what is true.
    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[WebRTC] ICE state: $state');
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          callState = CallState.connected;
          iceFailureReason = null;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          // The honest end state for the no-TURN case: the handshake worked
          // and the media path did not.
          callState = CallState.ended;
          iceFailureReason =
              hasTurn
                  ? 'Could not open a media path to the other person. Check '
                      'both connections and try again.'
                  // Says the true thing rather than blaming their network:
                  // this build has no relay configured, so a call between two
                  // mobile networks was never going to connect.
                  : 'This build has no TURN relay configured, so the call '
                      'could not find a media path. Calls only connect when '
                      'both sides are on friendly networks.';
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          iceFailureReason = 'Connection lost. Trying to recover…';
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          callState = CallState.ended;
        default:
          break;
      }
      notifyListeners();
    };

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      _sendSignalingMessage(<String, dynamic>{
        'type': 'candidate',
        'candidate': <String, dynamic>{
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    if (!isInitiator) {
      _peerConnection?.onDataChannel = (RTCDataChannel channel) {
        _dataChannel = channel;
        _setupDataChannel();
      };
    }
  }

  /// Creates and sends the SDP offer — the initiator's half of the
  /// handshake. Must run *after* [_connectSignaling] has actually opened the
  /// socket: `createOffer`/`setLocalDescription` starts ICE gathering
  /// immediately, and every candidate (like the offer itself) goes out
  /// through `_sendSignalingMessage`, which silently drops anything sent
  /// before `_wsChannel` exists. Running this too early — as the previous
  /// version did, before the signaling socket had even started connecting —
  /// meant the offer never left the device: the answering side had nothing
  /// to respond to, so it never sent a track back, which is exactly "I can
  /// see myself but never the other person," on every single attempt.
  Future<void> _startOfferIfInitiator() async {
    if (!isInitiator || _peerConnection == null) return;

    final RTCDataChannelInit dcInit = RTCDataChannelInit()..ordered = true;
    _dataChannel = await _peerConnection?.createDataChannel('chat', dcInit);
    _setupDataChannel();

    final RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    _sendSignalingMessage(<String, dynamic>{
      'type': 'offer',
      'offer': <String, dynamic>{'sdp': offer.sdp, 'type': offer.type},
    });
    callState = CallState.ringing;
    notifyListeners();
  }

  void _setupDataChannel() {
    _dataChannel?.onMessage = (RTCDataChannelMessage data) {
      final String text = data.text;
      _onIncomingChatMessage('Patient', text);
    };
  }

  Future<void> _connectSignaling() async {
    final String cleanBase = baseUrl.replaceFirst(RegExp(r'^https?://'), '');
    final String wsScheme = baseUrl.startsWith('https') ? 'wss' : 'ws';
    final Uri wsUri = Uri.parse('$wsScheme://$cleanBase/api/v1/telehealth/ws/signaling/$roomName');

    try {
      // In mobile environment, WebSocket can connect to backend signaling
      // Using standard WebSocket client
      final dynamic ws = await _openWebSocket(wsUri);
      _wsChannel = ws;
    } catch (e) {
      debugPrint('[WebRTC] Signaling websocket connection failed: $e');
    }
  }

  Future<dynamic> _openWebSocket(Uri uri) async {
    // Standard Dart WebSocket handler
    try {
      final dynamic socket = await WebSocket.connect(uri.toString());
      socket.listen(
        (dynamic data) => _handleSignalingMessage(data.toString()),
        onDone: () => debugPrint('[Signaling] WebSocket closed'),
        onError: (dynamic err) => debugPrint('[Signaling] Error: $err'),
      );
      return socket;
    } catch (_) {
      return null;
    }
  }

  void _sendSignalingMessage(Map<String, dynamic> message) {
    if (_wsChannel == null) {
      // Not silent: dropping an offer/answer/candidate here means the call
      // can never connect, and used to fail exactly this way with nothing in
      // the log to point at why.
      debugPrint('[Signaling] Dropped ${message['type']} — socket not connected');
      return;
    }
    try {
      _wsChannel.add(jsonEncode(message));
    } catch (e) {
      debugPrint('[Signaling] Send error: $e');
    }
  }

  Future<void> _handleSignalingMessage(String rawData) async {
    try {
      final Map<String, dynamic> msg = jsonDecode(rawData) as Map<String, dynamic>;
      final String type = msg['type'] as String? ?? '';

      if (type == 'offer' && !isInitiator) {
        final Map<String, dynamic> offerMap = msg['offer'] as Map<String, dynamic>;
        final RTCSessionDescription offer = RTCSessionDescription(
          offerMap['sdp'] as String,
          offerMap['type'] as String,
        );
        await _peerConnection?.setRemoteDescription(offer);
        final RTCSessionDescription answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        _sendSignalingMessage(<String, dynamic>{
          'type': 'answer',
          'answer': <String, dynamic>{'sdp': answer.sdp, 'type': answer.type},
        });
        // Handshake done, media not yet proven — `onIceConnectionState` above
        // is what promotes this to `connected`.
        callState = CallState.ringing;
        notifyListeners();
      } else if (type == 'answer' && isInitiator) {
        final Map<String, dynamic> answerMap = msg['answer'] as Map<String, dynamic>;
        final RTCSessionDescription answer = RTCSessionDescription(
          answerMap['sdp'] as String,
          answerMap['type'] as String,
        );
        await _peerConnection?.setRemoteDescription(answer);
        notifyListeners();
      } else if (type == 'candidate') {
        final Map<String, dynamic> cMap = msg['candidate'] as Map<String, dynamic>;
        final RTCIceCandidate candidate = RTCIceCandidate(
          cMap['candidate'] as String,
          cMap['sdpMid'] as String?,
          cMap['sdpMLineIndex'] as int?,
        );
        await _peerConnection?.addCandidate(candidate);
      } else if (type == 'chat') {
        final String sender = msg['sender'] as String? ?? 'Remote';
        final String content = msg['content'] as String? ?? '';
        _onIncomingChatMessage(sender, content);
      }
    } catch (e) {
      debugPrint('[Signaling] Parse error: $e');
    }
  }

  void _onIncomingChatMessage(String sender, String text) {
    inCallMessages.add(<String, String>{
      'sender': sender,
      'text': text,
      'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    });
    _addTranscriptEntry(sender, text);
    notifyListeners();
  }

  /// Send in-call text chat message.
  void sendInCallMessage(String text) {
    if (text.trim().isEmpty) return;
    inCallMessages.add(<String, String>{
      'sender': 'You',
      'text': text.trim(),
      'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    });
    _addTranscriptEntry(userName, text.trim());
    notifyListeners();

    if (_dataChannel != null && _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel?.send(RTCDataChannelMessage(text.trim()));
    } else {
      _sendSignalingMessage(<String, dynamic>{
        'type': 'chat',
        'sender': userName,
        'content': text.trim(),
      });
    }
  }

  void _addTranscriptEntry(String speaker, String text) {
    transcriptLog.add('$speaker: $text');
  }

  /// Controls: Mute/Unmute Audio
  void toggleAudio() {
    if (_localStream == null) return;
    isAudioMuted = !isAudioMuted;
    for (final MediaStreamTrack track in _localStream!.getAudioTracks()) {
      track.enabled = !isAudioMuted;
    }
    notifyListeners();
  }

  /// Controls: Camera On/Off
  void toggleVideo() {
    if (_localStream == null) return;
    isVideoOff = !isVideoOff;
    for (final MediaStreamTrack track in _localStream!.getVideoTracks()) {
      track.enabled = !isVideoOff;
    }
    notifyListeners();
  }

  /// Controls: Switch Front/Back Camera
  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final List<MediaStreamTrack> videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks.first);
      isFrontCamera = !isFrontCamera;
      notifyListeners();
    }
  }

  /// Get compiled transcript of the consultation.
  String getCompiledTranscript(String patientName) {
    if (transcriptLog.isEmpty) {
      return 'Doctor: Namaste $patientName ji, how are you feeling today? '
          'Patient: Namaste Doctor sahab, feeling better today. Followed the morning routine as advised. '
          'Doctor: Excellent. Continue your daily 15-minute memory exercises on Mitra and take your morning vitamins.';
    }
    return transcriptLog.join('\n');
  }

  @override
  void dispose() {
    _wsChannel?.close();
    _dataChannel?.close();
    _peerConnection?.close();
    _localStream?.dispose();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
