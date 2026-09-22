part of '../../main.dart';

/// Speaks the proprietary V380 camera protocol directly from the phone, with
/// no backend involved. Dart port of `cs_tmp/V380Decoder/src/V380Client.cs`,
/// specialized to the one mode this app needs: connecting to a camera through
/// a V380 cloud relay server (resolved by [V380CloudDispatch]) rather than a
/// LAN IP. Fields the reference only ever populates on its (unused here) LAN
/// path - `audioBits`, `communicationVersion`, frame width/height - are left
/// at their cloud-mode defaults, matching the reference's own behavior in
/// this mode, and the dead branches that only trigger from those fields
/// (`communicationVersion == 21`, 16-bit/ADPCM audio) are omitted.
class V380ProtocolClient {
  V380ProtocolClient({
    required this.initialIp,
    required this.resolveIp,
    required this.deviceId,
    required this.username,
    required this.password,
    this.port = 8800,
    this.streamQuality = 1,
  });

  /// The relay IP already resolved by the caller before starting the
  /// session (so a completely unreachable camera can fail fast).
  final String initialIp;

  /// Re-resolves the camera's current relay IP through [V380CloudDispatch].
  /// Called again whenever the connect/stream loop hits
  /// [_reresolveAfterFailures] consecutive failures on the current IP -
  /// V380's cloud reassigns cameras between relay nodes, so retrying the
  /// same dead IP forever (the previous behavior) leaves the app stuck
  /// until the whole camera entry is torn down and recreated.
  final Future<String?> Function() resolveIp;

  final int port;
  final int deviceId;
  final String username;
  final String password;
  final int streamQuality; // 0 = SD, 1 = HD

  final _framesController = StreamController<V380Frame>.broadcast();
  final _stateController =
      StreamController<(V380ConnectionState, String?)>.broadcast();

  Stream<V380Frame> get frames => _framesController.stream;
  Stream<(V380ConnectionState, String?)> get connectionState =>
      _stateController.stream;

  Socket? _streamSocket;
  _SocketReader? _streamReader;
  _V380AesEcb? _decryptCipher;

  int _authTicket = 0;
  int _sessionId = 0;
  int _deviceVersion = 0;

  /// Set by [_getAuthTicket] when the camera explicitly rejects the login
  /// (cmd 1168, loginResult != 1001), naming which field it blamed - mirrors
  /// the result-code mapping in `cs_tmp/V380Decoder/src/V380Client.cs`
  /// (1011/1012/1018). Null for any other failure (timeout, bad response
  /// shape, etc), which retries instead of treating it as a hard rejection.
  String? _lastAuthRejectionReason;
  double _audioClockMs = 0;
  bool _stopped = false;
  String? _currentIp;
  int _consecutiveFailures = 0;
  int _backoffAttempt = 0;

  static const _handshakeTimeout = Duration(seconds: 5);
  static const _frameTimeout = Duration(seconds: 15);

  /// How many consecutive connect/login/start failures on the current relay
  /// IP before giving up on it and asking [resolveIp] for a fresh one.
  static const _reresolveAfterFailures = 2;

  static const _baseBackoff = Duration(seconds: 3);
  static const _maxBackoff = Duration(seconds: 30);

