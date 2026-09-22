part of '../../main.dart';

/// Manages V380 Cloud cameras and direct RTSP cameras discovered on the
/// local network.
class CctvManagementSheet extends StatefulWidget {
  const CctvManagementSheet({
    super.key,
    required this.controller,
    required this.user,
  });

  final AppController controller;
  final AppUser user;

  @override
  State<CctvManagementSheet> createState() => _CctvManagementSheetState();
}

class _CctvManagementSheetState extends State<CctvManagementSheet> {
  final TextEditingController _v380LabelController = TextEditingController();
  final TextEditingController _v380DeviceIdController = TextEditingController();
  final TextEditingController _v380UsernameController = TextEditingController(
    text: 'admin',
  );
  final TextEditingController _v380PasswordController = TextEditingController();
  final TextEditingController _localUsernameController =
      TextEditingController();
  final TextEditingController _localPasswordController =
      TextEditingController();
  final TextEditingController _localPathController = TextEditingController();

  RtspCameraScanner? _activeScanner;
  CameraScanProgress? _scanProgress;
  List<RtspCameraCandidate> _candidates = const [];
  bool _scanning = false;
  String? _scanMessage;
  String? _v380Error;

  @override
  void dispose() {
    _activeScanner?.cancel();
    _v380LabelController.dispose();
    _v380DeviceIdController.dispose();
    _v380UsernameController.dispose();
    _v380PasswordController.dispose();
    _localUsernameController.dispose();
    _localPasswordController.dispose();
    _localPathController.dispose();
    super.dispose();
  }

  Future<void> _startLocalScan() async {
    FocusManager.instance.primaryFocus?.unfocus();
    _activeScanner?.cancel();

    if (kIsWeb) {
      setState(() {
        _scanMessage =
            'Local camera scanning is available in the Android and iOS apps.';
      });
      return;
    }

    final scanner = RtspCameraScanner();
    _activeScanner = scanner;
    setState(() {
      _scanning = true;
      _scanProgress = null;
      _candidates = const [];
      _scanMessage = 'Looking for RTSP cameras on this local network...';
    });

    final candidates = await scanner.scan(
      username: _localUsernameController.text,
      password: _localPasswordController.text,
      preferredPath: _localPathController.text,
      onProgress: (progress) {
        if (!mounted || _activeScanner != scanner) return;
        setState(() {
          _scanProgress = progress;
          _scanMessage = progress.label;
        });
      },
    );

    if (!mounted || _activeScanner != scanner) return;
    setState(() {
      _scanning = false;
      _activeScanner = null;
      _candidates = candidates;
      if (scanner.cancelled) {
        _scanMessage = 'Local camera scan stopped.';
      } else if (candidates.isEmpty) {
        _scanMessage =
            'No RTSP cameras were found. Make sure this device is on the camera Wi-Fi and RTSP/ONVIF is enabled.';
      } else {
        _scanMessage =
            'Found ${candidates.length} local camera${candidates.length == 1 ? '' : 's'}.';
      }
    });
  }

  void _stopCameraProbe() {
    _activeScanner?.cancel();
    setState(() {
      _scanMessage = 'Stopping local camera scan...';
    });
  }

  String _candidateUrlWithCredentials(
    RtspCameraCandidate candidate,
    TextEditingController usernameController,
    TextEditingController passwordController,
  ) {
    if (usernameController.text.trim().isEmpty) {
      return candidate.streamUrl;
    }
    final candidateUri = Uri.parse(candidate.streamUrl);
    final path = candidateUri.hasQuery
        ? '${candidateUri.path}?${candidateUri.query}'
        : candidateUri.path;
    return _buildRtspUrl(
      host: candidate.host,
      port: candidate.port,
      path: path,
      username: usernameController.text,
      password: passwordController.text,
    );
  }

