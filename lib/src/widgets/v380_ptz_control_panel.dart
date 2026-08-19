part of '../../main.dart';

class V380PtzControlPanel extends StatefulWidget {
  const V380PtzControlPanel({
    super.key,
    required this.streamUrl,
    this.compactOverlay = false,
  });

  final String streamUrl;
  final bool compactOverlay;

  @override
  State<V380PtzControlPanel> createState() => _V380PtzControlPanelState();
}

class _V380PtzControlPanelState extends State<V380PtzControlPanel> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: 'Auto',
  );

  static const _holdCommandTimeout = Duration(seconds: 2);
  static const _holdRefreshInterval = Duration(milliseconds: 200);
  static const _holdSafetyTimeout = Duration(seconds: 30);
  static const _moveSpeed = 0.55;

  Timer? _holdSafetyTimer;
  _OnvifPtzClient? _ptzClient;
  String? _ptzClientKey;
  String? _status;
  String? _activeControlId;
  bool _settingsOpen = false;
  bool _busy = false;
  bool _moveStartInFlight = false;
  bool _releaseRequested = false;

  @override
  void initState() {
    super.initState();
    _syncCredentialsFromStream(force: true);
  }

  @override
  void didUpdateWidget(covariant V380PtzControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _resetPtzClient();
      _syncCredentialsFromStream(force: true);
      setState(() {
        _status = null;
      });
    }
  }

  @override
  void dispose() {
    _holdSafetyTimer?.cancel();
    final client = _ptzClient;
    if (_activeControlId != null && client != null) {
      _ptzClient = null;
      unawaited(client.stop().catchError((_) {}).whenComplete(client.close));
    } else {
      _resetPtzClient();
    }
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _syncCredentialsFromStream({required bool force}) {
    final credentials = _cameraCredentialsFromRtspUrl(widget.streamUrl);
    if (force || _usernameController.text.trim().isEmpty) {
      _usernameController.text = credentials.username.isEmpty
          ? 'admin'
          : credentials.username;
    }
    if (force || _passwordController.text.isEmpty) {
      _passwordController.text = credentials.password;
    }
  }

  void _resetPtzClient() {
    _ptzClient?.close();
    _ptzClient = null;
    _ptzClientKey = null;
  }

  void _startHoldMove(String controlId, _OnvifPtzVector vector) {
    if (_activeControlId == controlId ||
        (_busy && _activeControlId == null) ||
        (_activeControlId != null && _activeControlId != controlId)) {
      return;
    }

    _holdSafetyTimer?.cancel();
    _releaseRequested = false;
    _moveStartInFlight = true;
    setState(() {
      _activeControlId = controlId;
      _busy = true;
      _status = 'Starting PTZ movement...';
    });

    _holdSafetyTimer = Timer(_holdSafetyTimeout, () {
      if (_activeControlId == controlId) {
        _endHoldMove(controlId);
      }
    });
    unawaited(_holdMoveLoop(controlId, vector));
  }

  Future<void> _holdMoveLoop(String controlId, _OnvifPtzVector vector) async {
    _OnvifPtzClient? client;
    try {
      client = _clientForSettings(_settingsFromFields());
      var firstMoveSent = false;

      while (mounted && _activeControlId == controlId && !_releaseRequested) {
        _moveStartInFlight = true;
        await client.startContinuousMove(
          vector.scaled(_moveSpeed),
          timeout: _holdCommandTimeout,
        );

        if (!mounted) {
          return;
        }

        _moveStartInFlight = false;
        if (_releaseRequested || _activeControlId != controlId) {
          break;
        }

        if (!firstMoveSent) {
          firstMoveSent = true;
          setState(() {
            _busy = false;
            _status = 'PTZ movement active.';
          });
        }

        await Future<void>.delayed(_holdRefreshInterval);
      }

      if (!mounted) {
        return;
      }

      _moveStartInFlight = false;
      if (_releaseRequested && _activeControlId == controlId) {
        await _sendStopForHold(controlId, client);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _holdSafetyTimer?.cancel();
      setState(() {
        _activeControlId = null;
        _busy = false;
        _moveStartInFlight = false;
        _releaseRequested = false;
        _status = _friendlyPtzError(error);
      });
    }
  }

  void _endHoldMove(String controlId) {
    if (_activeControlId != controlId) {
      return;
    }

    _releaseRequested = true;
    _holdSafetyTimer?.cancel();
    if (_moveStartInFlight) {
      setState(() {
        _status = 'Stopping PTZ movement...';
      });
      return;
    }

    final client = _ptzClient;
    if (client == null) {
      setState(() {
        _activeControlId = null;
        _busy = false;
        _status = 'PTZ movement stopped.';
      });
      return;
    }

    unawaited(_sendStopForHold(controlId, client));
  }

  Future<void> _sendStopForHold(
    String controlId,
    _OnvifPtzClient client,
  ) async {
    if (!mounted) {
      return;
    }

    _holdSafetyTimer?.cancel();
    setState(() {
      if (_activeControlId == controlId) {
        _activeControlId = null;
      }
      _busy = true;
      _moveStartInFlight = false;
      _releaseRequested = false;
      _status = 'Stopping PTZ movement...';
    });

    try {
      await client.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'PTZ movement stopped.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = _friendlyPtzError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _stop() async {
    final activeControlId = _activeControlId;
    if (activeControlId != null) {
      _endHoldMove(activeControlId);
      return;
    }

    await _runPtzCommand(
      pendingStatus: 'Stopping PTZ movement...',
      successStatus: 'PTZ movement stopped.',
      action: (client) => client.stop(),
    );
  }

  Future<void> _runPtzCommand({
    required String pendingStatus,
    required String successStatus,
    required Future<void> Function(_OnvifPtzClient client) action,
  }) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _status = pendingStatus;
    });

    try {
      final client = _clientForSettings(_settingsFromFields());
      await action(client);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = successStatus;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = _friendlyPtzError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  _OnvifPtzClient _clientForSettings(_OnvifPtzSettings settings) {
    final key = settings.cacheKey;
    if (_ptzClient == null || _ptzClientKey != key) {
      _resetPtzClient();
      _ptzClient = _OnvifPtzClient(settings);
      _ptzClientKey = key;
    }
    return _ptzClient!;
  }

  _OnvifPtzSettings _settingsFromFields() {
    final uri = Uri.tryParse(widget.streamUrl);
    if (uri == null || uri.host.isEmpty) {
      throw const FormatException('The selected RTSP stream has no camera IP.');
    }

    return _OnvifPtzSettings(
      host: uri.host,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      port: _parseOnvifPort(_portController.text),
    );
  }

  int? _parseOnvifPort(String value) {
    final cleanValue = value.trim().toLowerCase();
    if (cleanValue.isEmpty || cleanValue == 'auto') {
      return null;
    }

    final port = int.tryParse(cleanValue);
    if (port == null || port <= 0 || port > 65535) {
      throw const FormatException('Enter a valid ONVIF port or Auto.');
    }

    return port;
  }

  String _friendlyPtzError(Object error) {
    if (error is _OnvifPtzException) {
      return error.message;
    }
    if (error is FormatException) {
      return error.message;
    }
    return 'PTZ command failed: $error';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final host = Uri.tryParse(widget.streamUrl)?.host ?? 'camera';
    final hasErrorStatus =
        _status?.contains('failed') == true ||
        _status?.contains('Could not') == true ||
        _status?.contains('Enter ') == true;
    final textColor = widget.compactOverlay ? Colors.white : colors.text;
    final mutedTextColor = widget.compactOverlay
        ? Colors.white70
        : colors.subtleText;
    // The overlay floats directly over live video, so give its text a drop
    // shadow to stay legible over bright footage even though the backing
    // box behind it is only translucent, not opaque.
    final overlayTextShadow = widget.compactOverlay
        ? const [Shadow(color: Colors.black87, blurRadius: 6)]
        : null;

    return Container(
      // Callers commonly place this overlay in a Positioned with only a
      // right/bottom offset (no matching left/top or explicit size), which
      // gives it unbounded constraints — and the Row+Expanded header below
      // needs bounded width to lay out. Pin a concrete width so this works
      // regardless of how the caller positions it.
      width: widget.compactOverlay ? 240 : null,
      padding: EdgeInsets.all(widget.compactOverlay ? 10 : 14),
      decoration: BoxDecoration(
        color: widget.compactOverlay
            ? Colors.black.withValues(alpha: 0.32)
            : colors.surfaceRaised,
        borderRadius: BorderRadius.circular(widget.compactOverlay ? 16 : 20),
        border: widget.compactOverlay ? null : Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.control_camera_outlined,
                color: Color(0xFF43E39C),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'V380 PTZ controls',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    shadows: overlayTextShadow,
                  ),
                ),
              ),
              Text(
                host,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  shadows: overlayTextShadow,
                ),
              ),
              if (!widget.compactOverlay) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'PTZ settings',
                  onPressed: () {
                    setState(() {
                      _settingsOpen = !_settingsOpen;
                    });
                  },
                  icon: Icon(
                    _settingsOpen
                        ? Icons.expand_less_outlined
                        : Icons.tune_outlined,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: widget.compactOverlay ? 8 : 10),
          _buildRemoteControl(),
          if (!widget.compactOverlay)
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildPtzSettings(),
              ),
              crossFadeState: _settingsOpen
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
          if (_status case final status?) ...[
            SizedBox(height: widget.compactOverlay ? 8 : 12),
            Text(
              status,
              maxLines: widget.compactOverlay ? 2 : null,
              overflow: widget.compactOverlay ? TextOverflow.ellipsis : null,
              style: TextStyle(
                color: hasErrorStatus
                    ? const Color(0xFFFF8A98)
                    : widget.compactOverlay
                    ? Colors.white70
                    : colors.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
                shadows: overlayTextShadow,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRemoteControl() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: widget.compactOverlay ? 220 : 238,
        padding: widget.compactOverlay
            ? const EdgeInsets.fromLTRB(12, 12, 12, 10)
            : const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: widget.compactOverlay
              ? Colors.transparent
              : const Color(0xFF11162A),
          borderRadius: BorderRadius.circular(28),
          border: widget.compactOverlay
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: widget.compactOverlay
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_buildDirectionPad()],
        ),
      ),
    );
  }

  Widget _buildDirectionPad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PtzHoldButton(
          tooltip: 'Tilt up',
          icon: Icons.keyboard_arrow_up,
          active: _activeControlId == 'tilt-up',
          disabled: _isControlDisabled('tilt-up'),
          onPressStart: () =>
              _startHoldMove('tilt-up', const _OnvifPtzVector(tilt: 1)),
          onPressEnd: () => _endHoldMove('tilt-up'),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PtzHoldButton(
              tooltip: 'Pan left',
              icon: Icons.keyboard_arrow_left,
              active: _activeControlId == 'pan-left',
              disabled: _isControlDisabled('pan-left'),
              onPressStart: () =>
                  _startHoldMove('pan-left', const _OnvifPtzVector(pan: -1)),
              onPressEnd: () => _endHoldMove('pan-left'),
            ),
            const SizedBox(width: 8),
            _PtzTapButton(
              tooltip: 'Stop movement',
              icon: Icons.stop_circle_outlined,
              disabled: _busy && _activeControlId == null,
              onPressed: _stop,
            ),
            const SizedBox(width: 8),
            _PtzHoldButton(
              tooltip: 'Pan right',
              icon: Icons.keyboard_arrow_right,
              active: _activeControlId == 'pan-right',
              disabled: _isControlDisabled('pan-right'),
              onPressStart: () =>
                  _startHoldMove('pan-right', const _OnvifPtzVector(pan: 1)),
              onPressEnd: () => _endHoldMove('pan-right'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _PtzHoldButton(
          tooltip: 'Tilt down',
          icon: Icons.keyboard_arrow_down,
          active: _activeControlId == 'tilt-down',
          disabled: _isControlDisabled('tilt-down'),
          onPressStart: () =>
              _startHoldMove('tilt-down', const _OnvifPtzVector(tilt: -1)),
          onPressEnd: () => _endHoldMove('tilt-down'),
        ),
      ],
    );
  }

  bool _isControlDisabled(String controlId) {
    return (_busy && _activeControlId == null) ||
        (_activeControlId != null && _activeControlId != controlId);
  }

  Widget _buildPtzSettings() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final fields = [
          TextField(
            controller: _usernameController,
            onChanged: (_) => _resetPtzClient(),
            decoration: const InputDecoration(
              labelText: 'ONVIF username',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          TextField(
            controller: _passwordController,
            onChanged: (_) => _resetPtzClient(),
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'ONVIF password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          TextField(
            controller: _portController,
            onChanged: (_) => _resetPtzClient(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'ONVIF port',
              hintText: 'Auto',
              prefixIcon: Icon(Icons.settings_ethernet_outlined),
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
            SizedBox(width: 160, child: fields[2]),
          ],
        );
      },
    );
  }
}