  /// Runs the connect/stream/reconnect loop until [stop] is called. Mirrors
  /// `V380Client.Run` in `cs_tmp/v380connectorbackend/src/V380Client.cs`
  /// (the backend's version, which layered connection-state reporting and
  /// auto-reconnect on top of the standalone decoder's engine), extended to
  /// re-resolve the relay IP on repeated failure instead of retrying a
  /// single IP forever.
  Future<void> run() async {
    _currentIp = initialIp;
    while (!_stopped) {
      try {
        _notify(V380ConnectionState.connecting, null);

        if (_currentIp == null) {
          final resolved = await resolveIp();
          if (_stopped) break;
          if (resolved == null) {
            _notify(
              V380ConnectionState.reconnecting,
              'Unable to locate a V380 cloud relay for this camera; retrying.',
            );
            if (await _waitOrStop(_nextBackoff())) break;
            continue;
          }
          _currentIp = resolved;
        }

        final auth = await _getAuthTicket();
        if (auth == 0) {
          _notify(
            V380ConnectionState.reconnecting,
            'Unable to authenticate with the camera; retrying.',
          );
          _registerFailure();
          if (await _waitOrStop(_nextBackoff())) break;
          continue;
        }
        if (auth == -1) {
          _notify(
            V380ConnectionState.authenticationFailed,
            _lastAuthRejectionReason ??
                'The camera rejected the device ID or credentials.',
          );
          break;
        }

        if (!await _streamLogin()) {
          _notify(
            V380ConnectionState.reconnecting,
            'V380 stream login failed; retrying.',
          );
          await _closeStreamSocket();
          _registerFailure();
          if (await _waitOrStop(_nextBackoff())) break;
          continue;
        }

        if (!await _startStream()) {
          _notify(
            V380ConnectionState.reconnecting,
            'The V380 start-stream command failed; retrying.',
          );
          await _closeStreamSocket();
          _registerFailure();
          if (await _waitOrStop(_nextBackoff())) break;
          continue;
        }

        _consecutiveFailures = 0;
        _backoffAttempt = 0;
        _lastStreamEndReason = null;
        await _receiveFrames();
        if (!_stopped) {
          _notify(
            V380ConnectionState.reconnecting,
            _lastStreamEndReason ?? 'The camera stream ended; reconnecting.',
          );
        }
      } catch (error) {
        _notify(V380ConnectionState.reconnecting, '$error');
        _registerFailure();
        if (await _waitOrStop(_nextBackoff())) break;
      } finally {
        await _closeStreamSocket();
      }
    }
    if (_stopped) {
      _notify(V380ConnectionState.offline, null);
    }
  }

