part of '../../main.dart';

class CameraScanProgress {
  const CameraScanProgress({
    required this.currentTarget,
    required this.completedTargets,
    required this.totalTargets,
  });

  final String currentTarget;
  final int completedTargets;
  final int totalTargets;

  double get value => totalTargets == 0 ? 0 : completedTargets / totalTargets;

  String get label {
    if (totalTargets == 0) {
      return 'Preparing local network scan...';
    }

    return 'Scanning $currentTarget ($completedTargets of $totalTargets)';
  }
}

class RtspCameraCandidate {
  const RtspCameraCandidate({
    required this.host,
    required this.port,
    required this.streamUrl,
    required this.status,
    required this.verified,
    required this.requiresCredentials,
  });

  final String host;
  final int port;
  final String streamUrl;
  final String status;
  final bool verified;
  final bool requiresCredentials;

  String get endpoint => '$host:$port';
}

class RtspCameraScanner {
  static const _ports = [554, 8554, 10554, 5544];
  static const _parallelChecks = 32;
  static const _connectTimeout = Duration(milliseconds: 550);
  static const _responseTimeout = Duration(milliseconds: 950);
  static const _commonStreamPaths = [
    '/live/ch00_1',
    '/live/ch00_0',
    '/11',
    '/video.h264',
    '/h264_stream',
    '/onvif1',
    '/1/cif',
    '/',
    '/live',
    '/Streaming/Channels/101',
    '/Streaming/Channels/102',
    '/h264Preview_01_main',
    '/h264Preview_01_sub',
    '/cam/realmonitor?channel=1&subtype=0',
    '/cam/realmonitor?channel=1&subtype=1',
    '/videoMain',
    '/videoSub',
    '/video1',
    '/onvif2',
    '/media/video1',
  ];

  bool _cancelled = false;

