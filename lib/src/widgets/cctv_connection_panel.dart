part of '../../main.dart';

/// Bottom-sheet content for connecting to, scanning for, and removing live
/// CCTV cameras. The live video itself fills the CCTV tab behind this sheet;
/// this panel only manages which streams are connected.
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
  final TextEditingController _manualUrlController = TextEditingController();

  RtspCameraScanner? _activeScanner;
  CameraScanProgress? _scanProgress;
  List<RtspCameraCandidate> _candidates = const [];
  bool _scanning = false;
  bool _showManualEntry = false;
  String? _scanMessage;
  String? _manualError;

  @override
  void dispose() {
    _activeScanner?.cancel();
    _manualUrlController.dispose();
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
    final added = widget.controller.addLiveCctvStream(
      widget.user.username,
      candidate.streamUrl,
    );
    setState(() {
      if (added) {
        _manualError = null;
        _showManualEntry = false;
        _scanMessage = 'Added ${candidate.endpoint} as a live camera.';
      } else {
        _scanMessage =
            widget.controller.lastError ?? 'Could not add that camera.';
      }
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

    final added = widget.controller.addLiveCctvStream(
      widget.user.username,
      normalizedUrl,
    );
    if (!added) {
      setState(() {
        _manualError =
            widget.controller.lastError ?? 'Could not add that camera.';
      });
      return;
    }

    setState(() {
      _manualUrlController.clear();
      _manualError = null;
      _showManualEntry = false;
    });
  }

  void _removeStream(LiveCctvStream stream) {
    widget.controller.removeLiveCctvStream(widget.user.username, stream.id);
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
                    ? 'Scan the local network or enter an RTSP URL to connect a camera.'
                    : 'Connected cameras (${streams.length}/${AppController.maxLiveCctvStreams}).',
                style: TextStyle(color: colors.mutedText, height: 1.4),
              ),
              if (streams.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (var i = 0; i < streams.length; i++) ...[
                  if (i > 0) Divider(color: colors.border, height: 1),
                  _ConnectedCameraRow(
                    displayLabel: cctvStreamDisplayLabel(i, streams.length),
                    streamUrl: streams[i].streamUrl,
                    onRemove: () => _removeStream(streams[i]),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              _buildActionButtons(atLimit),
              if (atLimit) ...[const SizedBox(height: 10), _buildLimitNotice()],
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
          ),
        ),
      ),
    );
  }

  Widget _buildLimitNotice() {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'Up to ${AppController.maxLiveCctvStreams} live cameras can be connected at once. Remove one to add another.',
        style: TextStyle(color: colors.mutedText, height: 1.4),
      ),
    );
  }

  Widget _buildActionButtons(bool atLimit) {
    final scanButton = FilledButton.icon(
      onPressed: _scanning || atLimit ? null : _startScan,
      icon: Icon(
        _scanning ? Icons.radar_outlined : Icons.manage_search_outlined,
      ),
      label: Text(_scanning ? 'Scanning...' : 'Scan Cameras'),
    );
    final addButton = OutlinedButton.icon(
      onPressed: atLimit
          ? null
          : () {
              setState(() {
                _showManualEntry = !_showManualEntry;
                _manualError = null;
              });
            },
      icon: const Icon(Icons.add_link_outlined),
      label: const Text('Add Camera'),
    );
    final stopButton = _scanning
        ? OutlinedButton.icon(
            onPressed: _stopScan,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop'),
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              scanButton,
              if (stopButton != null) ...[
                const SizedBox(height: 10),
                stopButton,
              ],
              const SizedBox(height: 10),
              addButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: scanButton),
            if (stopButton != null) ...[
              const SizedBox(width: 10),
              Expanded(child: stopButton),
            ],
            const SizedBox(width: 10),
            Expanded(child: addButton),
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

class _ConnectedCameraRow extends StatelessWidget {
  const _ConnectedCameraRow({
    required this.displayLabel,
    required this.streamUrl,
    required this.onRemove,
  });

  final String displayLabel;
  final String streamUrl;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(Icons.videocam_outlined, size: 18, color: colors.mutedText),
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
                  streamUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.subtleText, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove camera',
            onPressed: onRemove,
            icon: const Icon(Icons.videocam_off_outlined),
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
                    style: TextStyle(color: colors.subtleText, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        );

        final useButton = FilledButton.icon(
          onPressed: onUse,
          icon: const Icon(Icons.add_outlined),
          label: const Text('Add'),
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