  /// Counts a failure against the current relay IP, dropping it once
  /// [_reresolveAfterFailures] is reached so the next loop iteration asks
  /// [resolveIp] for a (possibly different) relay instead of retrying a
  /// relay that may have been decommissioned or reassigned.
  void _registerFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _reresolveAfterFailures) {
      _consecutiveFailures = 0;
      _currentIp = null;
    }
  }

  /// Doubles the retry delay on every consecutive failure (capped at
  /// [_maxBackoff]) with +/-20% jitter, instead of hammering a struggling
  /// relay or dispatch endpoint on a flat 3-second cadence. Resets to the
  /// base delay as soon as a stream actually starts.
  Duration _nextBackoff() {
    final exponent = math.min(_backoffAttempt, 4);
    _backoffAttempt++;
    final scaledMs = _baseBackoff.inMilliseconds * (1 << exponent);
    final cappedMs = math.min(scaledMs, _maxBackoff.inMilliseconds);
    final jitter = 0.8 + math.Random().nextDouble() * 0.4;
    return Duration(milliseconds: (cappedMs * jitter).round());
  }

  void stop() {
    _stopped = true;
  }

  Future<void> dispose() async {
    _stopped = true;
    await _closeStreamSocket();
    if (!_framesController.isClosed) await _framesController.close();
    if (!_stateController.isClosed) await _stateController.close();
  }

  void _notify(V380ConnectionState state, String? error) {
    if (!_stateController.isClosed) _stateController.add((state, error));
  }

  Future<bool> _waitOrStop(Duration duration) async {
    final deadline = DateTime.now().add(duration);
    while (DateTime.now().isBefore(deadline)) {
      if (_stopped) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return _stopped;
  }

  // ── Auth (cmd 1167/1168) ──────────────────────────────────────────
  Future<int> _getAuthTicket() async {
    Socket? socket;
    _SocketReader? reader;
    try {
      socket = await Socket.connect(
        _currentIp!,
        port,
        timeout: _handshakeTimeout,
      );
      reader = _SocketReader(socket);

      final encryptedPassword = _generatePassword(password);
      final cmd = Uint8List(520);
      v380WriteU32(cmd, 0, 1167);
      v380WriteU32(cmd, 4, 1022);
      cmd[8] = 31;
      v380WriteU32(cmd, 9, 1);
      v380WriteU32(cmd, 13, deviceId);
      v380WriteAsciiPadded(cmd, 17, '$deviceId.nvdvr.net', 50);
      v380WriteU32(cmd, 67, port);
      v380WriteAsciiPadded(cmd, 71, username, 32);
      cmd.setRange(
        103,
        103 + math.min(encryptedPassword.length, 64),
        encryptedPassword,
      );

      socket.add(cmd);
      await socket.flush();

      final resp = await reader.readAtLeast(256, _handshakeTimeout);
      if (resp.length < 256) return 0;

      final respCmd = v380ReadU32(resp, 0);
      if (respCmd != 1168) return 0;

      final loginResult = v380ReadU32(resp, 4);
      // 1001 is the "direct server" success code from the original
      // prsyahmi/v380 reverse-engineering. That project's docs also name
      // 1002 ("LoginFromMRServerEX") as a distinct, legitimate success case
      // for logins through a media-relay server - exactly this app's only
      // connection mode (see V380CloudDispatch) - which our fixed check
      // used to treat as a hard rejection. The real rejection codes (invalid
      // username/password/device ID) live in the unrelated 1010s range.
      if (loginResult != 1001 && loginResult != 1002) {
        _lastAuthRejectionReason = switch (loginResult) {
          1011 => 'The camera rejected the username.',
          1012 => 'The camera rejected the password.',
          1018 => 'The camera rejected the device ID.',
          _ => 'The camera rejected the login (code $loginResult).',
        };
        return -1;
      }

      _deviceVersion = resp[12];
      _authTicket = v380ReadU32(resp, 13);
      _sessionId = v380ReadU32(resp, 17);
      return 1;
    } catch (_) {
      return 0;
    } finally {
      await reader?.close();
      socket?.destroy();
    }
  }

  // ── Stream login (cmd 301/401) + start (cmd 303) ──────────────────
  Future<bool> _streamLogin() async {
    final socket = await Socket.connect(
      _currentIp!,
      port,
      timeout: _handshakeTimeout,
    );
    socket.setOption(SocketOption.tcpNoDelay, true);
    _streamSocket = socket;
    _streamReader = _SocketReader(socket);

    // Field values below are verified against a packet capture of the
    // official V380 Pro app's actual cmd-301 request against a working
    // camera, not just the reverse-engineered struct's field names/offsets
    // (which are right, but several of the "unknownN" values here were
    // wrong guesses - see the fix that introduced this comment).
    final cmd = Uint8List(256);
    v380WriteU32(cmd, 0, 301);
    v380WriteU32(cmd, 4, 1002);
    v380WriteAsciiPadded(cmd, 8, '$deviceId.nvdvr.net', 50);
    v380WriteU32(cmd, 58, port);
    v380WriteU32(cmd, 62, deviceId);
    v380WriteU32(cmd, 66, _authTicket);
    v380WriteU32(cmd, 70, _sessionId);
    v380WriteU32(cmd, 74, streamQuality);
    cmd[78] = 21;
    v380WriteU32(cmd, 79, 4096);

    socket.add(cmd);
    await socket.flush();

    final resp = await _streamReader!.readAtLeast(16, _handshakeTimeout);
    if (resp.length < 8) return false;

    final respCmd = v380ReadU32(resp, 0);
    if (respCmd != 401) return false;

    final result = v380ReadU32(resp, 4).toSigned(32);
    if (result == -11 || result == -12) return false;

    if (_deviceVersion > 30) _generateMediaKey(_authTicket);
    return true;
  }

  Future<bool> _startStream() async {
    // A packet capture of the official app's cmd-303 request confirms this
    // is a fixed protocol constant, not derived from the stream-login
    // response (an earlier fix here guessed it should echo that response's
    // result field - a real working session showed the response was 100
    // while this field stayed 0x3001 regardless, disproving that guess).
    final cmd = Uint8List(256);
    v380WriteU32(cmd, 0, 303);
    v380WriteU32(cmd, 4, 0x3001);
    _streamSocket!.add(cmd);
    await _streamSocket!.flush();
    return true;
  }

  // ── Frame reassembly + dispatch, port of ReceiveFrames/HandleAsMediaFrame
  // in cs_tmp/V380Decoder/src/V380Client.cs ─────────────────────────
  /// Set right before _receiveFrames returns early, naming why the stream
  /// ended - a closed/errored socket and a plain read timeout (camera
  /// accepted start-stream but never actually sent frame data) point at very
  /// different problems, which the generic "stream ended" message collapsed.
  String? _lastStreamEndReason;

  String _describeStreamEnd(String waitingFor) {
    final reader = _streamReader!;
    if (reader.lastError != null) {
      return 'The camera stream connection errored while waiting for $waitingFor: ${reader.lastError}.';
    }
    if (reader.isClosed) {
      return 'The camera closed the stream connection while waiting for $waitingFor (${reader.bufferedByteCount} bytes buffered).';
    }
    return 'No $waitingFor arrived from the camera within ${_frameTimeout.inSeconds}s (${reader.bufferedByteCount} bytes buffered).';
  }

  Future<void> _receiveFrames() async {
    final needDecrypt = _deviceVersion > 30;
    var reportedOnline = false;

    var frameFrags = <Uint8List>[];
    var frameTotal = 0;
    var nextFragment = 0;
    var frameStartType = 0;
    var assemblingFrame = false;

    while (!_stopped) {
      final header = await _streamReader!.readExact(12, _frameTimeout);
      if (header == null) {
        _lastStreamEndReason = _describeStreamEnd('a frame header');
        return;
      }
      if (header[0] != 0x7F) continue;

      final type = header[1];
      final totalFrame = v380ReadU16(header, 3);
      final curFrame = v380ReadU16(header, 5);
      final payLen = v380ReadU16(header, 7);

      if (payLen == 0 ||
          payLen > 20000 ||
          totalFrame == 0 ||
          curFrame >= totalFrame) {
        continue;
      }

      final payload = await _streamReader!.readExact(payLen, _frameTimeout);
      if (payload == null) {
        _lastStreamEndReason = _describeStreamEnd('a frame payload');
        return;
      }

      if (type == 0x5B) continue;

      if (curFrame == 0 ||
          !assemblingFrame ||
          totalFrame != frameTotal ||
          curFrame != nextFragment) {
        frameFrags = <Uint8List>[];
        frameTotal = totalFrame;
        nextFragment = 0;
        frameStartType = type;
        assemblingFrame = true;
      }

      frameFrags.add(payload);
      nextFragment = curFrame + 1;

      if (curFrame != totalFrame - 1) continue;

      final totalLen = frameFrags.fold<int>(
        0,
        (total, part) => total + part.length,
      );
      if (totalLen < 16) {
        frameFrags = <Uint8List>[];
        assemblingFrame = false;
        continue;
      }

      final full = _concatFragments(frameFrags);
      frameFrags = <Uint8List>[];
      assemblingFrame = false;

      final handled = _handleAsMediaFrame(frameStartType, full, needDecrypt);
      if (handled && !reportedOnline) {
        reportedOnline = true;
        _notify(V380ConnectionState.online, null);
      }
    }
  }

  bool _handleAsMediaFrame(int rawType, Uint8List full, bool needDecrypt) {
    final outerTimestamp = full.length >= 16 ? v380ReadU64(full, 8) : 0;

    // Audio, classic path (8-bit G.711, no extra header trim beyond 16 bytes).
    if (rawType == 0x1A) {
      if (full.length < 16) return false;
      final payload = Uint8List.fromList(full.sublist(16));
      if (needDecrypt) _decryptAudioFrame(payload, payload.length);
      if (!_framesController.isClosed) {
        _framesController.add(
          V380Frame(
            isVideo: false,
            codec: V380VideoCodec.unknown,
            payload: payload,
            timestamp: outerTimestamp,
          ),
        );
      }
      return true;
    }

    // Audio, newer path.
    if (rawType == 0x16) {
      final audioPayload = _extractAudioPayload(full, needDecrypt);
      if (audioPayload.isEmpty) return false;
      // PCMA/8000/1: 1 byte == 1 sample == 1/8 ms. Timestamp must keep
      // increasing across frames for downstream RTP muxing.
      final ts = _audioClockMs.round();
      _audioClockMs += audioPayload.length / 8.0;
      if (!_framesController.isClosed) {
        _framesController.add(
          V380Frame(
            isVideo: false,
            codec: V380VideoCodec.unknown,
            payload: audioPayload,
            timestamp: ts,
          ),
        );
      }
      return true;
    }

    final normalized = _tryExtractVideoPayload(full, needDecrypt);
    if (normalized == null) return false;

    final codec = _detectVideoCodec(normalized);
    if (!_framesController.isClosed) {
      _framesController.add(
        V380Frame(
          isVideo: true,
          codec: codec,
          payload: normalized,
          timestamp: outerTimestamp,
        ),
      );
    }
    return true;
  }

  Uint8List _extractAudioPayload(Uint8List full, bool needDecrypt) {
    const headerLen = 20;
    final payload = full.length > headerLen
        ? Uint8List.fromList(full.sublist(headerLen))
        : Uint8List.fromList(full);
    if (needDecrypt && payload.length >= 16) {
      _decryptAudioFrame(payload, payload.length);
    }
    return payload;
  }

  Uint8List? _tryExtractVideoPayload(Uint8List full, bool needDecrypt) {
    var bestScore = -0x7fffffff;
    Uint8List? best;
    for (final candidate in _enumerateVideoCandidates(full, needDecrypt)) {
      final normalized = _tryNormalizeVideoPayload(candidate);
      if (normalized == null) continue;
      final score = _scoreVideoPayload(normalized);
      if (score > bestScore) {
        bestScore = score;
        best = normalized;
      }
    }
    return best;
  }

  Iterable<Uint8List> _enumerateVideoCandidates(
    Uint8List full,
    bool needDecrypt,
  ) sync* {
    const offset = 16;
    if (full.length <= offset) return;
    final direct = Uint8List.fromList(full.sublist(offset));
    if (needDecrypt && direct.length >= 16) {
      final decrypted = Uint8List.fromList(direct);
      _decryptVideoFrame(decrypted, decrypted.length);
      yield decrypted;
    }
    yield direct;
  }

  Uint8List? _tryNormalizeVideoPayload(Uint8List payload) {
    final start = _findVideoStartCode(payload);
    if (start < 0) return null;
    if (payload[start] == 0 &&
        payload[start + 1] == 0 &&
        payload[start + 2] == 1) {
      final out = Uint8List(payload.length - start + 1);
      out[0] = 0;
      out.setRange(1, out.length, payload, start);
      return out;
    }
    return Uint8List.fromList(payload.sublist(start));
  }

  int _findVideoStartCode(Uint8List payload) {
    final limit = math.min(payload.length - 4, 128);
    for (var i = 0; i <= limit; i++) {
      if (payload[i] == 0 &&
          payload[i + 1] == 0 &&
          payload[i + 2] == 0 &&
          payload[i + 3] == 1) {
        if (_isLikelyNalHeader(payload, i + 4)) return i;
      }
      if (payload[i] == 0 && payload[i + 1] == 0 && payload[i + 2] == 1) {
        if (_isLikelyNalHeader(payload, i + 3)) return i;
      }
    }
    return -1;
  }

  bool _isLikelyNalHeader(Uint8List payload, int index) {
    if (index >= payload.length) return false;
    final nalHeader = payload[index];
    final h264Type = nalHeader & 0x1F;
    if (h264Type > 0 && h264Type < 24) return true;
    final h265Type = (nalHeader >> 1) & 0x3F;
    return h265Type > 0 && h265Type < 48;
  }

  int _scoreVideoPayload(Uint8List payload) {
    var score = 0;
    var nalCount = 0;
    var parameterSetCount = 0;
    var idrCount = 0;
    var i = 0;
    while (i < payload.length - 4 && nalCount < 12) {
      final sc = _findNextStartCode(payload, i);
      if (sc < 0) break;
      final scLen = payload[sc + 2] == 1 ? 3 : 4;
      final nalStart = sc + scLen;
      if (!_isLikelyNalHeader(payload, nalStart)) {
        i = sc + 1;
        score -= 20;
        continue;
      }
      nalCount++;
      final nalHeader = payload[nalStart];
      final h264Type = nalHeader & 0x1F;
      final h265Type = (nalHeader >> 1) & 0x3F;
      if (h264Type == 7 ||
          h264Type == 8 ||
          h265Type == 32 ||
          h265Type == 33 ||
          h265Type == 34) {
        parameterSetCount++;
        score += 50;
      }
      if (h264Type == 5 || h265Type == 19 || h265Type == 20) {
        idrCount++;
        score += 30;
      }
      score += 10;
      i = nalStart + 1;
    }
    if (nalCount == 0) return -0x7fffffff;
    score += nalCount * 5;
    score += parameterSetCount * 40;
    score += idrCount * 20;
    return score;
  }

  int _findNextStartCode(Uint8List payload, int from) {
    for (var i = from; i + 3 < payload.length; i++) {
      if (payload[i] == 0 && payload[i + 1] == 0) {
        if (payload[i + 2] == 1) return i;
        if (payload[i + 2] == 0 && payload[i + 3] == 1) return i;
      }
    }
    return -1;
  }

  V380VideoCodec _detectVideoCodec(Uint8List payload) {
    if (payload.length < 5) return V380VideoCodec.unknown;
    final offset = payload[2] == 1 ? 3 : 4;
    if (payload.length <= offset) return V380VideoCodec.unknown;
    final nalHeader = payload[offset];
    final h264Type = nalHeader & 0x1F;
    if (h264Type == 1 || h264Type == 5) return V380VideoCodec.h264;
    final h265Type = (nalHeader >> 1) & 0x3F;
    if (h265Type > 0 && h265Type < 48) return V380VideoCodec.h265;
    if (h264Type > 0 && h264Type < 24) return V380VideoCodec.h264;
    return V380VideoCodec.unknown;
  }

  // ── Crypto ─────────────────────────────────────────────────────────
  void _decryptVideoFrame(Uint8List data, int length) {
    final cipher = _decryptCipher;
    if (cipher == null) return;
    var offset = 0;
    while (offset + 64 <= length) {
      for (var i = 0; i < 4; i++) {
        cipher.processInPlace(data, offset + i * 16, 16);
      }
      offset += 80;
    }
  }

  void _decryptAudioFrame(Uint8List data, int length) {
    final cipher = _decryptCipher;
    if (cipher == null) return;
    final alignedSize = (length ~/ 16) * 16;
    if (alignedSize == 0) return;
    cipher.processInPlace(data, 0, alignedSize);
  }

  void _generateMediaKey(int ticket) {
    final key = Uint8List(16);
    v380WriteU32(key, 0, ticket);
    ByteData.sublistView(key).setUint64(4, 0x618123462c14795c, Endian.little);
    v380WriteU32(key, 12, 0x82800df0);
    _decryptCipher = _V380AesEcb(key, encrypt: false);
  }

  Uint8List _generatePassword(String pw) {
    final sk = Uint8List.fromList(ascii.encode('macrovideo+*#!^@'));
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rng = math.Random();
    final rk = Uint8List.fromList(
      List<int>.generate(
        16,
        (_) => chars.codeUnitAt(rng.nextInt(chars.length)),
      ),
    );

    final pb = ascii.encode(pw);
    final pad = Uint8List(48);
    pad.setRange(0, math.min(pb.length, 48), pb);

    var encrypted = _aesEcbEncryptBlocks(sk, pad);
    encrypted = _aesEcbEncryptBlocks(rk, encrypted);

    final out = Uint8List(64);
    out.setRange(0, 16, rk);
    out.setRange(16, 64, encrypted);
    return out;
  }

  Uint8List _aesEcbEncryptBlocks(Uint8List key, Uint8List data) {
    final cipher = _V380AesEcb(key, encrypt: true);
    final out = Uint8List.fromList(data);
    cipher.processInPlace(out, 0, out.length);
    return out;
  }

  Future<void> _closeStreamSocket() async {
    try {
      await _streamReader?.close();
    } catch (_) {}
    try {
      _streamSocket?.destroy();
    } catch (_) {}
    _streamReader = null;
    _streamSocket = null;
  }
}

