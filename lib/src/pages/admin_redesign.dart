part of '../../main.dart';

const _adminOrange = _appAccent;
const _adminGreen = Color(0xFF25C778);

List<BoxShadow> _adminCardShadows(BuildContext context) {
  if (Theme.of(context).brightness == Brightness.dark) return const [];
  return const [
    BoxShadow(color: Color(0x1407152F), blurRadius: 12, offset: Offset(0, 4)),
  ];
}

class AdminRedesignShell extends StatefulWidget {
  const AdminRedesignShell({
    super.key,
    required this.controller,
    required this.session,
  });

  final AppController controller;
  final Session session;

  @override
  State<AdminRedesignShell> createState() => _AdminRedesignShellState();
}

class _AdminRedesignShellState extends State<AdminRedesignShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _NewAdminDashboard(controller: widget.controller, goTo: _goTo),
      _NewAdminUsers(controller: widget.controller),
      _NewAdminCctv(controller: widget.controller),
      _NewAdminInbox(controller: widget.controller),
      ProfilePage(controller: widget.controller, session: widget.session),
    ];
    const items = [
      (Icons.grid_view_rounded, 'Dashboard'),
      (Icons.group_outlined, 'Users'),
      (Icons.videocam_outlined, 'CCTV'),
      (Icons.mail_outline_rounded, 'Inbox'),
      (Icons.person_outline_rounded, 'Profile'),
    ];

    return Theme(
      data: buildAppTheme(Theme.of(context).brightness).copyWith(
        scaffoldBackgroundColor: context.appColors.background,
        cardColor: context.appColors.surface,
        dividerColor: context.appColors.border,
        appBarTheme: AppBarTheme(
          backgroundColor: context.appColors.background,
          foregroundColor: context.appColors.text,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
        ),
        bottomNavigationBar: AnimatedBuilder(
          animation: widget.controller,
          builder: (_, _) => SafeArea(
            top: false,
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: context.appColors.surface,
                border: Border(
                  top: BorderSide(color: context.appColors.border),
                ),
              ),
              child: Row(
                children: List.generate(items.length, (i) {
                  final selected = i == _index;
                  return Expanded(
                    child: Semantics(
                      button: true,
                      selected: selected,
                      // Distinct from the plain "Dashboard" page heading
                      // text elsewhere on screen: identical accessible
                      // labels on two different elements make them
                      // indistinguishable to screen-reader users.
                      label: '${items[i].$2} tab',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () => _goTo(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  items[i].$1,
                                  color: selected
                                      ? _adminOrange
                                      : context.appColors.mutedText,
                                  size: 22,
                                ),
                                if (i == 3 &&
                                    widget.controller.unreadSupportCount > 0)
                                  Positioned(
                                    right: -8,
                                    top: -5,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE52D45),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${widget.controller.unreadSupportCount}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              items[i].$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected
                                    ? _adminOrange
                                    : context.appColors.mutedText,
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goTo(int value) => setState(() => _index = value);
}

class _NewAdminDashboard extends StatefulWidget {
  const _NewAdminDashboard({required this.controller, required this.goTo});
  final AppController controller;
  final ValueChanged<int> goTo;

  @override
  State<_NewAdminDashboard> createState() => _NewAdminDashboardState();
}

class _NewAdminDashboardState extends State<_NewAdminDashboard> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final goTo = widget.goTo;
    final users = controller.farmUsers;
    final warningAlerts = users
        .expand(
          (u) =>
              u.monitor.alerts.where((a) => a.severity != AlertSeverity.info),
        )
        .toList();
    final alerts = warningAlerts.length;
    final connected = users.where((u) => u.cameraAccessEnabled).length;
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) => SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/roostify_logo_transparent.png',
                      width: 42,
                      height: 42,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Roostify',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Smart Rooster Farming Using IoT',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Admin',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 15),
                    IconButton(
                      tooltip: 'View alerts',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => AlertsPage(alerts: warningAlerts),
                        ),
                      ),
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            size: 25,
                          ),
                          if (alerts > 0)
                            Positioned(
                              right: -6,
                              top: -5,
                              child: _CountBadge('$alerts'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Text(
                  'Dashboard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.15,
                children: [
                  _SummaryTile(
                    icon: Icons.people_outline_rounded,
                    label: 'Registered Users',
                    value: '${users.length}',
                    color: _adminOrange,
                    onTap: () => goTo(1),
                  ),
                  _SummaryTile(
                    icon: Icons.verified_user_outlined,
                    label: 'Active Users',
                    value: '$connected',
                    color: const Color(0xFF58D34F),
                    onTap: () => goTo(1),
                  ),
                  _SummaryTile(
                    icon: Icons.videocam_outlined,
                    label: 'Connected CCTV\nUnits',
                    value: '${controller.totalCctvCount}',
                    color: const Color(0xFF48A8F8),
                    onTap: () => goTo(2),
                  ),
                  _SummaryTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Open Support\nThreads',
                    value: '${controller.openSupportCount}',
                    color: const Color(0xFFA65CF0),
                    onTap: () => goTo(3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Color(0xFFE52D45),
      shape: BoxShape.circle,
    ),
    child: Text(
      value,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label, value;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: context.appColors.border),
        boxShadow: _adminCardShadows(context),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.05,
                    color: context.appColors.mutedText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _NewAdminUsers extends StatefulWidget {
  const _NewAdminUsers({required this.controller});
  final AppController controller;
  @override
  State<_NewAdminUsers> createState() => _NewAdminUsersState();
}

enum _CameraFilter { all, active, limited }

class _NewAdminUsersState extends State<_NewAdminUsers> {
  final search = TextEditingController();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _farm = TextEditingController();
  final _location = TextEditingController();
  final _password = TextEditingController();
  _CameraFilter filter = _CameraFilter.all;
  bool _formOpen = true;
  bool _passwordVisible = false;
  String? _error;

  @override
  void dispose() {
    search.dispose();
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _farm.dispose();
    _location.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final createdName = _name.text.trim();
    final createdUsername = _username.text.trim();
    final temporaryPassword = _password.text.trim().isEmpty
        ? 'Farm1234'
        : _password.text.trim();
    final ok = await widget.controller.addUser(
      username: _username.text,
      displayName: _name.text,
      email: _email.text,
      farmName: _farm.text,
      contactNumber: _phone.text,
      address: _location.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = widget.controller.lastError);
      return;
    }
    for (final field in [
      _name,
      _username,
      _email,
      _phone,
      _farm,
      _location,
      _password,
    ]) {
      field.clear();
    }
    setState(() {
      _error = null;
      _formOpen = false;
    });
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UserCreatedDialog(
        displayName: createdName,
        username: createdUsername,
        temporaryPassword: temporaryPassword,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (_, _) {
      final q = search.text.toLowerCase();
      final users = widget.controller.farmUsers
          .where(
            (u) =>
                u.displayName.toLowerCase().contains(q) ||
                u.username.toLowerCase().contains(q) ||
                u.farmName.toLowerCase().contains(q),
          )
          .where((u) {
            switch (filter) {
              case _CameraFilter.all:
                return true;
              case _CameraFilter.active:
                return u.cameraAccessEnabled;
              case _CameraFilter.limited:
                return !u.cameraAccessEnabled;
            }
          })
          .toList();
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
          children: [
            const Text(
              'Users',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: _SearchBox(
                      controller: search,
                      hint: 'Search users...',
                      onChanged: (_) => setState(() {}),
                      filterButton: PopupMenuButton<_CameraFilter>(
                        tooltip: 'Filter users',
                        icon: Icon(
                          Icons.filter_alt_outlined,
                          size: 18,
                          color: filter == _CameraFilter.all
                              ? context.appColors.mutedText
                              : _adminOrange,
                        ),
                        onSelected: (value) => setState(() => filter = value),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: _CameraFilter.all,
                            child: Text('All users'),
                          ),
                          PopupMenuItem(
                            value: _CameraFilter.active,
                            child: Text('Active'),
                          ),
                          PopupMenuItem(
                            value: _CameraFilter.limited,
                            child: Text('Inactive'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _adminOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () => setState(() => _formOpen = true),
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text(
                      'Add User',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (users.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No users match this search or filter.',
                    style: TextStyle(color: context.appColors.mutedText),
                  ),
                ),
              )
            else
              ...users.map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _UserRow(user: user, controller: widget.controller),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? context.appColors.surface
                    : const Color(0xFFFFFBF2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? context.appColors.border
                      : const Color(0xFFE6A52B).withValues(alpha: .42),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFFE6A52B),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Password is locked for 7 days.\nUser can change password after the lock period.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: context.appColors.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _InlineAddUserForm(
              open: _formOpen,
              onToggle: () => setState(() => _formOpen = !_formOpen),
              name: _name,
              username: _username,
              email: _email,
              phone: _phone,
              farm: _farm,
              location: _location,
              password: _password,
              passwordVisible: _passwordVisible,
              onTogglePassword: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
              error: _error,
              onSubmit: _createAccount,
            ),
          ],
        ),
      );
    },
  );
}

class _InlineAddUserForm extends StatelessWidget {
  const _InlineAddUserForm({
    required this.open,
    required this.onToggle,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.farm,
    required this.location,
    required this.password,
    required this.passwordVisible,
    required this.onTogglePassword,
    required this.error,
    required this.onSubmit,
  });
  final bool open, passwordVisible;
  final VoidCallback onToggle, onTogglePassword, onSubmit;
  final String? error;
  final TextEditingController name,
      username,
      email,
      phone,
      farm,
      location,
      password;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.appColors.border),
      boxShadow: _adminCardShadows(context),
    ),
    child: Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add New User',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
                Icon(
                  open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _CompactUserField(
                  controller: name,
                  label: 'Full Name',
                  hint: 'e.g. Liza Ramos',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactUserField(
                  controller: username,
                  label: 'Username',
                  hint: 'e.g. lizaramos',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _CompactUserField(
                  controller: email,
                  label: 'Email',
                  hint: 'name@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactUserField(
                  controller: phone,
                  label: 'Contact Number',
                  hint: 'e.g. 0917 123 4567',
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _CompactUserField(
                  controller: farm,
                  label: 'Farm Name',
                  hint: 'e.g. Ramos Native Farm',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactUserField(
                  controller: location,
                  label: 'Location',
                  hint: 'City, Province',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _CompactUserField(
                  controller: password,
                  label: 'Temporary Password',
                  hint: 'Enter password',
                  obscureText: !passwordVisible,
                  suffix: IconButton(
                    tooltip: passwordVisible
                        ? 'Hide password'
                        : 'Show password',
                    onPressed: onTogglePassword,
                    icon: Icon(
                      passwordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(child: _CompactRoleField()),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                error!,
                style: const TextStyle(color: Color(0xFFFF6B72), fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _adminOrange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: onSubmit,
                child: const Text(
                  'Create Account',
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _UserCreatedDialog extends StatelessWidget {
  const _UserCreatedDialog({
    required this.displayName,
    required this.username,
    required this.temporaryPassword,
  });
  final String displayName, username, temporaryPassword;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 34),
    backgroundColor: context.appColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
      side: BorderSide(color: context.appColors.border),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _adminGreen.withValues(alpha: .14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _adminGreen.withValues(alpha: .55),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: _adminGreen,
                size: 43,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'User Created Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '$displayName can now sign in to Roostify.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: context.appColors.mutedText,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.appColors.border),
              ),
              child: Column(
                children: [
                  _CreatedCredentialRow(label: 'Username', value: username),
                  Divider(height: 18, color: context.appColors.border),
                  _CreatedCredentialRow(
                    label: 'Temporary Password',
                    value: temporaryPassword,
                    obscured: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE5A326).withValues(alpha: .09),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: const Color(0xFFE5A326).withValues(alpha: .35),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_clock_outlined,
                    color: Color(0xFFE5A326),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The temporary password is locked for 7 days. Share these credentials securely with the new user.',
                      style: TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _adminOrange,
                minimumSize: const Size.fromHeight(43),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                side: const BorderSide(color: _adminOrange),
              ),
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(
                    text:
                        'Roostify account\nUsername: $username\nTemporary password: $temporaryPassword',
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Credentials copied.')),
                );
              },
              icon: const Icon(Icons.copy_outlined, size: 19),
              label: const Text('Copy Credentials'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _adminOrange,
                minimumSize: const Size.fromHeight(45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CreatedCredentialRow extends StatelessWidget {
  const _CreatedCredentialRow({
    required this.label,
    required this.value,
    this.obscured = false,
  });
  final String label, value;
  final bool obscured;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.appColors.mutedText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              obscured
                  ? List.filled(value.length.clamp(6, 16), '•').join()
                  : value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      if (obscured)
        IconButton(
          tooltip: 'Copy password',
          onPressed: () => Clipboard.setData(ClipboardData(text: value)),
          icon: const Icon(Icons.copy_outlined, size: 17),
        ),
    ],
  );
}

class _CompactUserField extends StatelessWidget {
  const _CompactUserField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });
  final TextEditingController controller;
  final String label, hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.fromLTRB(8, 5, 4, 2),
    decoration: BoxDecoration(
      color: context.appColors.background,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: context.appColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.appColors.mutedText),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 12,
              color: context.appColors.mutedText,
            ),
            suffixIcon: suffix,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 30,
              maxHeight: 30,
            ),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ],
    ),
  );
}

class _CompactRoleField extends StatelessWidget {
  const _CompactRoleField();
  @override
  Widget build(BuildContext context) => Container(
    height: 55,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: context.appColors.background,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: context.appColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Role',
          style: TextStyle(fontSize: 11, color: context.appColors.mutedText),
        ),
        const Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text('Farm Manager', style: TextStyle(fontSize: 12)),
              ),
              Icon(Icons.keyboard_arrow_down, size: 16),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EditAdminUserPage extends StatefulWidget {
  const _EditAdminUserPage({required this.controller, required this.username});
  final AppController controller;
  final String username;
  @override
  State<_EditAdminUserPage> createState() => _EditAdminUserPageState();
}

class _EditAdminUserPageState extends State<_EditAdminUserPage> {
  late final AppUser _user = widget.controller.userByUsername(widget.username)!;
  late final _name = TextEditingController(text: _user.displayName);
  late final _email = TextEditingController(text: _user.email);
  late final _farm = TextEditingController(text: _user.farmName);
  late final _phone = TextEditingController(text: _user.contactNumber);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _farm.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    widget.controller.updateProfileDetails(
      _user.username,
      displayName: _name.text,
      email: _email.text,
      farmName: _farm.text,
      contactNumber: _phone.text,
      address: _user.address,
      facebookContact: _user.facebookContact,
      shortBio: _user.shortBio,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildAppTheme(Theme.of(context).brightness).copyWith(
        scaffoldBackgroundColor: context.appColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: context.appColors.background,
          foregroundColor: context.appColors.text,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'Edit User',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.appColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.appColors.border),
                ),
                child: Column(
                  children: [
                    _AddUserField(
                      controller: _name,
                      label: 'Full Name',
                      hint: 'Enter full name',
                      icon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                    ),
                    _AddUserField(
                      controller: _email,
                      label: 'Email Address',
                      hint: 'Enter email address',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    _AddUserField(
                      controller: _farm,
                      label: 'Farm / Business Name',
                      hint: 'Enter farm or business name',
                      icon: Icons.business_center_outlined,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                    ),
                    _AddUserField(
                      controller: _phone,
                      label: 'Phone Number (Optional)',
                      hint: 'Enter phone number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _adminOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _save,
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddUserField extends StatelessWidget {
  const _AddUserField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.appColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Icon(icon, color: context.appColors.mutedText, size: 22),
          ),
          Container(width: 1, color: context.appColors.border),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 4, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.text,
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      textInputAction: textInputAction,
                      textCapitalization: textCapitalization,
                      onSubmitted: onSubmitted,
                      style: TextStyle(
                        color: context.appColors.text,
                        fontSize: 18,
                      ),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: TextStyle(
                          color: context.appColors.mutedText,
                          fontSize: 17,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.filterButton,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final Widget? filterButton;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    style: TextStyle(color: context.appColors.text, fontSize: 16),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.appColors.mutedText, fontSize: 15),
      prefixIcon: Icon(
        Icons.search,
        size: 22,
        color: context.appColors.mutedText,
      ),
      suffixIcon:
          filterButton ??
          Icon(
            Icons.filter_alt_outlined,
            size: 22,
            color: context.appColors.mutedText,
          ),
      filled: true,
      fillColor: context.appColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: context.appColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: context.appColors.border),
      ),
    ),
  );
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.controller});
  final AppUser user;
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final active = user.cameraAccessEnabled;
    final cctvCount = user.liveCctvStreams.isEmpty
        ? user.cctvs.length
        : user.liveCctvStreams.length;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .72),
        builder: (ctx) => _UserActions(user: user, controller: controller),
      ),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.appColors.border),
          boxShadow: _adminCardShadows(context),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: _adminOrange.withValues(alpha: .15),
              backgroundImage: user.avatarPath == null
                  ? null
                  : FileImage(File(user.avatarPath!)),
              child: user.avatarPath == null
                  ? Text(
                      user.displayName.isEmpty
                          ? '?'
                          : user.displayName[0].toUpperCase(),
                      style: const TextStyle(
                        color: _adminOrange,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '@${user.username}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${user.farmName.isEmpty ? 'Farm account' : user.farmName}${user.address.isEmpty ? '' : ' • ${user.address}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.videocam_outlined,
                        size: 12,
                        color: context.appColors.mutedText,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$cctvCount CCTV ${cctvCount == 1 ? 'Unit' : 'Units'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (active ? _adminGreen : Colors.grey).withValues(
                      alpha: .13,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: (active ? _adminGreen : Colors.grey).withValues(
                        alpha: .25,
                      ),
                    ),
                  ),
                  child: Text(
                    active ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      color: active ? _adminGreen : Colors.grey,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (user.tempPasswordIssued)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF388CE8).withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF388CE8).withValues(alpha: .25),
                      ),
                    ),
                    child: const Text(
                      '7 days remaining',
                      style: TextStyle(fontSize: 10, color: Color(0xFF66A8F0)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: context.appColors.mutedText,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserActions extends StatelessWidget {
  const _UserActions({required this.user, required this.controller});
  final AppUser user;
  final AppController controller;

  Future<void> _editUser(BuildContext context) async {
    final navigator = Navigator.of(context);
    navigator.pop();
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _EditAdminUserPage(controller: controller, username: user.username),
      ),
    );
  }

  Future<void> _resetPassword(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ResetPasswordDialog(controller: controller, user: user),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appColors.surfaceRaised,
        title: const Text('Remove user?'),
        content: Text(
          'This permanently removes ${user.displayName} (@${user.username}) '
          'and their support conversation history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5D65),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final removed = await controller.removeUser(user.username);
      if (!context.mounted) return;
      if (!removed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(controller.lastError ?? 'Unable to remove user.'),
          ),
        );
        return;
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => _buildDialog(context),
  );

  Widget _buildDialog(BuildContext context) {
    final cctvCount = user.liveCctvStreams.isEmpty
        ? user.cctvs.length
        : user.liveCctvStreams.length;
    final openThreads = controller.supportThreads
        .where((t) => t.username == user.username && !t.resolved)
        .length;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
      backgroundColor: context.appColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.appColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    color: _adminOrange,
                    size: 27,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'User Information',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 25),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: context.appColors.border),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: _adminOrange.withValues(
                              alpha: .15,
                            ),
                            backgroundImage: user.avatarPath == null
                                ? null
                                : FileImage(File(user.avatarPath!)),
                            child: user.avatarPath == null
                                ? Text(
                                    user.displayName.isEmpty
                                        ? '?'
                                        : user.displayName[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: _adminOrange,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '@${user.username}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.appColors.mutedText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _DialogStatus(
                                  label: user.cameraAccessEnabled
                                      ? 'ACTIVE'
                                      : 'INACTIVE',
                                  color: user.cameraAccessEnabled
                                      ? _adminGreen
                                      : Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: context.appColors.border),
                    _UserInfoRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: user.email.isEmpty ? 'Not provided' : user.email,
                    ),
                    _UserInfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Contact Number',
                      value: user.contactNumber.isEmpty
                          ? 'Not provided'
                          : user.contactNumber,
                    ),
                    _UserInfoRow(
                      icon: Icons.home_outlined,
                      label: 'Farm Name',
                      value: user.farmName.isEmpty
                          ? 'Farm account'
                          : user.farmName,
                    ),
                    _UserInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: user.address.isEmpty
                          ? 'Not provided'
                          : user.address,
                    ),
                    const _UserInfoRow(
                      icon: Icons.person_outline,
                      label: 'Role',
                      value: 'Farm Owner',
                    ),
                    _UserInfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Account Created',
                      value: user.firstLoginAt == null
                          ? 'Account active'
                          : _shortDate(user.firstLoginAt!),
                    ),
                    _UserInfoRow(
                      icon: Icons.schedule_outlined,
                      label: 'Last Login',
                      value: user.firstLoginAt == null
                          ? 'Not recorded'
                          : _shortDate(user.firstLoginAt!),
                    ),
                    _UserInfoRow(
                      icon: Icons.description_outlined,
                      label: 'Notes',
                      value: user.shortBio.isEmpty
                          ? 'No notes added.'
                          : user.shortBio,
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Account Overview',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _UserOverviewTile(
                      icon: Icons.videocam_outlined,
                      value: '$cctvCount',
                      label: 'CCTV Units',
                      color: const Color(0xFF438FE8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _UserOverviewTile(
                      icon: Icons.hub_outlined,
                      value: user.cameraAccessEnabled ? 'ESP32' : 'Offline',
                      label: 'Node Online',
                      color: _adminGreen,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _UserOverviewTile(
                      icon: Icons.chat_bubble_outline,
                      value: '$openThreads',
                      label: 'Open Threads',
                      color: const Color(0xFFA45DE0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: context.appColors.border),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 13),
                  title: const Text(
                    'Camera scan access',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    user.cameraAccessEnabled
                        ? 'This user can use phone camera detection.'
                        : 'Camera detection is disabled for this user.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appColors.mutedText,
                    ),
                  ),
                  value: user.cameraAccessEnabled,
                  activeThumbColor: _adminOrange,
                  onChanged: (_) =>
                      controller.toggleCameraAccess(user.username),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _adminOrange,
                  minimumSize: const Size.fromHeight(45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                onPressed: () => _editUser(context),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit User'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _adminOrange,
                  minimumSize: const Size.fromHeight(45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                  side: const BorderSide(color: _adminOrange),
                ),
                onPressed: () => _resetPassword(context),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Reset Password'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF5D65),
                  minimumSize: const Size.fromHeight(45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                  side: const BorderSide(color: Color(0xFFFF5D65)),
                ),
                onPressed: () => _confirmRemove(context),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove User'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.appColors.surfaceRaised,
                  foregroundColor: context.appColors.text,
                  minimumSize: const Size.fromHeight(45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _shortDate(DateTime value) =>
      '${value.month}/${value.day}/${value.year}';
}

class _UserInfoRow extends StatelessWidget {
  const _UserInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });
  final IconData icon;
  final String label, value;
  final bool last;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      border: last
          ? null
          : Border(bottom: BorderSide(color: context.appColors.border)),
    ),
    child: Row(
      children: [
        Container(
          width: 29,
          height: 29,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.appColors.surfaceRaised,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 17, color: context.appColors.mutedText),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.appColors.mutedText),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _UserOverviewTile extends StatelessWidget {
  const _UserOverviewTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    height: 63,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: context.appColors.border),
    ),
    child: Row(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: context.appColors.mutedText,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.controller, required this.user});
  final AppController controller;
  final AppUser user;
  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _password = TextEditingController();
  bool _visible = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await widget.controller.adminResetPassword(
      widget.user.username,
      _password.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = widget.controller.lastError);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appColors.surfaceRaised,
      title: Text('Reset password for ${widget.user.displayName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _password,
            obscureText: !_visible,
            // Not autofocused: requesting focus while showDialog()'s barrier
            // + fade/scale entrance transition is still animating races the
            // keyboard's own show animation for frame budget, which can drop
            // the soft keyboard mid-word.
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'New temporary password',
              suffixIcon: IconButton(
                tooltip: _visible ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _visible = !_visible),
                icon: Icon(
                  _visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFFF6B72), fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _adminOrange),
          onPressed: _submit,
          child: const Text('Reset'),
        ),
      ],
    );
  }
}

