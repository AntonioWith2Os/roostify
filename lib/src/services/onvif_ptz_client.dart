part of '../../main.dart';

@immutable
class _OnvifPtzSettings {
  const _OnvifPtzSettings({
    required this.host,
    required this.username,
    required this.password,
    this.port,
  });

  final String host;
  final String username;
  final String password;
  final int? port;

  String get cacheKey => '$host|${port ?? 'auto'}|$username|$password';
}

class _OnvifPtzException implements Exception {
  const _OnvifPtzException(this.message);

  final String message;

  @override
  String toString() => message;
}

@immutable
class _OnvifPtzVector {
  const _OnvifPtzVector({this.pan = 0, this.tilt = 0, this.zoom = 0});

  final double pan;
  final double tilt;
  final double zoom;

  bool get hasPanTilt => pan != 0 || tilt != 0;
  bool get hasZoom => zoom != 0;
  bool get isEmpty => !hasPanTilt && !hasZoom;

  _OnvifPtzVector scaled(double speed) {
    final cleanSpeed = speed.clamp(0.05, 1.0).toDouble();
    return _OnvifPtzVector(
      pan: (pan * cleanSpeed).clamp(-1.0, 1.0).toDouble(),
      tilt: (tilt * cleanSpeed).clamp(-1.0, 1.0).toDouble(),
      zoom: (zoom * cleanSpeed).clamp(-1.0, 1.0).toDouble(),
    );
  }
}

class _OnvifPtzClient {
  _OnvifPtzClient(this.settings)
    : _client = HttpClient()..connectionTimeout = _connectTimeout;

  static const _connectTimeout = Duration(seconds: 3);
  static const _responseTimeout = Duration(seconds: 7);
  static const _automaticPorts = [8899, 80, 8080, 8000, 5000];
  static const _mediaPaths = ['/onvif/media_service', '/onvif/media'];
  static const _ptzPaths = ['/onvif/ptz_service', '/onvif/ptz'];
  static const _panTiltSpace =
      'http://www.onvif.org/ver10/tptz/PanTiltSpaces/VelocityGenericSpace';
  static const _zoomSpace =
      'http://www.onvif.org/ver10/tptz/ZoomSpaces/VelocityGenericSpace';

  final _OnvifPtzSettings settings;
  final HttpClient _client;
  _OnvifPtzSession? _session;

  Future<void> startContinuousMove(
    _OnvifPtzVector vector, {
    required Duration timeout,
  }) async {
    if (vector.isEmpty) {
      await stop();
      return;
    }

    await _sendPtzCommand(
      action: 'http://www.onvif.org/ver20/ptz/wsdl/ContinuousMove',
      bodyBuilder: (profileToken) {
        return _continuousMoveBody(
          profileToken: profileToken,
          vector: vector,
          timeout: timeout,
        );
      },
    );
  }

  Future<void> stop() {
    return _sendPtzCommand(
      action: 'http://www.onvif.org/ver20/ptz/wsdl/Stop',
      bodyBuilder: (profileToken) {
        return '''
<tptz:Stop>
  <tptz:ProfileToken>${_xmlEscape(profileToken)}</tptz:ProfileToken>
  <tptz:PanTilt>true</tptz:PanTilt>
  <tptz:Zoom>true</tptz:Zoom>
</tptz:Stop>''';
      },
    );
  }

  void close() {
    _client.close(force: true);
  }

  Future<void> _sendPtzCommand({
    required String action,
    required String Function(String profileToken) bodyBuilder,
  }) async {
    final session = await _resolveSession();
    final candidates = session.ptzCandidates;
    Object? lastError;

    for (final ptzUri in candidates) {
      try {
        await _postSoap(
          ptzUri,
          action: action,
          body: bodyBuilder(session.profileToken),
        );
        session.prefer(ptzUri);
        return;
      } catch (error) {
        lastError = error;
      }
    }

    throw _OnvifPtzException(
      'ONVIF PTZ command failed for ${settings.host}: ${_errorSummary(lastError)}',
    );
  }

  Future<_OnvifPtzSession> _resolveSession() async {
    final cachedSession = _session;
    if (cachedSession != null) {
      return cachedSession;
    }

    final ports = settings.port == null
        ? _automaticPorts
        : <int>[settings.port!];
    Object? lastError;

    for (final port in ports) {
      try {
        final session = await _resolveSessionOnPort(port);
        _session = session;
        return session;
      } catch (error) {
        lastError = error;
      }
    }

    throw _OnvifPtzException(
      'Could not connect to ONVIF PTZ on ${settings.host}. Enable ONVIF in V380 Pro and check the ONVIF username, password, and port. ${_errorSummary(lastError)}',
    );
  }

