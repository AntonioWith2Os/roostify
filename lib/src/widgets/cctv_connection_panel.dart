part of '../../main.dart';

class CctvConnectionPanel extends StatefulWidget {
  const CctvConnectionPanel({
    super.key,
    required this.controller,
    required this.user,
  });

  final AppController controller;
  final AppUser user;

  @override
  State<CctvConnectionPanel> createState() => _CctvConnectionPanelState();
}

class _CctvConnectionPanelState extends State<CctvConnectionPanel> {
  final TextEditingController _manualUrlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pathController = TextEditingController(
    text: '/live/ch00_1',
  );

  RtspCameraScanner? _activeScanner;
  CameraScanProgress? _scanProgress;
  List<RtspCameraCandidate> _candidates = const [];
  bool _scanning = false;
  bool _showManualEntry = false;
  bool _showScanOptions = false;
  String? _scanMessage;
  String? _manualError;

  @override
  void initState() {
    super.initState();
    _manualUrlController.text = widget.user.liveCctvStreamUrl ?? '';
  }

  @override
  void didUpdateWidget(covariant CctvConnectionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedUrl = widget.user.liveCctvStreamUrl ?? '';
    if (selectedUrl != oldWidget.user.liveCctvStreamUrl &&
        selectedUrl != _manualUrlController.text) {
      _manualUrlController.text = selectedUrl;
    }
  }

  @override
  void dispose() {
    _activeScanner?.cancel();
    _manualUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    FocusManager.instance.primaryFocus?.unfocus();
    _activeScanner?.cancel();

    final scanner = RtspCameraScanner();
    _activeScanner = scanner;

    setState(() {
      _scanning = true;
      _scanProgress = null;
      _scanMessage = 'Looking for RTSP cameras on this local network...';
      _candidates = const [];
      _manualError = null;
    });

    final candidates = await scanner.scan(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      preferredPath: _pathController.text.trim(),
      onProgress: (progress) {
        if (!mounted || _activeScanner != scanner) {
          return;
        }
        setState(() {
          _scanProgress = progress;
          _scanMessage = progress.label;
        });
      },
    );

    if (!mounted || _activeScanner != scanner) {
      return;
    }

    setState(() {
      _scanning = false;
      _activeScanner = null;
      _candidates = candidates;
      if (scanner.cancelled) {
        _scanMessage = 'Camera scan stopped.';
      } else if (candidates.isEmpty) {
        _scanMessage =
            'No RTSP cameras were found on the current local network. For V380 Pro, confirm RTSP/ONVIF is enabled, then try manual URL entry with the camera LAN IP.';
      } else {
        _scanMessage =
            'Found ${candidates.length} camera${candidates.length == 1 ? '' : 's'}.';
      }
    });
  }

  void _stopScan() {
    _activeScanner?.cancel();
    setState(() {
      _scanMessage = 'Stopping camera scan...';
    });
  }

  void _selectCamera(RtspCameraCandidate candidate) {
    widget.controller.setLiveCctvStreamUrl(
      widget.user.username,
      candidate.streamUrl,
    );
    setState(() {
      _manualUrlController.text = candidate.streamUrl;
      _manualError = null;
      _showManualEntry = false;
    });
  }

  void _useManualUrl() {
    final normalizedUrl = _normalizeRtspUrl(_manualUrlController.text);
    if (normalizedUrl == null) {
      setState(() {
        _manualError = 'Enter an RTSP URL like rtsp://192.168.1.20:554/live.';
      });
      return;
    }

    widget.controller.setLiveCctvStreamUrl(widget.user.username, normalizedUrl);
    setState(() {
      _manualUrlController.text = normalizedUrl;
      _manualError = null;
      _showManualEntry = false;
    });
  }

  void _clearSelectedCamera() {
    widget.controller.setLiveCctvStreamUrl(widget.user.username, null);
    setState(() {
      _manualUrlController.clear();
      _showManualEntry = true;
      _manualError = null;
    });
  }

  String? _normalizeRtspUrl(String rawValue) {
    var value = rawValue.trim();
    if (value.isEmpty) {
      return null;
    }

    if (!value.contains('://')) {
      value = 'rtsp://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme.toLowerCase() != 'rtsp' || uri.host.isEmpty) {
      return null;
    }

    return uri.toString();
  }