  void _selectLocalCamera(RtspCameraCandidate candidate) {
    if (candidate.requiresCredentials &&
        _localUsernameController.text.trim().isEmpty) {
      setState(() {
        _scanMessage =
            'This camera requires a login. Enter its username and password, then tap Add again.';
      });
      return;
    }

    final localStreamUrl = _candidateUrlWithCredentials(
      candidate,
      _localUsernameController,
      _localPasswordController,
    );
    final added = widget.controller.addLiveCctvStream(
      widget.user.username,
      localStreamUrl,
      label: 'Local ${candidate.host}',
      allowDirectRtspCamera: true,
    );
    setState(() {
      _scanMessage = added
          ? 'Added ${candidate.endpoint} as a local camera.'
          : widget.controller.lastError ?? 'Could not add that camera.';
    });
  }

  void _addV380CloudCamera() {
    FocusManager.instance.primaryFocus?.unfocus();
    final sourceUrl = buildV380CloudCameraUri(
      deviceId: _v380DeviceIdController.text,
      username: _v380UsernameController.text,
      password: _v380PasswordController.text,
    );
    final validationError = v380CloudCameraValidationError(sourceUrl);
    if (validationError != null) {
      setState(() => _v380Error = validationError);
      return;
    }
    final added = widget.controller.addLiveCctvStream(
      widget.user.username,
      sourceUrl,
      label: _v380LabelController.text.trim().isEmpty
          ? 'V380 ${_v380DeviceIdController.text.trim()}'
          : _v380LabelController.text,
    );
    if (!added) {
      setState(() => _v380Error = widget.controller.lastError);
      return;
    }
    setState(() {
      _v380LabelController.clear();
      _v380DeviceIdController.clear();
      _v380PasswordController.clear();
      _v380Error = null;
    });
  }

