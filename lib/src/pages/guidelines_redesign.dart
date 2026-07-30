part of '../../main.dart';

const _guideOrange = Color(0xFFFF6A19);
const _guideGreen = Color(0xFF48D66D);
const _guideBlue = Color(0xFF6794FF);
const _guideRed = Color(0xFFFF4D3A);
const _guideAmber = Color(0xFFFFAE00);

class _RedesignedGuide {
  const _RedesignedGuide(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.kind,
  );

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String kind;

  bool matches(String query) =>
      title.toLowerCase().contains(query) ||
      subtitle.toLowerCase().contains(query);
}

const _redesignedGuides = [
  _RedesignedGuide(
    'Confidence Scores',
    'Understand normal and abnormal scan confidence.',
    Icons.speed_rounded,
    _guideOrange,
    'confidence',
  ),
  _RedesignedGuide(
    'YOLOv8 Detection',
    'How the AI detects and classifies roosters.',
    Icons.memory_rounded,
    _guideBlue,
    'yolo',
  ),
  _RedesignedGuide(
    'Detection Basis',
    'Signs used for normal vs abnormal rooster detection.',
    Icons.center_focus_strong_rounded,
    _guideOrange,
    'basis',
  ),
  _RedesignedGuide(
    'Rooster Breeding Guide',
    'Basic breeding, nutrition, and care tips.',
    Icons.egg_alt_outlined,
    _guideOrange,
    'breeding',
  ),
  _RedesignedGuide(
    'Sensor Guide',
    'What each sensor monitors and why it matters.',
    Icons.memory_outlined,
    _guideBlue,
    'sensors',
  ),
  _RedesignedGuide(
    'Sensor Warning Signs',
    'What warnings mean and what action to take.',
    Icons.warning_amber_rounded,
    _guideRed,
    'warnings',
  ),
];

class _RedesignedGuidesHome extends StatelessWidget {
  const _RedesignedGuidesHome({
    required this.controller,
    required this.session,
    required this.searchController,
    required this.guides,
    required this.onSearchChanged,
  });

  final AppController controller;
  final Session session;
  final TextEditingController searchController;
  final List<_RedesignedGuide> guides;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 82,
        title: const Row(
          children: [
            _GuideBrandMark(),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Roostify',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                Text(
                  'Smart Rooster Monitoring',
                  style: TextStyle(color: _guideOrange, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'View alerts',
            onPressed: () {
              final user = controller.userByUsername(session.user.username)!;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AlertsPage(alerts: user.monitor.alerts),
                ),
              );
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const Text(
            'Guides',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'Learn how detection, sensors, and rooster care work.',
            style: TextStyle(color: context.appColors.mutedText, height: 1.4),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search guides...',
              prefixIcon: Icon(Icons.search_rounded),
              suffixIcon: Icon(Icons.filter_alt_outlined, color: _guideOrange),
            ),
          ),
          const SizedBox(height: 18),
          if (guides.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No guides found.')),
            )
          else
            for (var index = 0; index < guides.length; index++)
              _GuideIndexRow(
                number: index + 1,
                guide: guides[index],
                onTap: () => _openRedesignedGuide(
                  context,
                  guides[index],
                  controller,
                  session,
                ),
              ),
        ],
      ),
    );
  }
}

class _GuideBrandMark extends StatelessWidget {
  const _GuideBrandMark();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(13),
    child: Image.asset(
      'assets/app_icon_square.png',
      width: 48,
      height: 48,
      fit: BoxFit.cover,
    ),
  );
}

class _GuideIndexRow extends StatelessWidget {
  const _GuideIndexRow({
    required this.number,
    required this.guide,
    required this.onTap,
  });