class _PtzHoldButton extends StatelessWidget {
  const _PtzHoldButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.disabled,
    required this.onPressStart,
    required this.onPressEnd,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final bool disabled;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  @override
  Widget build(BuildContext context) {
    final enabled = !disabled;
    final fillColor = active
        ? const Color(0xFF43E39C)
        : Colors.white.withValues(alpha: enabled ? 0.1 : 0.045);
    final iconColor = active
        ? const Color(0xFF07110D)
        : Colors.white.withValues(alpha: enabled ? 0.9 : 0.34);

    return Tooltip(
      message: tooltip,
      child: Listener(
        onPointerDown: enabled ? (_) => onPressStart() : null,
        onPointerUp: enabled ? (_) => onPressEnd() : null,
        onPointerCancel: enabled ? (_) => onPressEnd() : null,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 58,
            height: 52,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active
                    ? const Color(0xFF95F5C6)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 30),
          ),
        ),
      ),
    );
  }
}

class _PtzTapButton extends StatelessWidget {
  const _PtzTapButton({
    required this.icon,
    required this.tooltip,
    required this.disabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = !disabled;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        style: IconButton.styleFrom(
          fixedSize: const Size(58, 52),
          backgroundColor: const Color(
            0xFFFFCE67,
          ).withValues(alpha: enabled ? 0.9 : 0.22),
          foregroundColor: const Color(0xFF1D1605),
          disabledForegroundColor: Colors.white30,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: Icon(icon, size: 27),
      ),
    );
  }
}