  void _removeStream(LiveCctvStream stream) {
    widget.controller.removeLiveCctvStream(widget.user.username, stream.id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final streams = widget.user.liveCctvStreams;
    final atLimit = streams.length >= AppController.maxLiveCctvStreams;
    final colors = context.appColors;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const Text(
                'Manage Cameras',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                streams.isEmpty
                    ? (_v380CloudCameraAddingEnabled
                          ? 'Scan nearby cameras or connect through V380 Cloud.'
                          : 'Scan nearby cameras on this Wi-Fi network.')
                    : 'Connected cameras (${streams.length}/${AppController.maxLiveCctvStreams}).',
                style: TextStyle(color: colors.mutedText, height: 1.4),
              ),
              const SizedBox(height: 14),
              if (_v380CloudCameraAddingEnabled) ...[
                _ArchitectureNotice(colors: colors),
                const SizedBox(height: 14),
                _buildV380CloudCamera(atLimit),
                const SizedBox(height: 12),
              ],
              _buildLocalScanner(atLimit),
              if (streams.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (var index = 0; index < streams.length; index++) ...[
                  if (index > 0) Divider(color: colors.border, height: 1),
                  _ConnectedStreamRow(
                    displayLabel: streams[index].label.isEmpty
                        ? cctvStreamDisplayLabel(index, streams.length)
                        : streams[index].label,
                    stream: streams[index],
                    onRemove: () => _removeStream(streams[index]),
                  ),
                ],
              ],
              if (atLimit) ...[
                const SizedBox(height: 16),
                _LimitNotice(colors: colors),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildV380CloudCamera(bool atLimit) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.cloud_sync_outlined),
        title: const Text(
          'V380 Cloud camera',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text('Connect directly to the V380 cloud'),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          Text(
            'This device locates the camera on the V380 cloud and decodes the stream itself - no Roostify server is involved. Credentials are stored only on this device.',
            style: TextStyle(
              color: colors.mutedText,
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _v380LabelController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Camera label (optional)',
              hintText: 'Main Pen',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _v380DeviceIdController,
            keyboardType: TextInputType.number,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'V380 device ID',
              hintText: '12345678',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _v380UsernameController,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Camera username',
              hintText: 'admin',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _v380PasswordController,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Camera password (optional)',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          if (_v380Error case final error?) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                error,
                style: const TextStyle(
                  color: Color(0xFFFF8A98),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: atLimit ? null : _addV380CloudCamera,
            icon: const Icon(Icons.add_link_outlined),
            label: const Text('Connect V380 Camera'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalScanner(bool atLimit) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.radar_outlined),
        title: const Text(
          'Scan local network',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text('Find RTSP cameras on the current Wi-Fi'),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          Text(
            'Camera login and stream path are optional. Add them before scanning when your camera requires authentication.',
            style: TextStyle(
              color: colors.mutedText,
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _localUsernameController,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Camera username (optional)',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _localPasswordController,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Camera password (optional)',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _localPathController,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Preferred RTSP path (optional)',
              hintText: '/live/ch00_1',
              prefixIcon: Icon(Icons.route_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _scanning || atLimit ? null : _startLocalScan,
                  icon: Icon(
                    _scanning
                        ? Icons.radar_outlined
                        : Icons.manage_search_outlined,
                  ),
                  label: Text(_scanning ? 'Scanning...' : 'Scan Cameras'),
                ),
              ),
              if (_scanning) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _stopCameraProbe,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Stop'),
                ),
              ],
            ],
          ),
          if (_scanMessage != null) ...[
            const SizedBox(height: 12),
            if (_scanning && _scanProgress != null) ...[
              LinearProgressIndicator(value: _scanProgress!.value),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _scanMessage!,
                style: TextStyle(color: colors.mutedText, height: 1.4),
              ),
            ),
          ],
          if (_candidates.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var index = 0; index < _candidates.length; index++) ...[
              if (index > 0) Divider(color: colors.border, height: 1),
              _RtspCameraCandidateTile(
                candidate: _candidates[index],
                onUse: () => _selectLocalCamera(_candidates[index]),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ArchitectureNotice extends StatelessWidget {
  const _ArchitectureNotice({required this.colors});

  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hub_outlined, color: Color(0xFF4DA1FF)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'For remote viewing, connect through V380 Cloud here. On farm Wi-Fi, Roostify can also discover a local RTSP camera.',
              style: TextStyle(color: colors.mutedText, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitNotice extends StatelessWidget {
  const _LimitNotice({required this.colors});

  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'Up to ${AppController.maxLiveCctvStreams} cameras can be connected at once. Remove one to add another.',
        style: TextStyle(color: colors.mutedText, height: 1.4),
      ),
    );
  }
}

class _ConnectedStreamRow extends StatelessWidget {
  const _ConnectedStreamRow({
    required this.displayLabel,
    required this.stream,
    required this.onRemove,
  });

  final String displayLabel;
  final LiveCctvStream stream;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(Icons.videocam_outlined, size: 20, color: colors.mutedText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  safePlaybackEndpointLabel(stream.streamUrl),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.subtleText, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove stream',
            onPressed: onRemove,
            icon: const Icon(Icons.link_off_outlined),
          ),
        ],
      ),
    );
  }
}

class _RtspCameraCandidateTile extends StatelessWidget {
  const _RtspCameraCandidateTile({
    required this.candidate,
    required this.onUse,
  });

  final RtspCameraCandidate candidate;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accent = candidate.verified
        ? const Color(0xFF26C281)
        : candidate.requiresCredentials
        ? const Color(0xFFE6B452)
        : const Color(0xFF4DA1FF);
    final icon = candidate.verified
        ? Icons.verified_outlined
        : candidate.requiresCredentials
        ? Icons.lock_outline
        : Icons.videocam_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: accent.withValues(alpha: .14),
            foregroundColor: accent,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.endpoint,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  candidate.status,
                  style: TextStyle(color: colors.mutedText, height: 1.35),
                ),
                const SizedBox(height: 3),
                Text(
                  safePlaybackEndpointLabel(candidate.streamUrl),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.subtleText, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onUse, child: const Text('Add')),
        ],
      ),
    );
  }
}