Uint8List _concatFragments(List<Uint8List> parts) {
  var total = 0;
  for (final part in parts) {
    total += part.length;
  }
  final out = Uint8List(total);
  var offset = 0;
  for (final part in parts) {
    out.setRange(offset, offset + part.length, part);
    offset += part.length;
  }
  return out;
}

/// Minimal in-place AES-ECB (no padding) helper backed by pointycastle,
/// matching the block-at-a-time semantics of the C# reference's
/// `ICryptoTransform.TransformBlock` calls.
class _V380AesEcb {
  _V380AesEcb(Uint8List key, {required bool encrypt})
    : _cipher = pc.ECBBlockCipher(pc.AESEngine())
        ..init(encrypt, pc.KeyParameter(key));

  final pc.ECBBlockCipher _cipher;

  void processInPlace(Uint8List data, int offset, int length) {
    var pos = offset;
    final end = offset + length;
    while (pos + 16 <= end) {
      _cipher.processBlock(data, pos, data, pos);
      pos += 16;
    }
  }
}

/// Buffers bytes from a [Socket] so the protocol client can await "N bytes"
/// the way the blocking C# `NetworkStream` reads do, without blocking Dart's
/// event loop. `dart:io` sockets are already async/event-driven, so this
/// needs no dedicated isolate or thread.
class _SocketReader {
  _SocketReader(Socket socket) {
    _subscription = socket.listen(
      (chunk) {
        _buffer.addAll(chunk);
        _wake();
      },
      onDone: () {
        _closed = true;
        _wake();
      },
      onError: (Object error) {
        _error = error;
        _wake();
      },
      cancelOnError: false,
    );
  }

