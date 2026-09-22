import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:coolapp/main.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises [V380LocalRtspServer] end-to-end over a real loopback TCP
/// socket, standing in for a player like FijkPlayer/ffmpeg - there's no V380
/// hardware available in this environment, but the RTSP/RTP framing this
/// class hand-implements (OPTIONS/DESCRIBE/SETUP/PLAY, interleaved RTP) is
/// fully exercisable without a real camera on the other end.
void main() {
  test('serves a minimal RTSP session and RTP-packetizes a pushed frame', () async {
    final server = V380LocalRtspServer(streamPath: '/camera/12345678');
    await server.start();
    addTearDown(server.stop);

    final socket = await Socket.connect(InternetAddress.loopbackIPv4, server.port);
    addTearDown(() => socket.destroy());

    final replies = StreamController<String>.broadcast();
    final rawChunks = <Uint8List>[];
    socket.listen((chunk) {
      rawChunks.add(chunk);
      // RTP-interleaved frames start with '$' (0x24) and aren't valid ASCII
      // text - route only plain RTSP replies into the text stream.
      if (chunk.isNotEmpty && chunk[0] != 0x24) {
        replies.add(String.fromCharCodes(chunk));
      }
    });

    Future<String> nextReply() => replies.stream.first.timeout(const Duration(seconds: 5));

    socket.write('OPTIONS rtsp://127.0.0.1/camera/12345678 RTSP/1.0\r\nCSeq: 1\r\n\r\n');
    var reply = await nextReply();
    expect(reply, contains('RTSP/1.0 200 OK'));
    expect(reply, contains('Public:'));
    expect(reply, contains('DESCRIBE'));

    socket.write('DESCRIBE rtsp://127.0.0.1/camera/12345678 RTSP/1.0\r\nCSeq: 2\r\n\r\n');
    reply = await nextReply();
    expect(reply, contains('RTSP/1.0 200 OK'));
    expect(reply, contains('Content-Type: application/sdp'));
    expect(reply, contains('m=video 0 RTP/AVP 96'));
    expect(reply, contains('m=audio 0 RTP/AVP 8'));
    expect(reply, contains('a=rtpmap:96 H264/90000'));

    socket.write(
      'SETUP rtsp://127.0.0.1/camera/12345678/trackID=0 RTSP/1.0\r\n'
      'CSeq: 3\r\nTransport: RTP/AVP/TCP;unicast;interleaved=0-1\r\n\r\n',
    );
    reply = await nextReply();
    expect(reply, contains('RTSP/1.0 200 OK'));
    expect(reply, contains('Transport: RTP/AVP/TCP;unicast;interleaved=0-1'));
    expect(reply, contains('Session: 1'));

    socket.write('PLAY rtsp://127.0.0.1/camera/12345678 RTSP/1.0\r\nCSeq: 4\r\n\r\n');
    reply = await nextReply();
    expect(reply, contains('RTSP/1.0 200 OK'));
    expect(reply, contains('RTP-Info:'));

    // A synthetic Annex-B H.264 IDR NAL (start code + NAL header 0x65).
    final payload = Uint8List.fromList([0, 0, 0, 1, 0x65, 1, 2, 3, 4]);
    rawChunks.clear();
    server.pushVideo(
      V380Frame(isVideo: true, codec: V380VideoCodec.h264, payload: payload, timestamp: 0),
    );

    // Wait for the interleaved RTP frame to arrive on the raw socket.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (rawChunks.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(rawChunks, isNotEmpty);
    final rtpFrame = rawChunks.first;
    // '$' + channel 0 (video) + 2-byte big-endian length prefix.
    expect(rtpFrame[0], 0x24);
    expect(rtpFrame[1], 0);
    final rtpLength = (rtpFrame[2] << 8) | rtpFrame[3];
    expect(rtpFrame.length, 4 + rtpLength);
    // RTP header: version 2 (0x80) and payload type 96 (dynamic H.264).
    expect(rtpFrame[4], 0x80);
    expect(rtpFrame[5] & 0x7F, 96);

    socket.write('TEARDOWN rtsp://127.0.0.1/camera/12345678 RTSP/1.0\r\nCSeq: 5\r\n\r\n');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await replies.close();
  });
}