  final int number;
  final _RedesignedGuide guide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _GuideCard(
    margin: const EdgeInsets.only(bottom: 10),
    onTap: onTap,
    child: Row(
      children: [
        _GuideIcon(icon: guide.icon, color: guide.color, size: 62),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$number. ${guide.title}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                guide.subtitle,
                style: TextStyle(
                  color: context.appColors.mutedText,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Text('Read more', style: TextStyle(color: _guideOrange)),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}

void _openRedesignedGuide(
  BuildContext context,
  _RedesignedGuide guide,
  AppController controller,
  Session session,
) {
  final page = switch (guide.kind) {
    'confidence' => const _ConfidenceScoresGuidePage(),
    'yolo' => const _YoloGuidePage(),
    'basis' => const _DetectionBasisGuidePage(),
    'breeding' => const _BreedingRedesignGuidePage(),
    'sensors' => _SensorRedesignGuidePage(controller: controller),
    _ => const _SensorWarningsGuidePage(),
  };
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

class _GuideScaffold extends StatelessWidget {
  const _GuideScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Theme(
    data: buildAppTheme(Brightness.dark),
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        children: [
          Row(
            children: [
              _GuideIcon(icon: icon, color: _guideOrange, size: 68),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.appColors.mutedText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    ),
  );
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.child,
    this.margin,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderColor ?? context.appColors.border),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

class _GuideIcon extends StatelessWidget {
  const _GuideIcon({required this.icon, required this.color, this.size = 54});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      shape: BoxShape.circle,
      border: Border.all(color: color.withValues(alpha: .5)),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: .14), blurRadius: 18),
      ],
    ),
    child: Icon(icon, color: color, size: size * .48),
  );
}

class _ConfidenceScoresGuidePage extends StatelessWidget {
  const _ConfidenceScoresGuidePage();

  @override
  Widget build(BuildContext context) => _GuideScaffold(
    title: 'Confidence Scores',
    subtitle: 'How to understand normal and abnormal scan confidence.',
    icon: Icons.speed_rounded,
    children: [
      _GuideCard(
        child: Row(
          children: [
            const Expanded(
              child: _ScoreBlock(
                title: 'Normal Confidence',
                value: '92%',
                label: 'Healthy',
                color: _guideGreen,
              ),
            ),
            Container(width: 1, height: 115, color: const Color(0xFF30394B)),
            const Expanded(
              child: _ScoreBlock(
                title: 'Abnormal Confidence',
                value: '18%',
                label: 'Low Risk',
                color: _guideOrange,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      const _GuideInfoRow(
        icon: Icons.info_outline_rounded,
        title: 'What confidence means',
        text:
            'Confidence shows how certain the AI is about its prediction based on the scan.',
      ),
      const SizedBox(height: 20),
      const _GuideSectionLabel('How to read results'),
      _ConfidenceRangeCard(
        range: '90–100%',
        title: 'Very strong result',
        text: 'You can trust the result.',
        color: _guideGreen,
        icon: Icons.verified_user_outlined,
      ),
      _ConfidenceRangeCard(
        range: '70–89%',
        title: 'Likely result',
        text: 'Verify the rooster is clear.',
        color: _guideAmber,
        icon: Icons.search_rounded,
      ),
      _ConfidenceRangeCard(
        range: 'Below 70%',
        title: 'Rescan with better angle or lighting',
        text: 'Low confidence means the AI needs a clearer image.',
        color: _guideRed,
        icon: Icons.warning_amber_rounded,
      ),
      const SizedBox(height: 14),
      const _GuideSectionLabel('Tips for accurate scanning'),
      const _TipsCard(),
    ],
  );
}

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({
    required this.title,
    required this.value,
    required this.label,
    required this.color,
  });
  final String title;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _GuideIcon(icon: Icons.speed_rounded, color: color, size: 62),
      const SizedBox(height: 8),
      Text(title, textAlign: TextAlign.center),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 25,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(label, style: TextStyle(color: color)),
    ],
  );
}

class _ConfidenceRangeCard extends StatelessWidget {
  const _ConfidenceRangeCard({
    required this.range,
    required this.title,
    required this.text,
    required this.color,
    required this.icon,
  });
  final String range;
  final String title;
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _GuideCard(
    margin: const EdgeInsets.only(bottom: 2),
    onTap: () => _showGuideExplanation(context, title, text),
    child: Row(
      children: [
        Container(
          width: 105,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: .7)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  range,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 19),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(text, style: TextStyle(color: context.appColors.mutedText)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();
  @override
  Widget build(BuildContext context) => const _GuideCard(
    child: Column(
      children: [
        _TipRow(Icons.light_mode_outlined, 'Use good natural lighting.'),
        _TipRow(
          Icons.egg_alt_outlined,
          'Make sure the full rooster is visible.',
        ),
        _TipRow(Icons.center_focus_strong, 'Avoid blur and use a clear angle.'),
        _TipRow(
          Icons.pan_tool_outlined,
          'Keep the camera steady while scanning.',
        ),
      ],
    ),
  );
}

class _TipRow extends StatelessWidget {
  const _TipRow(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(icon, color: _guideOrange),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: context.appColors.mutedText),
          ),
        ),
      ],
    ),
  );
}

class _YoloGuidePage extends StatelessWidget {
  const _YoloGuidePage();
  @override
  Widget build(BuildContext context) => _GuideScaffold(
    title: 'YOLOv8 Detection',
    subtitle: 'How the AI detects and classifies roosters.',
    icon: Icons.memory_rounded,
    children: [
      const _GuideInfoRow(
        icon: Icons.memory_rounded,
        title: 'Fast object detection',
        text:
            'YOLOv8 finds the rooster in each camera frame and classifies it in real time.',
        color: _guideBlue,
      ),
      const SizedBox(height: 20),
      const _GuideSectionLabel('How it works'),
      const Row(
        children: [
          Expanded(child: _ProcessStep(1, Icons.center_focus_strong, 'Detect')),
          SizedBox(width: 7),
          Expanded(child: _ProcessStep(2, Icons.search, 'Analyze')),
          SizedBox(width: 7),
          Expanded(child: _ProcessStep(3, Icons.psychology, 'Classify')),
          SizedBox(width: 7),
          Expanded(child: _ProcessStep(4, Icons.speed, 'Score')),
        ],
      ),
      const SizedBox(height: 22),
      const _GuideSectionLabel('Why YOLOv8 is used'),
      const _FeatureRow(
        Icons.bolt_rounded,
        'Fast detection',
        'Optimized for speed and efficiency.',
      ),
      const _FeatureRow(
        Icons.videocam_outlined,
        'Real-time performance',
        'Works on CCTV and phone cameras.',
      ),
      const _FeatureRow(
        Icons.gps_fixed_rounded,
        'Accurate localization',
        'Finds the rooster with a bounding box.',
      ),
      const _FeatureRow(
        Icons.trending_up_rounded,
        'Reliable monitoring',
        'Consistent results across different environments.',
      ),
    ],
  );
}

class _ProcessStep extends StatelessWidget {
  const _ProcessStep(this.number, this.icon, this.label);
  final int number;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => _GuideCard(
    child: Column(
      children: [
        Text(
          '$number',
          style: const TextStyle(
            color: _guideOrange,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Icon(icon, color: _guideOrange, size: 30),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _DetectionBasisGuidePage extends StatelessWidget {
  const _DetectionBasisGuidePage();
  static const normal = [
    'Balanced standing',
    'Head held high',
    'Alert eyes',
    'Smooth walking',
    'Active eating or drinking',
    'Grooming or wing stretching',
  ];
  static const abnormal = [
    'Drooped wings',
    'Limping',
    'Crouched posture',
    'Low activity',
    'Poor balance or head tilt',
    'Open-mouth breathing',
    'Reduced appetite',
  ];

  @override
  Widget build(BuildContext context) => _GuideScaffold(
    title: 'Detection Basis',
    subtitle: 'Signs used to detect normal and abnormal roosters.',
    icon: Icons.center_focus_strong,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 500;
          final cards = [
            _SignsCard(
              title: 'Normal Signs',
              signs: normal,
              color: _guideGreen,
              icon: Icons.check_circle_outline,
            ),
            _SignsCard(
              title: 'Abnormal Signs',
              signs: abnormal,
              color: _guideRed,
              icon: Icons.warning_amber_rounded,
            ),
          ];
          return compact
              ? Column(
                  children: [
                    cards.first,
                    const SizedBox(height: 10),
                    cards.last,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards.first),
                    const SizedBox(width: 10),
                    Expanded(child: cards.last),
                  ],
                );
        },
      ),
      const SizedBox(height: 12),
      const _GuideInfoRow(
        icon: Icons.camera_alt_outlined,
        title: 'Visible behavior matters',
        text:
            'Roostify analyzes visible posture and behavior captured by the camera.',
      ),
    ],
  );
}

class _SignsCard extends StatelessWidget {
  const _SignsCard({
    required this.title,
    required this.signs,
    required this.color,
    required this.icon,
  });
  final String title;
  final List<String> signs;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => _GuideCard(
    borderColor: color.withValues(alpha: .45),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final sign in signs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(width: 10),
                Expanded(child: Text(sign)),
              ],
            ),
          ),
      ],
    ),
  );
}