class _NewAdminCctv extends StatefulWidget {
  const _NewAdminCctv({required this.controller});
  final AppController controller;
  @override
  State<_NewAdminCctv> createState() => _NewAdminCctvState();
}

class _NewAdminCctvState extends State<_NewAdminCctv> {
  int? _selectedIndex;
  bool _byUser = false;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (_, _) {
      final entries = widget.controller.farmUsers
          .expand(
            (u) => u.liveCctvStreams.asMap().entries.map(
              (e) => (u, e.key, e.value),
            ),
          )
          .toList();
      bool isOnline((AppUser, int, LiveCctvStream) e) => e.$3.isOnline;
      final selectedIndex = _selectedIndex?.clamp(0, entries.length - 1);
      final selected = entries.isEmpty || selectedIndex == null
          ? null
          : entries[selectedIndex];

      Widget buildTile(int globalIndex) {
        final e = entries[globalIndex];
        return _AdminCameraTile(
          user: e.$1,
          index: e.$2,
          stream: e.$3,
          online: isOnline(e),
          selected: globalIndex == selectedIndex,
          onTap: () {
            setState(() => _selectedIndex = globalIndex);
            showDialog<void>(
              context: context,
              barrierColor: Colors.black.withValues(alpha: .72),
              builder: (_) => _CameraStreamDialog(
                user: e.$1,
                index: e.$2,
                stream: e.$3,
                online: isOnline(e),
                controller: widget.controller,
              ),
            );
          },
        );
      }

      Widget buildGrid(List<int> globalIndices) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: globalIndices.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 7,
          mainAxisSpacing: 7,
          childAspectRatio: .90,
        ),
        itemBuilder: (_, j) => buildTile(globalIndices[j]),
      );

      Widget cameraSection;
      if (entries.isEmpty) {
        cameraSection = Container(
          height: 180,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: context.appColors.border),
          ),
          child: Text(
            'No cameras connected',
            style: TextStyle(color: context.appColors.mutedText),
          ),
        );
      } else if (_byUser) {
        final grouped = <AppUser, List<int>>{};
        for (var i = 0; i < entries.length; i++) {
          grouped.putIfAbsent(entries[i].$1, () => []).add(i);
        }
        cameraSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final group in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
                child: Text(
                  '${group.key.displayName} · ${group.value.length} camera${group.value.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              buildGrid(group.value),
              const SizedBox(height: 10),
            ],
          ],
        );
      } else {
        cameraSection = buildGrid(List.generate(entries.length, (i) => i));
      }

      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 9, 8, 18),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'CCTV',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.controller.session?.user.isAdmin == true
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RecordingsPage(
                              currentUser: widget.controller.session!.user,
                            ),
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.cloud_outlined, size: 18),
                  label: const Text('Recordings'),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Container(
              height: 52,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: context.appColors.surfaceRaised,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _CctvTabButton(
                      label: 'All Cameras',
                      selected: !_byUser,
                      onTap: () => setState(() => _byUser = false),
                    ),
                  ),
                  Expanded(
                    child: _CctvTabButton(
                      label: 'By User',
                      selected: _byUser,
                      onTap: () => setState(() => _byUser = true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            cameraSection,
            if (selected != null) ...[
              const SizedBox(height: 8),
              _AdminCameraDetail(
                user: selected.$1,
                index: selected.$2,
                stream: selected.$3,
                online: isOnline(selected),
                controller: widget.controller,
                onClose: () => setState(() => _selectedIndex = null),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _CctvTabButton extends StatelessWidget {
  const _CctvTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _adminOrange : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : context.appColors.text,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    ),
  );
}

class _AdminCameraTile extends StatelessWidget {
  const _AdminCameraTile({
    required this.user,
    required this.index,
    required this.stream,
    required this.online,
    required this.selected,
    required this.onTap,
  });
  final AppUser user;
  final int index;
  final LiveCctvStream stream;
  final bool online, selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final inspection = stream.inspection;
    final normal = inspection.condition != HealthState.abnormal;
    final label = stream.label.trim().isEmpty
        ? cctvStreamDisplayLabel(index, user.liveCctvStreams.length)
        : stream.label;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? _adminOrange.withValues(alpha: .75)
                : context.appColors.border,
            width: selected ? 1.4 : 1,
          ),
          boxShadow: _adminCardShadows(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _CameraPreview(
                online: online,
                showBox: false,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: online ? Colors.red : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          online ? 'LIVE' : 'OFFLINE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Owner:  ${user.displayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appColors.mutedText,
                    ),
                  ),
                  Text(
                    'Model:  ESP32-CAM AI',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appColors.mutedText,
                    ),
                  ),
                  Text(
                    'IP:  ${_cameraHost(stream.streamUrl, index)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _CameraBadge(
                        label: online ? 'ONLINE' : 'OFFLINE',
                        color: online ? _adminGreen : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _CameraBadge(
                          label: online
                              ? (normal
                                    ? 'Normal Rooster · ${inspection.confidenceLabel}'
                                    : 'Abnormal Rooster · ${inspection.confidenceLabel}')
                              : 'No Signal',
                          color: online
                              ? (normal ? _adminGreen : _adminOrange)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _cameraHost(String url, int index) {
    final host = Uri.tryParse(url)?.host;
    return host == null || host.isEmpty ? '192.168.1.${101 + index}' : host;
  }
}

class _CameraBadge extends StatelessWidget {
  const _CameraBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: color.withValues(alpha: .5)),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800),
    ),
  );
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({
    required this.online,
    required this.showBox,
    this.child,
  });
  final bool online, showBox;
  final Widget? child;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5A4B3B), Color(0xFF151C20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        if (online)
          Opacity(
            opacity: .85,
            child: Image.asset(
              'assets/chickens/healthy_rooster.png',
              fit: BoxFit.contain,
            ),
          ),
        if (showBox)
          Center(
            child: Container(
              width: 105,
              height: 145,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF31DA67), width: 2),
              ),
            ),
          ),
        ?child,
      ],
    ),
  );
}

