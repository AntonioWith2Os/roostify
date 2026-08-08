part of '../../main.dart';

/// Shows every connected live camera at once in a fullscreen landscape
/// mosaic. This is a lightweight viewing-only mode — no recording, YOLOv8
/// inspection, or PTZ controls — so it doesn't duplicate the heavier work
/// each camera's own card already does on the CCTV page underneath it.
class MultiCameraFullscreenPage extends StatefulWidget {
  const MultiCameraFullscreenPage({super.key, required this.streams});

  final List<LiveCctvStream> streams;

  @override
  State<MultiCameraFullscreenPage> createState() =>
      _MultiCameraFullscreenPageState();
}

class _MultiCameraFullscreenPageState extends State<MultiCameraFullscreenPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  int _crossAxisCountFor(int streamCount) {
    return streamCount <= 1 ? 1 : 2;
  }

  @override
  Widget build(BuildContext context) {
    final streams = widget.streams;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: streams.isEmpty
                  ? const Center(
                      child: Text(
                        'No live cameras connected.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _crossAxisCountFor(streams.length),
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        childAspectRatio: 16 / 9,
                      ),
                      itemCount: streams.length,
                      itemBuilder: (context, index) => _LiveMosaicTile(
                        key: ValueKey(streams[index].id),
                        stream: streams[index],
                        displayLabel: cctvStreamDisplayLabel(
                          index,
                          streams.length,
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: Colors.black.withValues(alpha: 0.46),
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  tooltip: 'Exit combined view',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveMosaicTile extends StatefulWidget {
  const _LiveMosaicTile({
    super.key,
    required this.stream,
    required this.displayLabel,
  });

  final LiveCctvStream stream;
  final String displayLabel;

  @override
  State<_LiveMosaicTile> createState() => _LiveMosaicTileState();
}

class _LiveMosaicTileState extends State<_LiveMosaicTile> {
  FijkPlayer? _player;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final player = FijkPlayer();
    _player = player;
    try {
      final options = FijkOption()
        ..setPlayerOption('framedrop', 1)
        ..setPlayerOption('infbuf', 1)
        ..setPlayerOption('packet-buffering', 0)
        ..setFormatOption('max_delay', 2000 * 1000)
        ..setFormatOption('stimeout', 5000000)
        ..setFormatOption('reconnect', 1)
        ..setFormatOption('rtsp_transport', 'tcp');
      await player.applyOptions(options);
      if (!mounted) {
        return;
      }
      await player.setDataSource(widget.stream.streamUrl, autoPlay: true);
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    }
  }

  @override
  void dispose() {
    final player = _player;
    if (player != null) {
      unawaited(player.release().catchError((_) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (player != null)
            FijkView(
              player: player,
              fit: FijkFit.contain,
              fs: false,
              color: Colors.black,
              panelBuilder: (_, _, _, _, _) => const SizedBox.shrink(),
            )
          else
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white54,
                ),
              ),
            ),
          if (_error != null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Could not open this stream.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.displayLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
