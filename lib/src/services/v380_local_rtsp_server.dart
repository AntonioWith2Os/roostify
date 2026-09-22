part of '../../main.dart';

/// A tiny loopback-only RTSP server serving exactly one camera stream, so
/// `FijkPlayer` can play `rtsp://127.0.0.1:<port>/...` for a V380 camera
/// decoded entirely on-device. Dart port of the single-stream shape in
/// `cs_tmp/V380Decoder/src/RtspServer.cs` + `RtspSession.cs` (the standalone
/// decoder's version - this app never needs the VPS backend's multi-tenant,
/// many-cameras-per-server variant, since each camera here gets its own
/// server instance on its own ephemeral port).
class V380LocalRtspServer {
  V380LocalRtspServer({required this.streamPath});

  final String streamPath;

  ServerSocket? _listener;
  final List<_V380RtspSession> _sessions = [];
  int _nextId = 0;

  Uint8List? _h264Sps;
  Uint8List? _h264Pps;
  Uint8List? _h265Vps;
  Uint8List? _h265Sps;
  Uint8List? _h265Pps;
  bool _isH265 = false;

  int get port => _listener?.port ?? 0;

  Future<void> start() async {
    final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _listener = listener;
    listener.listen((socket) {
      socket.setOption(SocketOption.tcpNoDelay, true);
      final session = _V380RtspSession(
        id: _nextId++,
        socket: socket,
        server: this,
      );
      _sessions.add(session);
      session.onClose = () => _sessions.remove(session);
      session.start();
    });
  }

  void pushVideo(V380Frame frame) {
    _observe(frame);
    for (final session in List<_V380RtspSession>.of(_sessions)) {
      session.pushVideo(frame);
    }
  }

  void pushAudio(V380Frame frame) {
    for (final session in List<_V380RtspSession>.of(_sessions)) {
      session.pushAudio(frame);
    }
  }

  void _observe(V380Frame frame) {
    if (frame.codec == V380VideoCodec.h265) {
      _isH265 = true;
      if (_h265Vps == null || _h265Sps == null || _h265Pps == null) {
        _parseNals(
          frame.payload,
          h265: true,
          callback: (type, nal) {
            if (type == 32) {
              _h265Vps ??= nal;
            } else if (type == 33) {
              _h265Sps ??= nal;
            } else if (type == 34) {
              _h265Pps ??= nal;
            }
          },
        );
      }
    } else if (frame.isKeyframe && (_h264Sps == null || _h264Pps == null)) {
      _parseNals(
        frame.payload,
        h265: false,
        callback: (type, nal) {
          if (type == 7) {
            _h264Sps ??= nal;
          } else if (type == 8) {
            _h264Pps ??= nal;
          }
        },
      );
    }
  }

  String buildSdp() {
    if (_isH265) {
      final vps = _h265Vps, sps = _h265Sps, pps = _h265Pps;
      final fmtp = (vps != null && sps != null && pps != null)
          ? 'a=fmtp:96 sprop-vps=${base64Encode(vps)};sprop-sps=${base64Encode(sps)};sprop-pps=${base64Encode(pps)}\r\n'
          : '';
      return _commonSdp('H265', fmtp);
    }

    var fmtp = '';
    final sps = _h264Sps, pps = _h264Pps;
    if (sps != null && pps != null) {
      final profile = sps.length >= 4
          ? sps
                .sublist(1, 4)
                .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
                .join()
          : '64001F';
      fmtp =
          'a=fmtp:96 packetization-mode=1;sprop-parameter-sets=${base64Encode(sps)},${base64Encode(pps)};profile-level-id=$profile\r\n';
    }
    return _commonSdp('H264', fmtp);
  }