class _BreedingRedesignGuidePage extends StatelessWidget {
  const _BreedingRedesignGuidePage();
  static const sections = [
    (
      '1. Choose healthy breeders',
      'Active behavior\nBright eyes and clean feathers\nGood body condition',
      Icons.health_and_safety_outlined,
    ),
    (
      '2. Housing',
      'Clean, dry coop\nAdequate space\nGood ventilation and lighting',
      Icons.home_work_outlined,
    ),
    (
      '3. Nutrition',
      'Balanced feed\nClean fresh water\nVitamins and minerals',
      Icons.rice_bowl_outlined,
    ),
    (
      '4. Breeding care',
      'Monitor mating\nSeparate injured birds\nRecord lineage and hatch dates',
      Icons.egg_alt_outlined,
    ),
  ];
  @override
  Widget build(BuildContext context) => _GuideScaffold(
    title: 'Rooster Breeding Guide',
    subtitle: 'Basic breeding, nutrition, and care tips.',
    icon: Icons.egg_alt_outlined,
    children: [
      for (final section in sections)
        _FeatureRow(
          section.$3,
          section.$1,
          section.$2.replaceAll('\n', ' • '),
          onTap: () => _showGuideExplanation(context, section.$1, section.$2),
        ),
      const _GuideInfoRow(
        icon: Icons.notifications_none_rounded,
        title: 'Reminder',
        text:
            'Regular observation and good management help produce healthy, strong roosters.',
      ),
    ],
  );
}