  bool get cancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }

  Future<List<RtspCameraCandidate>> scan({
    required void Function(CameraScanProgress progress) onProgress,
    String username = '',
    String password = '',
    String preferredPath = '',
  }) async {
    final subnetPrefixes = await _localSubnetPrefixes();
    if (_cancelled || subnetPrefixes.isEmpty) {
      return const [];
    }

    final targets = <_RtspScanTarget>[
      for (final prefix in subnetPrefixes)
        for (var hostSuffix = 1; hostSuffix <= 254; hostSuffix++)
          for (final port in _ports)
            _RtspScanTarget(host: '$prefix.$hostSuffix', port: port),
    ];

    final candidates = <RtspCameraCandidate>[];
    var completedTargets = 0;

    for (
      var start = 0;
      start < targets.length && !_cancelled;
      start += _parallelChecks
    ) {
      final batch = targets.skip(start).take(_parallelChecks).toList();
      final batchResults = await Future.wait(
        batch.map((target) async {
          if (_cancelled) {
            return null;
          }

          final candidate = await _probeTarget(
            target,
            username: username,
            password: password,
            preferredPath: preferredPath,
          );
          completedTargets += 1;
          onProgress(
            CameraScanProgress(
              currentTarget: target.label,
              completedTargets: completedTargets,
              totalTargets: targets.length,
            ),
          );
          return candidate;
        }),
      );

      candidates.addAll(batchResults.whereType<RtspCameraCandidate>());
    }

    final deduped = <String, RtspCameraCandidate>{};
    for (final candidate in candidates) {
      deduped.putIfAbsent(candidate.streamUrl, () => candidate);
    }

    return deduped.values.toList()..sort((a, b) {
      if (a.verified != b.verified) {
        return a.verified ? -1 : 1;
      }
      if (a.requiresCredentials != b.requiresCredentials) {
        return a.requiresCredentials ? 1 : -1;
      }
      return a.endpoint.compareTo(b.endpoint);
    });
  }

  Future<RtspCameraCandidate?> _probeTarget(
    _RtspScanTarget target, {
    required String username,
    required String password,
    required String preferredPath,
  }) async {
    try {
      final candidatePaths = _candidateRtspPaths(preferredPath);
      final rootUri = Uri.parse(
        _buildRtspUrl(
          host: target.host,
          port: target.port,
          path: '/',
          username: username,
          password: password,
        ),
      );

      final optionsResponse = await _sendRtspProbeRequest(
        rootUri,
        method: 'OPTIONS',
        cSeq: 1,
        connectTimeout: _connectTimeout,
        responseTimeout: _responseTimeout,
      );

      if (!optionsResponse.isRtspResponse) {
        return _probeRtspStreamPaths(
          target,
          candidatePaths,
          username: username,
          password: password,
          cSeqStart: 2,
          includeFallback: false,
        );
      }

      if (optionsResponse.statusCode == 401) {
        final streamUrl = _buildRtspUrl(
          host: target.host,
          port: target.port,
          path: candidatePaths.first,
          username: username,
          password: password,
        );

        return RtspCameraCandidate(
          host: target.host,
          port: target.port,
          streamUrl: streamUrl,
          status:
              'RTSP camera found, but it needs login before the app can verify the stream path.',
          verified: false,
          requiresCredentials: true,
        );
      }

      return await _probeRtspStreamPaths(
            target,
            candidatePaths,
            username: username,
            password: password,
            cSeqStart: 2,
          ) ??
          _unverifiedRtspCandidate(
            target,
            candidatePaths.first,
            username: username,
            password: password,
          );
    } on SocketException {
      return null;
    } on TimeoutException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<RtspCameraCandidate?> _probeRtspStreamPaths(
    _RtspScanTarget target,
    List<String> candidatePaths, {
    required String username,
    required String password,
    required int cSeqStart,
    bool includeFallback = true,
  }) async {
    RtspCameraCandidate? fallbackCandidate;

    for (var index = 0; index < candidatePaths.length && !_cancelled; index++) {
      final path = candidatePaths[index];
      final streamUrl = _buildRtspUrl(
        host: target.host,
        port: target.port,
        path: path,
        username: username,
        password: password,
      );
      final uri = Uri.parse(streamUrl);
      final _RtspProbeResponse describeResponse;
      try {
        describeResponse = await _sendRtspProbeRequest(
          uri,
          method: 'DESCRIBE',
          cSeq: cSeqStart + index,
          includeSdpAccept: true,
          connectTimeout: _connectTimeout,
          responseTimeout: _responseTimeout,
        );
      } on SocketException {
        continue;
      } on TimeoutException {
        continue;
      }

      if (describeResponse.statusCode == 200) {
        return RtspCameraCandidate(
          host: target.host,
          port: target.port,
          streamUrl: streamUrl,
          status: 'Verified RTSP stream path.',
          verified: true,
          requiresCredentials: false,
        );
      }

      if (describeResponse.statusCode == 401) {
        return RtspCameraCandidate(
          host: target.host,
          port: target.port,
          streamUrl: streamUrl,
          status:
              'Camera answered RTSP but requires credentials for this path.',
          verified: false,
          requiresCredentials: true,
        );
      }

      if (includeFallback &&
          fallbackCandidate == null &&
          describeResponse.isRtspResponse &&
          describeResponse.statusCode != 404) {
        fallbackCandidate = RtspCameraCandidate(
          host: target.host,
          port: target.port,
          streamUrl: streamUrl,
          status:
              'RTSP camera found; the app may need a different stream path.',
          verified: false,
          requiresCredentials: false,
        );
      }
    }

    return fallbackCandidate;
  }

  RtspCameraCandidate _unverifiedRtspCandidate(
    _RtspScanTarget target,
    String path, {
    required String username,
    required String password,
  }) {
    return RtspCameraCandidate(
      host: target.host,
      port: target.port,
      streamUrl: _buildRtspUrl(
        host: target.host,
        port: target.port,
        path: path,
        username: username,
        password: password,
      ),
      status: 'RTSP camera found; choose it or adjust the stream path.',
      verified: false,
      requiresCredentials: false,
    );
  }

  List<String> _candidateRtspPaths(String preferredPath) {
    final paths = <String>{};
    final cleanPreferredPath = _normalizeRtspPath(preferredPath);
    if (cleanPreferredPath != '/') {
      paths.add(cleanPreferredPath);
    }
    paths.addAll(_commonStreamPaths);
    return paths.toList();
  }

  Future<List<String>> _localSubnetPrefixes() async {
    if (kIsWeb) {
      return const [];
    }

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      final prefixes = <String>{};

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final prefix = _subnetPrefix(address.address);
          if (prefix != null) {
            prefixes.add(prefix);
          }
        }
      }

      return prefixes.toList()..sort();
    } on SocketException {
      return const [];
    } on UnsupportedError {
      return const [];
    }
  }

  String? _subnetPrefix(String address) {
    final parts = address.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) {
      return null;
    }

    final first = parts[0]!;
    final second = parts[1]!;
    final privateNetwork =
        first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168) ||
        (first == 169 && second == 254);

    if (!privateNetwork) {
      return null;
    }

    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }
}

class _RtspScanTarget {
  const _RtspScanTarget({required this.host, required this.port});

  final String host;
  final int port;

  String get label => '$host:$port';
}