  String _commonSdp(String codec, String fmtp) =>
      'v=0\r\n'
      'o=- 1 1 IN IP4 0.0.0.0\r\n'
      's=V380 Live\r\n'
      't=0 0\r\n'
      'a=recvonly\r\n'
      'm=video 0 RTP/AVP 96\r\n'
      'a=rtpmap:96 $codec/90000\r\n'
      '$fmtp'
      'a=control:trackID=0\r\n'
      'm=audio 0 RTP/AVP 8\r\n'
      'a=rtpmap:8 PCMA/8000/1\r\n'
      'a=control:trackID=1\r\n';

  Future<void> stop() async {
    for (final session in List<_V380RtspSession>.of(_sessions)) {
      session.close();
    }
    _sessions.clear();
    await _listener?.close();
    _listener = null;
  }

  static void _parseNals(
    Uint8List data, {
    required bool h265,
    required void Function(int type, Uint8List nal) callback,
  }) {
    var offset = 0;
    while (offset < data.length) {
      final start = _findStartCode(data, offset);
      if (start < 0) break;
      final startCodeLength = (start + 2 < data.length && data[start + 2] == 1)
          ? 3
          : 4;
      final nalStart = start + startCodeLength;
      if (nalStart >= data.length) break;
      final next = _findStartCode(data, nalStart);
      final nalEnd = next < 0 ? data.length : next;
      final minLen = h265 ? 2 : 1;
      if (nalStart + minLen <= nalEnd) {
        final nal = Uint8List.fromList(data.sublist(nalStart, nalEnd));
        final type = h265 ? (nal[0] >> 1) & 0x3f : nal[0] & 0x1f;
        callback(type, nal);
      }
      offset = nalEnd;
    }
  }

  static int _findStartCode(Uint8List data, int from) {
    for (var i = from; i + 3 < data.length; i++) {
      if (data[i] == 0 && data[i + 1] == 0) {
        if (data[i + 2] == 1) return i;
        if (data[i + 2] == 0 && data[i + 3] == 1) return i;
      }
    }
    return -1;
  }
}

class _V380RtspSession {
  _V380RtspSession({
    required this.id,
    required this.socket,
    required this.server,
  });

  final int id;
  final Socket socket;
  final V380LocalRtspServer server;
  VoidCallback? onClose;

  StreamSubscription<Uint8List>? _sub;
  bool _alive = true;
  bool _playing = false;
  String _buffer = '';

  int _videoCh = 0;
  int _audioCh = 2;
  int _videoSeq = 0;
  int _audioSeq = 0;
  late final int _videoSsrc = math.Random().nextInt(0xFFFFFFFF);
  late final int _audioSsrc = math.Random().nextInt(0xFFFFFFFF);
  int _videoStartMicros = 0;
  int _audioRtsClock = 0;

  void start() {
    _sub = socket.listen(
      _onData,
      onDone: close,
      onError: (_) => close(),
      cancelOnError: false,
    );
  }

  void _onData(Uint8List chunk) {
    _buffer += ascii.decode(chunk, allowInvalid: true);
    var end = _buffer.indexOf('\r\n\r\n');
    while (end >= 0) {
      final req = _buffer.substring(0, end + 4);
      _buffer = _buffer.substring(end + 4);
      _handleRequest(req);
      end = _buffer.indexOf('\r\n\r\n');
    }
  }