  Future<_OnvifPtzSession> _resolveSessionOnPort(int port) async {
    _OnvifCapabilities? capabilities;
    Object? capabilityError;

    try {
      capabilities = await _getCapabilities(
        _serviceUri(port, '/onvif/device_service'),
        port,
      );
    } catch (error) {
      capabilityError = error;
    }

    final mediaCandidates = _uniqueUris([
      capabilities?.mediaUri,
      for (final path in _mediaPaths) _serviceUri(port, path),
    ]);
    final ptzCandidates = _uniqueUris([
      capabilities?.ptzUri,
      for (final path in _ptzPaths) _serviceUri(port, path),
    ]);

    String? profileToken;
    Object? profileError;
    for (final mediaUri in mediaCandidates) {
      try {
        profileToken = await _getProfileToken(mediaUri);
        break;
      } catch (error) {
        profileError = error;
      }
    }

    if (profileToken == null) {
      throw _OnvifPtzException(
        'ONVIF media profile was not found on port $port. ${_errorSummary(profileError ?? capabilityError)}',
      );
    }

    return _OnvifPtzSession(profileToken: profileToken, ptzUris: ptzCandidates);
  }

  Future<_OnvifCapabilities> _getCapabilities(Uri deviceUri, int port) async {
    final document = await _postSoap(
      deviceUri,
      action: 'http://www.onvif.org/ver10/device/wsdl/GetCapabilities',
      body: '''
<tds:GetCapabilities>
  <tds:Category>All</tds:Category>
</tds:GetCapabilities>''',
    );

    return _OnvifCapabilities(
      mediaUri: _capabilityXAddr(document, 'Media', port),
      ptzUri: _capabilityXAddr(document, 'PTZ', port),
    );
  }

  Future<String> _getProfileToken(Uri mediaUri) async {
    final document = await _postSoap(
      mediaUri,
      action: 'http://www.onvif.org/ver10/media/wsdl/GetProfiles',
      body: '<trt:GetProfiles/>',
    );
    XmlElement? fallbackProfile;
    XmlElement? ptzProfile;

    for (final profile in _xmlElements(document, 'Profiles')) {
      fallbackProfile ??= profile;
      final hasPtzConfiguration = _xmlElements(
        profile,
        'PTZConfiguration',
      ).isNotEmpty;
      if (hasPtzConfiguration) {
        ptzProfile = profile;
        break;
      }
    }

    final profile = ptzProfile ?? fallbackProfile;
    final token = profile?.getAttribute('token');
    if (token == null || token.trim().isEmpty) {
      throw const _OnvifPtzException(
        'The ONVIF media service did not return a profile token.',
      );
    }

    return token;
  }