  @override
  Widget build(BuildContext context) {
    final selectedStreamUrl = widget.user.liveCctvStreamUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LocalYoloModelStatus(),
        const SizedBox(height: 12),
        if (selectedStreamUrl == null)
          const _NoSelectedCctvState()
        else
          LiveFeedCard(
            key: ValueKey(selectedStreamUrl),
            streamUrl: selectedStreamUrl,
            detections: widget.user.cctvInspection.detections,
            onFrameCaptureStarted: () {
              widget.controller.markCctvInspectionCapturing(
                widget.user.username,
                selectedStreamUrl,
              );
            },
            onFrameReady: (frameBytes) {
              return widget.controller.inspectCctvFrame(
                widget.user.username,
                selectedStreamUrl,
                frameBytes,
              );
            },
            onFrameCaptureFailed: (message) {
              widget.controller.markCctvInspectionError(
                widget.user.username,
                selectedStreamUrl,
                message,
              );
            },
          ),
        if (selectedStreamUrl != null) ...[
          const SizedBox(height: 12),
          V380PtzControlPanel(streamUrl: selectedStreamUrl),
        ],
        const SizedBox(height: 12),
        _buildActionButtons(selectedStreamUrl),
        if (_showScanOptions) ...[
          const SizedBox(height: 12),
          _buildScanOptions(),
        ],
        if (_showManualEntry) ...[
          const SizedBox(height: 12),
          _buildManualEntry(),
        ],
        if (_scanMessage != null) ...[
          const SizedBox(height: 12),
          _buildScanStatus(),
        ],
        if (_candidates.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildCandidateList(),
        ],
      ],
    );
  }

  Widget _buildActionButtons(String? selectedStreamUrl) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: _scanning ? null : _startScan,
          icon: Icon(
            _scanning ? Icons.radar_outlined : Icons.manage_search_outlined,
          ),
          label: Text(_scanning ? 'Scanning...' : 'Scan Cameras'),
        ),
        if (_scanning)
          OutlinedButton.icon(
            onPressed: _stopScan,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop'),
          ),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _showScanOptions = !_showScanOptions;
            });
          },
          icon: const Icon(Icons.tune_outlined),
          label: Text(_showScanOptions ? 'Hide Options' : 'Scan Options'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _showManualEntry = !_showManualEntry;
              _manualError = null;
            });
          },
          icon: const Icon(Icons.link_outlined),
          label: Text(selectedStreamUrl == null ? 'Manual URL' : 'Change URL'),
        ),
        if (selectedStreamUrl != null)
          OutlinedButton.icon(
            onPressed: _clearSelectedCamera,
            icon: const Icon(Icons.videocam_off_outlined),
            label: const Text('Disconnect'),
          ),
      ],
    );
  }

  Widget _buildScanOptions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final fields = [
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Camera username',
              hintText: 'V380 often uses admin',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Camera password',
              hintText: 'Leave blank if the camera password is empty',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          TextField(
            controller: _pathController,
            decoration: const InputDecoration(
              labelText: 'Try stream path first',
              hintText: '/live/ch00_1',
              prefixIcon: Icon(Icons.route_outlined),
            ),
          ),
        ];

        if (compact) {
          return Column(
            children: [
              fields[0],
              const SizedBox(height: 10),
              fields[1],
              const SizedBox(height: 10),
              fields[2],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: fields[0]),
            const SizedBox(width: 10),
            Expanded(child: fields[1]),
            const SizedBox(width: 10),
            Expanded(child: fields[2]),
          ],
        );
      },
    );
  }

  Widget _buildManualEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _manualUrlController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'RTSP stream URL',
            hintText: _testRtspStreamUrl,
            prefixIcon: Icon(Icons.videocam_outlined),
          ),
        ),
        if (_manualError != null) ...[
          const SizedBox(height: 8),
          Text(
            _manualError!,
            style: const TextStyle(
              color: Color(0xFFFF8A98),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _useManualUrl,
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Use This Stream'),
        ),
      ],
    );
  }

  Widget _buildScanStatus() {
    final progress = _scanProgress;
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_scanning && progress != null) ...[
            LinearProgressIndicator(value: progress.value),
            const SizedBox(height: 10),
          ],
          Text(
            _scanMessage!,
            style: TextStyle(color: colors.mutedText, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateList() {
    final colors = context.appColors;
    return Column(
      children: [
        for (var index = 0; index < _candidates.length; index++) ...[
          if (index > 0) Divider(color: colors.border, height: 1),
          _CameraCandidateTile(
            candidate: _candidates[index],
            onUse: () => _selectCamera(_candidates[index]),
          ),
        ],
      ],
    );
  }
}

class _NoSelectedCctvState extends StatelessWidget {
  const _NoSelectedCctvState();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.mediaGradientStart, colors.mediaGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_outlined, color: colors.mutedText, size: 38),
          const SizedBox(height: 12),
          const Text(
            'No CCTV stream selected',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan the local network or enter an RTSP URL to connect a camera.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.mutedText, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _CameraCandidateTile extends StatelessWidget {
  const _CameraCandidateTile({required this.candidate, required this.onUse});

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final details = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: accent.withValues(alpha: 0.14),
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
                  const SizedBox(height: 4),
                  Text(
                    candidate.status,
                    style: TextStyle(color: colors.mutedText, height: 1.35),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    candidate.streamUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.subtleText, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );

        final useButton = FilledButton.icon(
          onPressed: onUse,
          icon: const Icon(Icons.play_arrow_outlined),
          label: const Text('Use'),
        );

        if (compact) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [details, const SizedBox(height: 12), useButton],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 12),
              useButton,
            ],
          ),
        );
      },
    );
  }
}
