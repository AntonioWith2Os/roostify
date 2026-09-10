part of '../../main.dart';

/// Native WebRTC player for the MediaMTX WHEP endpoint returned by the
/// Hostinger decoder backend.
class WhepVideoView extends StatefulWidget {
  const WhepVideoView({
    super.key,
    required this.sourceUrl,
    this.fit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    this.onConnectionChanged,
  });

  final String sourceUrl;
  final RTCVideoViewObjectFit fit;
  final ValueChanged<bool>? onConnectionChanged;

  @override
  State<WhepVideoView> createState() => _WhepVideoViewState();
}

class _WhepVideoViewState extends State<WhepVideoView> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  Uri? _sessionUri;
  bool _rendererReady = false;
  bool _connected = false;
  bool _disposed = false;
  int _generation = 0;
  String _status = 'Connecting to the Roostify cloud…';

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant WhepVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceUrl != widget.sourceUrl) {
      unawaited(_restart());
    }
  }

  Future<void> _initialize() async {
    try {
      await _renderer.initialize();
      if (_disposed) {
        await _renderer.dispose();
        return;
      }
      _renderer.onFirstFrameRendered = () {
        if (_disposed || !mounted) return;
        setState(() => _status = 'Live');
      };
      setState(() => _rendererReady = true);
      await _connect();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _restart() async {
    final generation = ++_generation;
    _setConnected(false);
    if (mounted) {
      setState(() => _status = 'Reconnecting to the Roostify cloud…');
    }
    await _closeSession();
    if (_disposed || generation != _generation) return;
    await _connect();
  }

  Future<void> _connect() async {
    final generation = ++_generation;
    try {
      final endpoint = Uri.parse(
        await resolveCameraWebRtcUrl(widget.sourceUrl),
      );
      if (_disposed || generation != _generation) return;

      final peer = await createPeerConnection({'sdpSemantics': 'unified-plan'});
      if (_disposed || generation != _generation) {
        await peer.close();
        await peer.dispose();
        return;
      }
      _peerConnection = peer;

      peer.onConnectionState = (state) {
        if (_disposed || generation != _generation) return;
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _setConnected(true);
            if (mounted) setState(() => _status = 'Live');
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            _setConnected(false);
            if (mounted) {
              setState(() => _status = 'WebRTC connection lost. Tap to retry.');
            }
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateNew:
          case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
            break;
        }
      };
      peer.onTrack = (event) {
        if (_disposed || generation != _generation || event.streams.isEmpty) {
          return;
        }
        _renderer.srcObject = event.streams.first;
        if (mounted) setState(() {});
      };

      await peer.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      await peer.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      final iceComplete = Completer<void>();
      peer.onIceGatheringState = (state) {
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
            !iceComplete.isCompleted) {
          iceComplete.complete();
        }
      };
      final offer = await peer.createOffer();
      await peer.setLocalDescription(offer);
      if (peer.iceGatheringState !=
          RTCIceGatheringState.RTCIceGatheringStateComplete) {
        await iceComplete.future.timeout(const Duration(seconds: 8));
      }
      final localDescription = await peer.getLocalDescription();
      final offerSdp = localDescription?.sdp;
      if (offerSdp == null || offerSdp.isEmpty) {
        throw const FormatException(
          'WebRTC could not create a playback offer.',
        );
      }

      final response = await _postOffer(endpoint, offerSdp);
      if (_disposed || generation != _generation) return;
      _sessionUri = response.sessionUri;
      await peer.setRemoteDescription(
        RTCSessionDescription(response.answerSdp, 'answer'),
      );
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _showError(error);
    }
  }

  Future<_WhepAnswer> _postOffer(Uri endpoint, String offerSdp) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(endpoint);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/sdp')
        ..contentType = ContentType('application', 'sdp');
      request.write(offerSdp);
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final answer = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.created &&
          response.statusCode != HttpStatus.ok) {
        throw V380BackendException(
          'MediaMTX rejected WebRTC playback with HTTP ${response.statusCode}.',
        );
      }
      if (answer.trim().isEmpty) {
        throw const FormatException(
          'MediaMTX returned an empty WebRTC answer.',
        );
      }
      final location = response.headers.value(HttpHeaders.locationHeader);
      return _WhepAnswer(
        answerSdp: answer,
        sessionUri: location == null ? null : endpoint.resolve(location),
      );
    } on TimeoutException {
      throw const V380BackendException(
        'MediaMTX did not complete the WebRTC handshake in time.',
      );
    } on SocketException catch (error) {
      throw V380BackendException(
        'Cannot reach the MediaMTX WebRTC endpoint: ${error.message}',
      );
    } finally {
      client.close(force: true);
    }
  }

  void _showError(Object error) {
    _setConnected(false);
    if (!mounted || _disposed) return;
    setState(() {
      _status = '${_friendlyV380BackendError(error)} Tap to retry.';
    });
  }

  void _setConnected(bool value) {
    if (_connected == value) return;
    _connected = value;
    widget.onConnectionChanged?.call(value);
  }

  Future<void> _closeSession() async {
    final peer = _peerConnection;
    final sessionUri = _sessionUri;
    _peerConnection = null;
    _sessionUri = null;
    if (_rendererReady) {
      _renderer.srcObject = null;
    }
    if (peer != null) {
      try {
        await peer.close();
      } catch (_) {}
      try {
        await peer.dispose();
      } catch (_) {}
    }
    if (sessionUri != null) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3);
      try {
        final request = await client.deleteUrl(sessionUri);
        await request.close().timeout(const Duration(seconds: 5));
      } catch (_) {
        // MediaMTX also cleans abandoned WHEP sessions after the peer closes.
      } finally {
        client.close(force: true);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    _setConnected(false);
    unawaited(_disposeResources());
    super.dispose();
  }

  Future<void> _disposeResources() async {
    await _closeSession();
    await _renderer.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _connected ? null : _restart,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_rendererReady)
            RTCVideoView(
              _renderer,
              objectFit: widget.fit,
              placeholderBuilder: (_) => const _LiveFeedPlaceholder(),
            )
          else
            const _LiveFeedPlaceholder(),
          if (!_connected)
            ColoredBox(
              color: Colors.black38,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WhepAnswer {
  const _WhepAnswer({required this.answerSdp, required this.sessionUri});

  final String answerSdp;
  final Uri? sessionUri;
}