  Future<XmlDocument> _postSoap(
    Uri uri, {
    required String action,
    required String body,
  }) async {
    final request = await _client.postUrl(uri).timeout(_connectTimeout);
    final payload = utf8.encode(_soapEnvelope(body));

    request.headers.contentType = ContentType(
      'application',
      'soap+xml',
      charset: 'utf-8',
    );
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/soap+xml, text/xml, */*',
    );
    request.headers.set('SOAPAction', '"$action"');
    request.contentLength = payload.length;
    request.add(payload);

    final response = await request.close().timeout(_responseTimeout);
    final responseText = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_responseTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _OnvifPtzException(
        'ONVIF HTTP ${response.statusCode} from ${uri.host}:${uri.port}.',
      );
    }

    final document = XmlDocument.parse(responseText);
    final faultMessage = _soapFaultMessage(document);
    if (faultMessage != null) {
      throw _OnvifPtzException('ONVIF rejected the request: $faultMessage');
    }

    return document;
  }

  String _soapEnvelope(String body) {
    final securityHeader = _wsSecurityHeader();
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope
  xmlns:s="http://www.w3.org/2003/05/soap-envelope"
  xmlns:tds="http://www.onvif.org/ver10/device/wsdl"
  xmlns:trt="http://www.onvif.org/ver10/media/wsdl"
  xmlns:tptz="http://www.onvif.org/ver20/ptz/wsdl"
  xmlns:tt="http://www.onvif.org/ver10/schema">
  <s:Header>${securityHeader ?? ''}</s:Header>
  <s:Body>$body</s:Body>
</s:Envelope>''';
  }

  String? _wsSecurityHeader() {
    final username = settings.username.trim();
    if (username.isEmpty) {
      return null;
    }

    final created = DateTime.now().toUtc().toIso8601String();
    final nonceBytes = List<int>.generate(
      16,
      (_) => math.Random.secure().nextInt(256),
    );
    final digestBytes = sha1.convert([
      ...nonceBytes,
      ...utf8.encode(created),
      ...utf8.encode(settings.password),
    ]).bytes;

    return '''
<wsse:Security
  xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
  xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
  s:mustUnderstand="1">
  <wsse:UsernameToken>
    <wsse:Username>${_xmlEscape(username)}</wsse:Username>
    <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest">${base64Encode(digestBytes)}</wsse:Password>
    <wsse:Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">${base64Encode(nonceBytes)}</wsse:Nonce>
    <wsu:Created>${_xmlEscape(created)}</wsu:Created>
  </wsse:UsernameToken>
</wsse:Security>''';
  }

  String _continuousMoveBody({
    required String profileToken,
    required _OnvifPtzVector vector,
    required Duration timeout,
  }) {
    final velocity = StringBuffer('<tptz:Velocity>');
    if (vector.hasPanTilt) {
      velocity.write(
        '<tt:PanTilt x="${vector.pan.toStringAsFixed(2)}" y="${vector.tilt.toStringAsFixed(2)}" space="$_panTiltSpace"/>',
      );
    }
    if (vector.hasZoom) {
      velocity.write(
        '<tt:Zoom x="${vector.zoom.toStringAsFixed(2)}" space="$_zoomSpace"/>',
      );
    }
    velocity.write('</tptz:Velocity>');

    return '''
<tptz:ContinuousMove>
  <tptz:ProfileToken>${_xmlEscape(profileToken)}</tptz:ProfileToken>
  $velocity
  <tptz:Timeout>${_durationToOnvif(timeout)}</tptz:Timeout>
</tptz:ContinuousMove>''';
  }

  String _durationToOnvif(Duration duration) {
    final seconds = duration.inMilliseconds / 1000;
    final text = seconds == seconds.roundToDouble()
        ? seconds.toStringAsFixed(0)
        : seconds.toStringAsFixed(1);
    return 'PT${text}S';
  }

  Uri _serviceUri(int port, String path) {
    return Uri(scheme: 'http', host: settings.host, port: port, path: path);
  }

  Uri? _capabilityXAddr(XmlDocument document, String capability, int port) {
    for (final element in _xmlElements(document, capability)) {
      for (final xAddr in _xmlElements(element, 'XAddr')) {
        final normalized = _normalizeXAddr(xAddr.innerText, port);
        if (normalized != null) {
          return normalized;
        }
      }
    }
    return null;
  }

  Uri? _normalizeXAddr(String rawValue, int fallbackPort) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      return null;
    }

    var uri = Uri.tryParse(value);
    if (uri == null) {
      return null;
    }
    if (!uri.hasScheme) {
      uri = _serviceUri(
        fallbackPort,
        value.startsWith('/') ? value : '/$value',
      );
    }
    if (uri.host.isEmpty || uri.host == '0.0.0.0') {
      uri = uri.replace(host: settings.host);
    }
    if (!uri.hasPort) {
      uri = uri.replace(port: fallbackPort);
    }
    return uri;
  }

  List<Uri> _uniqueUris(Iterable<Uri?> uris) {
    final unique = <String, Uri>{};
    for (final uri in uris) {
      if (uri == null) {
        continue;
      }
      unique.putIfAbsent(uri.toString(), () => uri);
    }
    return unique.values.toList();
  }

  String? _soapFaultMessage(XmlDocument document) {
    final fault = _firstXmlElement(document, 'Fault');
    if (fault == null) {
      return null;
    }

    for (final localName in ['Text', 'Reason', 'faultstring']) {
      final text = _firstXmlElement(fault, localName)?.innerText.trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }

    return 'SOAP Fault';
  }

  String _errorSummary(Object? error) {
    if (error == null) {
      return '';
    }
    if (error is _OnvifPtzException) {
      return error.message;
    }
    if (error is SocketException) {
      return error.message;
    }
    if (error is TimeoutException) {
      return 'The camera did not answer in time.';
    }
    if (error is FormatException) {
      return error.message;
    }
    return error.toString();
  }
}

class _OnvifCapabilities {
  const _OnvifCapabilities({required this.mediaUri, required this.ptzUri});

  final Uri? mediaUri;
  final Uri? ptzUri;
}

class _OnvifPtzSession {
  _OnvifPtzSession({required this.profileToken, required this.ptzUris});

  final String profileToken;
  final List<Uri> ptzUris;
  Uri? _preferredPtzUri;

  List<Uri> get ptzCandidates {
    final preferred = _preferredPtzUri;
    if (preferred == null) {
      return ptzUris;
    }
    return [
      preferred,
      for (final uri in ptzUris)
        if (uri != preferred) uri,
    ];
  }

  void prefer(Uri uri) {
    _preferredPtzUri = uri;
  }
}

Iterable<XmlElement> _xmlElements(XmlNode node, String localName) {
  return node.descendants.whereType<XmlElement>().where((element) {
    return element.name.local == localName;
  });
}

XmlElement? _firstXmlElement(XmlNode node, String localName) {
  for (final element in _xmlElements(node, localName)) {
    return element;
  }
  return null;
}

String _xmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