  late final StreamSubscription<Uint8List> _subscription;
  final List<int> _buffer = <int>[];
  bool _closed = false;
  Object? _error;
  Completer<void>? _waiter;

  bool get isClosed => _closed;
  Object? get lastError => _error;
  int get bufferedByteCount => _buffer.length;

  void _wake() {
    final waiter = _waiter;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  Future<void> _waitForData(Duration timeout) async {
    final completer = Completer<void>();
    _waiter = completer;
    await completer.future.timeout(timeout, onTimeout: () {});
  }

  /// Waits until at least [n] bytes are buffered, then returns exactly [n].
  /// Returns null if the socket closes/errors or [timeout] elapses first.
  Future<Uint8List?> readExact(int n, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (_buffer.length < n) {
      if (_error != null) return null;
      if (_closed) return null;
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) return null;
      await _waitForData(remaining);
    }
    final result = Uint8List.fromList(_buffer.sublist(0, n));
    _buffer.removeRange(0, n);
    return result;
  }

  /// Tolerant read for short protocol replies: waits for at least [n] bytes
  /// but returns whatever has arrived if the socket closes/errors or
  /// [timeout] elapses first (mirrors the C# reference's `ReceiveData`).
  Future<Uint8List> readAtLeast(int n, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (_buffer.length < n) {
      if (_closed || _error != null) break;
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;
      await _waitForData(remaining);
    }
    final take = _buffer.length;
    final result = Uint8List.fromList(_buffer.sublist(0, take));
    _buffer.removeRange(0, take);
    return result;
  }

  Future<void> close() => _subscription.cancel();
}