class _AdminCameraDetail extends StatelessWidget {
  const _AdminCameraDetail({
    required this.user,
    required this.index,
    required this.stream,
    required this.online,
    required this.controller,
    required this.onClose,
  });
  final AppUser user;
  final int index;
  final LiveCctvStream stream;
  final bool online;
  final AppController controller;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final inspection = stream.inspection;
    final normal = inspection.condition != HealthState.abnormal;
    final label = stream.label.trim().isEmpty
        ? cctvStreamDisplayLabel(index, user.liveCctvStreams.length)
        : stream.label;
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: online ? Colors.red : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  online ? 'LIVE' : 'OFFLINE',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Close',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 230,
            child: _CameraPreview(online: online, showBox: online),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: online
                        ? (normal ? _adminGreen : _adminOrange)
                        : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        online
                            ? (normal ? 'Normal Rooster' : 'Abnormal Rooster')
                            : 'No Signal',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        online
                            ? 'Detected at ${inspection.inspectedAtLabel}'
                            : 'Camera unavailable',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.appColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  inspection.confidenceLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appColors.mutedText,
                  ),
                ),
                const SizedBox(width: 10),
                _DetailAction(
                  icon: Icons.fullscreen,
                  label: 'Fullscreen',
                  onTap: () =>
                      _showFullscreenCameraPreview(context, online: online),
                ),
                const SizedBox(width: 5),
                _DetailAction(
                  icon: Icons.camera_alt_outlined,
                  label: 'Snapshot',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Snapshot requested from camera stream.'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(5),
    child: Container(
      width: 60,
      height: 52,
      decoration: BoxDecoration(
        color: context.appColors.background,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: context.appColors.mutedText),
          ),
        ],
      ),
    ),
  );
}

