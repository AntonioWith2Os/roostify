part of '../../main.dart';

/// Video codec carried by a [V380Frame], mirrors the C# decoder's
/// `VideoCodec` enum (`cs_tmp/V380Decoder/src/FrameData.cs`).
enum V380VideoCodec { unknown, h264, h265 }

/// One decrypted, reassembled media frame from a V380 camera - either a
/// video access unit (Annex-B NALs) or a PCMA audio chunk. Dart port of
/// `cs_tmp/V380Decoder/src/FrameData.cs`.
class V380Frame {
  V380Frame({
    required this.isVideo,
    required this.codec,
    required this.payload,
    this.timestamp = 0,
  });

  final bool isVideo;
  final V380VideoCodec codec;
  final Uint8List payload;
  final int timestamp;

  bool get isKeyframe {
    if (!isVideo) return false;
    if (payload.length < 5) return false;
    final offset = payload[2] == 1 ? 3 : 4;
    if (payload.length <= offset) return false;
    final nalHeader = payload[offset];
    return switch (codec) {
      V380VideoCodec.h264 => (nalHeader & 0x1F) == 5,
      V380VideoCodec.h265 =>
        ((nalHeader >> 1) & 0x3F) == 19 || ((nalHeader >> 1) & 0x3F) == 20,
      V380VideoCodec.unknown => false,
    };
  }
}

/// Camera connection lifecycle, mirrors `V380ConnectionState` in
/// `cs_tmp/v380connectorbackend/src/CameraContracts.cs`.
enum V380ConnectionState {
  connecting,
  online,
  reconnecting,
  authenticationFailed,
  offline,
}

/// Little-endian byte helpers shared by the protocol client and the local
/// RTSP server (kept here once since `part of` files share one namespace).
void v380WriteU32(Uint8List b, int offset, int value) =>
    ByteData.sublistView(b).setUint32(offset, value, Endian.little);

void v380WriteU16(Uint8List b, int offset, int value) =>
    ByteData.sublistView(b).setUint16(offset, value, Endian.little);

int v380ReadU32(Uint8List b, int offset) =>
    ByteData.sublistView(b).getUint32(offset, Endian.little);

int v380ReadU16(Uint8List b, int offset) =>
    ByteData.sublistView(b).getUint16(offset, Endian.little);

int v380ReadU64(Uint8List b, int offset) =>
    ByteData.sublistView(b).getUint64(offset, Endian.little);

void v380WriteAsciiPadded(
  Uint8List dest,
  int offset,
  String text,
  int maxLength,
) {
  final bytes = ascii.encode(text);
  final count = math.min(bytes.length, maxLength);
  dest.setRange(offset, offset + count, bytes);
}