class _SensorRedesignGuidePage extends StatelessWidget {
  const _SensorRedesignGuidePage({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final connected =
        controller.sensorConnectionStatus ==
        Esp32SensorConnectionStatus.connected;
    return _GuideScaffold(
      title: 'Sensor Guide',
      subtitle: 'What each sensor monitors and why it matters.',
      icon: Icons.sensors_outlined,
      children: [
        _GuideInfoRow(
          icon: Icons.memory_rounded,
          title: connected ? 'ESP32 Connected' : 'ESP32 Offline',
          text: connected
              ? 'Your ESP32 is online and streaming sensor data.'
              : 'Connect the ESP32 from the Dashboard to stream live data.',
          color: connected ? _guideGreen : _guideRed,
        ),
        const SizedBox(height: 12),
        const _FeatureRow(
          Icons.thermostat_rounded,
          'Temperature',
          'Monitors coop heat levels to reduce heat stress. • °C',
        ),
        const _FeatureRow(
          Icons.water_drop_outlined,
          'Humidity',
          'Tracks moisture and helps ventilation decisions. • %',
          color: _guideBlue,
        ),
        const _FeatureRow(
          Icons.air_rounded,
          'Air Quality',
          'Monitors polluted or unsafe air in the coop. • AQI',
        ),
        const _FeatureRow(
          Icons.memory_outlined,
          'ESP32 Module',
          'Sends sensor data to the app in real time. • MCU',
          color: _guideBlue,
        ),
      ],
    );
  }
}

class _SensorWarningsGuidePage extends StatelessWidget {
  const _SensorWarningsGuidePage();
  static const rows = [
    (
      'High Temperature',
      'The temperature is higher than the safe range.',
      'Improve cooling and airflow.',
      Icons.thermostat_rounded,
      _guideRed,
    ),
    (
      'High Humidity',
      'Humidity is too high for comfort.',
      'Dry bedding and improve ventilation.',
      Icons.water_drop_outlined,
      _guideOrange,
    ),
    (
      'Poor Air Quality',
      'Unsafe air may affect rooster health.',
      'Clean the coop and increase fresh air.',
      Icons.air_rounded,
      _guideAmber,
    ),
    (
      'Sensor Disconnected',
      'The sensor is offline or not communicating.',
      'Check power, wiring, and connection.',
      Icons.link_off_rounded,
      _guideRed,
    ),
  ];
  @override
  Widget build(BuildContext context) => _GuideScaffold(
    title: 'Sensor Warning Signs',
    subtitle: 'What warnings mean and what action to take.',
    icon: Icons.warning_amber_rounded,
    children: [
      const _GuideCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _WarningLevel('Danger', 'Immediate action', _guideRed),
            _WarningLevel('Caution', 'Monitor closely', _guideOrange),
            _WarningLevel('Warning', 'Take action', _guideAmber),
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (final row in rows)
        _FeatureRow(
          row.$4,
          row.$1,
          '${row.$2}  Action: ${row.$3}',
          color: row.$5,
          onTap: () => _showGuideExplanation(context, row.$1, row.$3),
        ),
      const _GuideInfoRow(
        icon: Icons.health_and_safety_outlined,
        title: 'Stay alert, keep them healthy.',
        text:
            'Warnings help you act early and protect roosters from stress and illness.',
      ),
    ],
  );
}

class _WarningLevel extends StatelessWidget {
  const _WarningLevel(this.title, this.text, this.color);
  final String title;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Flexible(
    child: Column(
      children: [
        Icon(Icons.warning_amber_rounded, color: color, size: 30),
        Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.appColors.mutedText, fontSize: 10),
        ),
      ],
    ),
  );
}

class _GuideInfoRow extends StatelessWidget {
  const _GuideInfoRow({
    required this.icon,
    required this.title,
    required this.text,
    this.color = _guideOrange,
  });
  final IconData icon;
  final String title;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => _GuideCard(
    child: Row(
      children: [
        _GuideIcon(icon: icon, color: color, size: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  color: context.appColors.mutedText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow(
    this.icon,
    this.title,
    this.text, {
    this.color = _guideOrange,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String text;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => _GuideCard(
    margin: const EdgeInsets.only(bottom: 8),
    onTap: onTap,
    child: Row(
      children: [
        _GuideIcon(icon: icon, color: color, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(
                text,
                style: TextStyle(
                  color: context.appColors.mutedText,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null) const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}

class _GuideSectionLabel extends StatelessWidget {
  const _GuideSectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    ),
  );
}

void _showGuideExplanation(BuildContext context, String title, String text) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}