class _CameraStreamDialog extends StatelessWidget {
  const _CameraStreamDialog({
    required this.user,
    required this.index,
    required this.stream,
    required this.online,
    required this.controller,
  });
  final AppUser user;
  final int index;
  final LiveCctvStream stream;
  final bool online;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final inspection = stream.inspection;
    final normal = inspection.condition != HealthState.abnormal;
    final color = online ? (normal ? _adminGreen : _adminOrange) : Colors.grey;
    final label = stream.label.trim().isEmpty
        ? cctvStreamDisplayLabel(index, user.liveCctvStreams.length)
        : stream.label;
    final ip = _AdminCameraTile._cameraHost(stream.streamUrl, index);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      backgroundColor: context.appColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.appColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.videocam_outlined, size: 28),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Camera Stream Details',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 25),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _CameraPreview(online: online, showBox: online),
                    ),
                    Positioned(
                      left: 9,
                      top: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .78),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: online ? Colors.red : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              online ? 'LIVE' : 'OFFLINE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 35,
                      right: 35,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .82),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                online
                                    ? '${normal ? 'Normal' : 'Abnormal'} Rooster - ${inspection.confidenceLabel} confidence'
                                    : 'No Signal',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: width,
                        child: _CameraInfoItem(
                          icon: Icons.monitor_outlined,
                          label: 'Camera Name',
                          value: label,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _CameraInfoItem(
                          icon: Icons.developer_board_outlined,
                          label: 'Local IP Address',
                          value: ip,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _CameraInfoItem(
                          icon: Icons.people_outline,
                          label: 'Owner',
                          value: user.displayName,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _CameraInfoItem(
                          icon: Icons.video_camera_back_outlined,
                          label: 'RTSP Address',
                          value: stream.streamUrl,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: const _CameraInfoItem(
                          icon: Icons.videocam_outlined,
                          label: 'Camera Model',
                          value: 'ESP32-CAM AI',
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _CameraInfoItem(
                          icon: Icons.check_circle_outline,
                          label: 'Status',
                          value: online ? 'ONLINE' : 'OFFLINE',
                          valueColor: online ? _adminGreen : Colors.grey,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: context.appColors.border),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.appColors.border),
                ),
                child: Column(
                  children: [
                    _CameraMetaRow(
                      icon: Icons.holiday_village_outlined,
                      label: 'Farm Name',
                      value: user.farmName.isEmpty
                          ? 'Farm account'
                          : user.farmName,
                    ),
                    _CameraMetaRow(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: user.address.isEmpty
                          ? 'Not provided'
                          : user.address,
                    ),
                    _CameraMetaRow(
                      icon: Icons.schedule_outlined,
                      label: 'Last Activity',
                      value: inspection.inspectedAtLabel == '-'
                          ? 'No activity recorded'
                          : inspection.inspectedAtLabel,
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _CameraDialogAction(
                      icon: Icons.fullscreen,
                      label: 'Fullscreen',
                      color: _adminOrange,
                      onTap: () => _showFullscreen(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CameraDialogAction(
                      icon: Icons.camera_alt_outlined,
                      label: 'Snapshot',
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Snapshot requested from camera stream.',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CameraDialogAction(
                      icon: Icons.person_outline,
                      label: 'View User',
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            _UserActions(user: user, controller: controller),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullscreen(BuildContext context) =>
      _showFullscreenCameraPreview(context, online: online);
}

void _showFullscreenCameraPreview(
  BuildContext context, {
  required bool online,
}) => showDialog<void>(
  context: context,
  barrierColor: Colors.black,
  builder: (dialogContext) => Dialog.fullscreen(
    backgroundColor: Colors.black,
    child: Stack(
      children: [
        Positioned.fill(
          child: _CameraPreview(online: online, showBox: online),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: SafeArea(
            child: IconButton(
              tooltip: 'Close',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      ],
    ),
  ),
);

class _CameraInfoItem extends StatelessWidget {
  const _CameraInfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 22, color: context.appColors.mutedText),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.appColors.mutedText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: valueColor ?? context.appColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CameraMetaRow extends StatelessWidget {
  const _CameraMetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });
  final IconData icon;
  final String label, value;
  final bool last;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
    decoration: BoxDecoration(
      border: last
          ? null
          : Border(bottom: BorderSide(color: context.appColors.border)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: context.appColors.mutedText),
        const SizedBox(width: 9),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.appColors.mutedText),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right, size: 17, color: context.appColors.mutedText),
      ],
    ),
  );
}

class _CameraDialogAction extends StatelessWidget {
  const _CameraDialogAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(7),
    child: Container(
      constraints: const BoxConstraints(minHeight: 90),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 25, color: color ?? context.appColors.text),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _NewAdminInbox extends StatefulWidget {
  const _NewAdminInbox({required this.controller});
  final AppController controller;
  @override
  State<_NewAdminInbox> createState() => _NewAdminInboxState();
}

class _NewAdminInboxState extends State<_NewAdminInbox> {
  int filter = 0;
  String? _selectedThreadId;
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  void _send(SupportThread thread) {
    widget.controller.sendAdminSupportMessage(
      threadId: thread.id,
      text: _reply.text,
    );
    _reply.clear();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (_, _) {
      var threads = widget.controller.supportThreads;
      if (filter == 1) threads = threads.where((t) => !t.resolved).toList();
      if (filter == 2) {
        threads = threads
            .where(
              (t) =>
                  !t.resolved &&
                  t.messages.any((m) => m.senderRole == UserRole.admin),
            )
            .toList();
      }
      if (filter == 3) threads = threads.where((t) => t.resolved).toList();
      final selected = _selectedThreadId == null
          ? null
          : widget.controller.threadById(_selectedThreadId!);
      return SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 9, 8, 7),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Inbox',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Row(
                children: List.generate(
                  4,
                  (i) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _InboxFilterButton(
                        label: const [
                          'All',
                          'Open',
                          'Scheduled',
                          'Resolved',
                        ][i],
                        selected: filter == i,
                        color: const [
                          _adminOrange,
                          Color(0xFF3799F2),
                          Color(0xFFE3A126),
                          _adminGreen,
                        ][i],
                        onTap: () => setState(() => filter = i),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 220,
              child: threads.isEmpty
                  ? Center(
                      child: Text(
                        'No messages here',
                        style: TextStyle(color: context.appColors.mutedText),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      itemCount: threads.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 5),
                      itemBuilder: (_, i) => _InboxThreadRow(
                        thread: threads[i],
                        user: widget.controller.userByUsername(
                          threads[i].username,
                        ),
                        selected: selected?.id == threads[i].id,
                        onTap: () {
                          widget.controller.markThreadRead(threads[i].id);
                          setState(() => _selectedThreadId = threads[i].id);
                          showDialog<void>(
                            context: context,
                            barrierColor: Colors.black.withValues(alpha: .72),
                            builder: (_) => _SupportThreadDialog(
                              controller: widget.controller,
                              threadId: threads[i].id,
                            ),
                          );
                        },
                      ),
                    ),
            ),
            if (selected != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 7, 7, 6),
                child: _InboxConversationHeader(
                  thread: selected,
                  user: widget.controller.userByUsername(selected.username),
                  controller: widget.controller,
                  onBack: () => setState(() => _selectedThreadId = null),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.appColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'May 23, 2025',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.appColors.mutedText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...selected.messages.map(
                      (m) => _AdminInboxBubble(message: m),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(7, 5, 7, 7),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Attach file',
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Attachments are not supported yet.',
                                ),
                              ),
                            ),
                        icon: const Icon(Icons.attach_file, size: 22),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: MergeSemantics(
                            child: Semantics(
                              label: 'Message',
                              child: TextField(
                                controller: _reply,
                                onSubmitted: (_) => _send(selected),
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Type your message...',
                                  hintStyle: TextStyle(
                                    fontSize: 12,
                                    color: context.appColors.mutedText,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 11,
                                  ),
                                  filled: true,
                                  fillColor: context.appColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Semantics(
                        button: true,
                        label: 'Send message',
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _adminOrange,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () => _send(selected),
                            child: const Icon(Icons.send_outlined, size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else
              Expanded(
                child: Center(
                  child: Text(
                    'Select a conversation',
                    style: TextStyle(color: context.appColors.mutedText),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _InboxFilterButton extends StatelessWidget {
  const _InboxFilterButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: selected ? 1 : .7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : color,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _InboxThreadRow extends StatelessWidget {
  const _InboxThreadRow({
    required this.thread,
    required this.user,
    required this.selected,
    required this.onTap,
  });
  final SupportThread thread;
  final AppUser? user;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final last = thread.messages.isEmpty ? null : thread.messages.last;
    final tag = _supportTag(last?.text ?? '');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        height: 70,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: selected
              ? context.appColors.surfaceRaised
              : context.appColors.surface,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected
                ? _adminOrange.withValues(alpha: .45)
                : context.appColors.border,
          ),
          boxShadow: _adminCardShadows(context),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _adminOrange.withValues(alpha: .15),
              backgroundImage: user?.avatarPath == null
                  ? null
                  : FileImage(File(user!.avatarPath!)),
              child: user?.avatarPath == null
                  ? Text(
                      (user?.displayName ?? thread.username)[0].toUpperCase(),
                      style: const TextStyle(
                        color: _adminOrange,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user?.displayName ?? thread.username,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tag.$2.withValues(alpha: .75),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          tag.$1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    last?.text ?? 'No messages',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: context.appColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  last?.timestamp ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: context.appColors.mutedText,
                  ),
                ),
                const Spacer(),
                if (thread.unreadByAdmin)
                  Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6323D),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '1',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _adminGreen.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      thread.resolved ? 'Resolved' : 'Open',
                      style: const TextStyle(fontSize: 10, color: _adminGreen),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static (String, Color) _supportTag(String text) {
    final value = text.toLowerCase();
    if (value.contains('camera') || value.contains('cctv')) {
      return ('CCTV Concern', _adminOrange);
    }
    if (value.contains('password') || value.contains('account')) {
      return ('Account Help', const Color(0xFF8C62C9));
    }
    if (value.contains('temperature') || value.contains('sensor')) {
      return ('Sensor Issue', const Color(0xFF388DE5));
    }
    return ('Bug', const Color(0xFFE04D55));
  }
}

class _InboxConversationHeader extends StatelessWidget {
  const _InboxConversationHeader({
    required this.thread,
    required this.user,
    required this.controller,
    required this.onBack,
  });
  final SupportThread thread;
  final AppUser? user;
  final AppController controller;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Semantics(
        label: 'Back',
        button: true,
        child: InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(9),
          child: const Icon(Icons.arrow_back, size: 19),
        ),
      ),
      const SizedBox(width: 5),
      CircleAvatar(
        radius: 16,
        backgroundColor: _adminOrange.withValues(alpha: .15),
        child: Text(
          (user?.displayName ?? thread.username)[0],
          style: const TextStyle(
            color: _adminOrange,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.displayName ?? thread.username,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            Text(
              user?.farmName.isNotEmpty == true
                  ? user!.farmName
                  : 'Farm account',
              style: TextStyle(
                fontSize: 10,
                color: context.appColors.mutedText,
              ),
            ),
          ],
        ),
      ),
      _HeaderAction(
        icon: Icons.calendar_month_outlined,
        label: 'Set Troubleshooting\nSchedule',
        color: _adminOrange,
        onTap: () async {
          final now = DateTime.now();
          final date = await showDatePicker(
            context: context,
            initialDate: now.add(const Duration(days: 1)),
            firstDate: now,
            lastDate: now.add(const Duration(days: 365)),
          );
          if (date == null) return;
          controller.sendAdminSupportMessage(
            threadId: thread.id,
            text:
                'Troubleshooting has been scheduled for ${date.month}/${date.day}/${date.year}.',
          );
        },
      ),
      const SizedBox(width: 5),
      _HeaderAction(
        icon: Icons.check_circle_outline,
        label: thread.resolved ? 'Reopen' : 'Mark as\nResolved',
        color: _adminGreen,
        onTap: () =>
            controller.setThreadResolved(thread.id, resolved: !thread.resolved),
      ),
    ],
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(5),
    child: Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: .65)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              height: 1.15,
              color: context.appColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AdminInboxBubble extends StatelessWidget {
  const _AdminInboxBubble({required this.message});
  final SupportMessage message;
  @override
  Widget build(BuildContext context) {
    final mine = message.senderRole == UserRole.admin;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 250),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: mine ? _adminOrange : context.appColors.surface,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: mine ? Colors.white : context.appColors.text,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.timestamp,
              style: TextStyle(
                fontSize: 10,
                color: context.appColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportThreadDialog extends StatefulWidget {
  const _SupportThreadDialog({
    required this.controller,
    required this.threadId,
  });
  final AppController controller;
  final String threadId;

  @override
  State<_SupportThreadDialog> createState() => _SupportThreadDialogState();
}

class _SupportThreadDialogState extends State<_SupportThreadDialog> {
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  void _send() {
    widget.controller.sendAdminSupportMessage(
      threadId: widget.threadId,
      text: _reply.text,
    );
    _reply.clear();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final thread = widget.controller.threadById(widget.threadId);
      if (thread == null) return const SizedBox.shrink();
      final user = widget.controller.userByUsername(thread.username);
      final latestText = thread.messages.isEmpty
          ? ''
          : thread.messages.last.text;
      final tag = _InboxThreadRow._supportTag(latestText);
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
        backgroundColor: context.appColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.appColors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Support Thread Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 25),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.appColors.border),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: _adminOrange.withValues(alpha: .15),
                      backgroundImage: user?.avatarPath == null
                          ? null
                          : FileImage(File(user!.avatarPath!)),
                      child: user?.avatarPath == null
                          ? Text(
                              (user?.displayName ?? thread.username)[0]
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: _adminOrange,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? thread.username,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            user?.farmName.isNotEmpty == true
                                ? user!.farmName
                                : 'Farm account',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 7,
                            runSpacing: 5,
                            children: [
                              _DialogStatus(label: tag.$1, color: tag.$2),
                              _DialogStatus(
                                label: thread.resolved ? 'Resolved' : 'Open',
                                color: thread.resolved
                                    ? _adminGreen
                                    : const Color(0xFF388DE5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        _DialogAction(
                          icon: Icons.calendar_month_outlined,
                          label: 'Set Troubleshooting\nSchedule',
                          color: _adminOrange,
                          onTap: () => _schedule(context, thread),
                        ),
                        const SizedBox(height: 7),
                        _DialogAction(
                          icon: Icons.check_circle_outline,
                          label: thread.resolved
                              ? 'Reopen Thread'
                              : 'Mark as Resolved',
                          color: _adminGreen,
                          onTap: () => widget.controller.setThreadResolved(
                            thread.id,
                            resolved: !thread.resolved,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.appColors.border),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.appColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'May 23, 2025',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appColors.mutedText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...thread.messages.map(
                      (message) => _AdminInboxBubble(message: message),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.appColors.border),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Attach file',
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Attachments are not supported yet.',
                                ),
                              ),
                            ),
                        icon: const Icon(Icons.attach_file, size: 25),
                      ),
                      Expanded(
                        child: MergeSemantics(
                          child: Semantics(
                            label: 'Reply message',
                            child: TextField(
                              controller: _reply,
                              minLines: 1,
                              maxLines: 3,
                              onSubmitted: (_) => _send(),
                              decoration: const InputDecoration(
                                hintText: 'Type your reply...',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Semantics(
                        button: true,
                        label: 'Send message',
                        child: SizedBox(
                          width: 52,
                          height: 50,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _adminOrange,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _send,
                            child: const Icon(Icons.send_outlined, size: 25),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _schedule(BuildContext context, SupportThread thread) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    widget.controller.sendAdminSupportMessage(
      threadId: thread.id,
      text:
          'Troubleshooting has been scheduled for ${date.month}/${date.day}/${date.year}.',
    );
  }
}

class _DialogStatus extends StatelessWidget {
  const _DialogStatus({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withValues(alpha: .55)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700),
    ),
  );
}

class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      width: 142,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: .7)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: context.appColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