  void _handleRequest(String req) {
    final lines = req.split('\r\n');
    if (lines.isEmpty) return;
    final firstLine = lines[0].split(' ');
    final method = firstLine.isNotEmpty ? firstLine[0] : '';
    final url = firstLine.length > 1 ? firstLine[1] : '';
    final cseqLine = lines.firstWhere(
      (l) => l.toLowerCase().startsWith('cseq:'),
      orElse: () => 'CSeq: 0',
    );
    final cseqParts = cseqLine.split(':');
    final cseq = cseqParts.length > 1
        ? cseqParts.sublist(1).join(':').trim()
        : '0';
    final transportLine = lines.firstWhere(
      (l) => l.toLowerCase().startsWith('transport:'),
      orElse: () => '',
    );

    switch (method) {
      case 'OPTIONS':
        _reply(cseq, ['Public: OPTIONS,DESCRIBE,SETUP,PLAY,TEARDOWN']);
        break;
      case 'DESCRIBE':
        final sdp = server.buildSdp();
        final body = ascii.encode(sdp);
        _send(
          'RTSP/1.0 200 OK\r\nCSeq: $cseq\r\nContent-Type: application/sdp\r\nContent-Length: ${body.length}\r\n\r\n$sdp',
        );
        break;
      case 'SETUP':
        final isAudio = url.contains('trackID=1');
        var ch = isAudio ? 2 : 0;
        final match = RegExp(
          r'interleaved=(\d+)-(\d+)',
        ).firstMatch(transportLine);
        if (match != null) ch = int.parse(match.group(1)!);
        if (isAudio) {
          _audioCh = ch;
        } else {
          _videoCh = ch;
        }
        _reply(cseq, [
          'Transport: RTP/AVP/TCP;unicast;interleaved=$ch-${ch + 1}',
          'Session: 1',
        ]);
        break;
      case 'PLAY':
        _reply(cseq, [
          'Session: 1',
          'RTP-Info: url=$url/trackID=0;seq=$_videoSeq,url=$url/trackID=1;seq=$_audioSeq',
        ]);
        _playing = true;
        break;
      case 'TEARDOWN':
        _reply(cseq, ['Session: 1']);
        close();
        break;
      default:
        _send('RTSP/1.0 501 Not Implemented\r\nCSeq: $cseq\r\n\r\n');
    }
  }

  void _reply(String cseq, List<String> headers) {
    final sb = StringBuffer('RTSP/1.0 200 OK\r\nCSeq: $cseq\r\n');
    for (final header in headers) {
      sb.write('$header\r\n');
    }
    sb.write('\r\n');
    _send(sb.toString());
  }

  void _send(String text) {
    if (!_alive) return;
    try {
      socket.add(ascii.encode(text));
    } catch (_) {
      _alive = false;
    }
  }

  void pushVideo(V380Frame frame) {
    if (!_playing || !_alive) return;

    // Real elapsed wall-clock time since PLAY, not the camera's raw device
    // timestamp (arbitrary origin -> non-monotonic RTP timestamps that
    // make players reject the stream). Matches the fix already applied on
    // the VPS backend's RtspSession.
    if (_videoStartMicros == 0)
      _videoStartMicros = DateTime.now().microsecondsSinceEpoch;
    final elapsedMs =
        (DateTime.now().microsecondsSinceEpoch - _videoStartMicros) / 1000.0;
    final rts = (elapsedMs * 90).round().toUnsigned(32);

    if (frame.codec == V380VideoCodec.h265) {
      _pushVideoH265(frame.payload, rts);
      return;
    }

    V380LocalRtspServer._parseNals(
      frame.payload,
      h265: false,
      callback: (nalType, nal) {
        const mtu = 1400;
        final isLastNalOfAccessUnit = nalType == 1 || nalType == 5;
        if (nal.length <= mtu) {
          _sendRtp(
            _videoCh,
            96,
            _videoSeq++,
            rts,
            _videoSsrc,
            nal,
            0,
            nal.length,
            marker: isLastNalOfAccessUnit,
          );
          return;
        }
        _sendH264Fragmented(nal, rts, mtu, isLastNalOfAccessUnit);
      },
    );
  }

  void _sendH264Fragmented(
    Uint8List nal,
    int rts,
    int mtu,
    bool isLastNalOfAccessUnit,
  ) {
    final nalHdr = nal[0];
    final fuInd = (nalHdr & 0xE0) | 28;
    var offset = 1;
    var first = true;
    while (offset < nal.length) {
      final chunk = math.min(mtu - 2, nal.length - offset);
      final last = offset + chunk >= nal.length;
      var fuHdr = nalHdr & 0x1F;
      if (first) fuHdr |= 0x80;
      if (last) fuHdr |= 0x40;

      final frag = Uint8List(2 + chunk);
      frag[0] = fuInd;
      frag[1] = fuHdr;
      frag.setRange(2, 2 + chunk, nal, offset);

      _sendRtp(
        _videoCh,
        96,
        _videoSeq++,
        rts,
        _videoSsrc,
        frag,
        0,
        frag.length,
        marker: last && isLastNalOfAccessUnit,
      );
      offset += chunk;
      first = false;
    }
  }

  void _pushVideoH265(Uint8List data, int rts) {
    V380LocalRtspServer._parseNals(
      data,
      h265: true,
      callback: (nalType, nal) {
        const mtu = 1400;
        if (nalType >= 32) {
          if (nal.length <= mtu) {
            _sendRtp(
              _videoCh,
              96,
              _videoSeq++,
              rts,
              _videoSsrc,
              nal,
              0,
              nal.length,
              marker: false,
            );
          }
          return;
        }

        if (nal.length <= mtu) {
          _sendRtp(
            _videoCh,
            96,
            _videoSeq++,
            rts,
            _videoSsrc,
            nal,
            0,
            nal.length,
            marker: true,
          );
          return;
        }

        final nalHdr1 = nal.length > 1 ? nal[1] : 0;
        final fuIndicator = (nal[0] & 0x81) | (49 << 1);
        var offset = 2;
        var first = true;
        while (offset < nal.length) {
          final chunk = math.min(mtu - 3, nal.length - offset);
          final last = offset + chunk >= nal.length;
          var fuHdr = nalType & 0x3F;
          if (first) fuHdr |= 0x80;
          if (last) fuHdr |= 0x40;

          final frag = Uint8List(3 + chunk);
          frag[0] = fuIndicator;
          frag[1] = nalHdr1;
          frag[2] = fuHdr;
          frag.setRange(3, 3 + chunk, nal, offset);

          _sendRtp(
            _videoCh,
            96,
            _videoSeq++,
            rts,
            _videoSsrc,
            frag,
            0,
            frag.length,
            marker: last,
          );
          offset += chunk;
          first = false;
        }
      },
    );
  }

  void pushAudio(V380Frame frame) {
    if (!_playing || !_alive) return;
    const chunkSize = 160;
    var off = 0;
    while (off < frame.payload.length) {
      final len = math.min(chunkSize, frame.payload.length - off);
      _sendRtp(
        _audioCh,
        8,
        _audioSeq++,
        _audioRtsClock,
        _audioSsrc,
        frame.payload,
        off,
        len,
        marker: false,
      );
      _audioRtsClock = (_audioRtsClock + len).toUnsigned(32);
      off += len;
    }
  }

  void _sendRtp(
    int channel,
    int pt,
    int seq,
    int ts,
    int ssrc,
    Uint8List payload,
    int offset,
    int length, {
    required bool marker,
  }) {
    final rtp = Uint8List(12 + length);
    rtp[0] = 0x80;
    rtp[1] = (marker ? 0x80 : 0) | (pt & 0x7F);
    rtp[2] = (seq >> 8) & 0xFF;
    rtp[3] = seq & 0xFF;
    ByteData.sublistView(rtp).setUint32(4, ts, Endian.big);
    ByteData.sublistView(rtp).setUint32(8, ssrc, Endian.big);
    rtp.setRange(12, 12 + length, payload, offset);

    final frame = Uint8List(4 + rtp.length);
    frame[0] = 0x24; // '$'
    frame[1] = channel;
    frame[2] = (rtp.length >> 8) & 0xFF;
    frame[3] = rtp.length & 0xFF;
    frame.setRange(4, 4 + rtp.length, rtp);

    if (!_alive) return;
    try {
      socket.add(frame);
    } catch (_) {
      _alive = false;
    }
  }

  void close() {
    if (!_alive) return;
    _alive = false;
    _playing = false;
    try {
      socket.destroy();
    } catch (_) {}
    unawaited(_sub?.cancel());
    _sub = null;
    onClose?.call();
  }
}
