part of '../../main.dart';

const _adminBg = Color(0xFF070D17);
const _adminSurface = Color(0xFF0C1420);
const _adminSurface2 = Color(0xFF101A28);
const _adminLine = Color(0xFF1C2938);
const _adminOrange = Color(0xFFF45B16);
const _adminGreen = Color(0xFF25C778);
const _adminMuted = Color(0xFF8290A3);

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
      data: buildAppTheme(Brightness.dark).copyWith(
        scaffoldBackgroundColor: _adminBg,
        cardColor: _adminSurface,
        dividerColor: _adminLine,
        appBarTheme: const AppBarTheme(
          backgroundColor: _adminBg,
          foregroundColor: Colors.white,
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
          builder: (_, __) => SafeArea(
            top: false,
            child: Container(
              height: 68,
              decoration: const BoxDecoration(
                color: _adminSurface,
                border: Border(top: BorderSide(color: _adminLine)),
              ),
              child: Row(
                children: List.generate(items.length, (i) {
                  final selected = i == _index;
                  return Expanded(
                    child: InkWell(
                      onTap: () => _goTo(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(items[i].$1,
                                  color: selected ? _adminOrange : _adminMuted,
                                  size: 22),
                              if (i == 3 && widget.controller.unreadSupportCount > 0)
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
                                    child: Text('${widget.controller.unreadSupportCount}',
                                        style: const TextStyle(fontSize: 13,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(items[i].$2,
                              maxLines: 1,
                              style: TextStyle(
                                color: selected ? _adminOrange : _adminMuted,
                                fontSize: 13,
                                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                              )),
                        ],
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

class _NewAdminDashboard extends StatelessWidget {
  const _NewAdminDashboard({required this.controller, required this.goTo});
  final AppController controller;
  final ValueChanged<int> goTo;

  @override
  Widget build(BuildContext context) {
    final users = controller.farmUsers;
    final warningAlerts = users
        .expand((u) => u.monitor.alerts.where((a) => a.severity != AlertSeverity.info))
        .toList();
    final alerts = warningAlerts.length;
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => SafeArea(child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Row(children: [
              Image.asset('assets/app_icon_square.png', width: 43, height: 43),
              const SizedBox(width: 10),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Roostify', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                Text('ADMIN', style: TextStyle(fontSize: 13, color: _adminMuted, letterSpacing: 2)),
              ]),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute<void>(builder: (_) => AlertsPage(alerts: warningAlerts))),
                child: Container(width: 36, height: 36, decoration: BoxDecoration(
                  color: _adminSurface2, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _adminLine)),
                  child: Stack(clipBehavior: Clip.none, children: [
                    const Align(alignment: Alignment.center, child: Icon(Icons.notifications_none_rounded, size: 20)),
                    if (alerts > 0)
                      Positioned(right: -3, top: -3, child: Container(
                        width: 19, height: 19, alignment: Alignment.center,
                        decoration: const BoxDecoration(color: Color(0xFFE52D45), shape: BoxShape.circle),
                        child: Text('$alerts', style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w800)),
                      )),
                  ]),
                ),
              ),
            ]),
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF5A2C19)),
                gradient: const LinearGradient(colors: [_adminSurface2, Color(0xFF32190F)]),
              ),
              child: Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Welcome back, Admin!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text("Here's what's happening with your system today.",
                      style: TextStyle(color: Color(0xFFB9C1CC), fontSize: 13)),
                ])),
                Image.asset('assets/app_icon_square.png', width: 66, height: 66),
              ]),
            ),
          )),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            sliver: SliverGrid.count(
              crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10,
              childAspectRatio: 1.8,
              children: [
                _DashMetric(Icons.group_outlined, '${users.length}', 'Total Users', 'Active accounts', _adminOrange, () => goTo(1)),
                _DashMetric(Icons.videocam_outlined, '${controller.totalCctvCount}', 'CCTV Cameras', 'Connected', _adminGreen, () => goTo(2)),
                _DashMetric(Icons.mail_outline, '${controller.openSupportCount}', 'Inbox Messages', 'New messages', const Color(0xFFE94B5F), () => goTo(3)),
                _DashMetric(Icons.notifications_none, '$alerts', 'System Alerts', 'Active alerts', const Color(0xFFE94B5F),
                    () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => AlertsPage(alerts: warningAlerts)))),
              ],
            ),
          ),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            child: _Panel(title: 'System Overview', child: Column(children: [
              _BreakdownRow(
                label: 'Camera access',
                aLabel: 'Active', a: users.where((u) => u.cameraAccessEnabled).length,
                bLabel: 'Limited', b: users.where((u) => !u.cameraAccessEnabled).length,
                color: _adminOrange,
              ),
              const SizedBox(height: 12),
              _BreakdownRow(
                label: 'CCTV cameras',
                aLabel: 'Online', a: users.expand((u) => u.liveCctvStreams)
                    .where((s) => s.inspection.state != CctvInspectionState.error).length,
                bLabel: 'Offline', b: users.expand((u) => u.liveCctvStreams)
                    .where((s) => s.inspection.state == CctvInspectionState.error).length,
                color: _adminGreen,
              ),
              const SizedBox(height: 12),
              _BreakdownRow(
                label: 'Support threads',
                aLabel: 'Open', a: controller.openSupportCount,
                bLabel: 'Resolved', b: controller.supportThreads.length - controller.openSupportCount,
                color: const Color(0xFFE94B5F),
              ),
            ])),
          )),
        ],
      )),
    );
  }
}

class _DashMetric extends StatelessWidget {
  const _DashMetric(this.icon, this.value, this.title, this.note, this.color, this.onTap);
  final IconData icon; final String value, title, note; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _adminSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _adminLine)),
    child: Row(children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 19)),
      const SizedBox(width: 10), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, maxLines: 1, style: const TextStyle(fontSize: 13, color: Color(0xFFC0C8D3))),
        Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, height: 1.05)),
        Text(note, maxLines: 1, style: const TextStyle(fontSize: 13, color: _adminMuted)),
      ])),
    ]),
  ));
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title; final Widget child;
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _adminSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _adminLine)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), const SizedBox(height: 8), child]),
  );
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.aLabel,
    required this.a,
    required this.bLabel,
    required this.b,
    required this.color,
  });
  final String label, aLabel, bLabel;
  final int a, b;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final total = a + b;
    final fraction = total == 0 ? 0.0 : a / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        Text('$aLabel $a · $bLabel $b', style: const TextStyle(fontSize: 13, color: _adminMuted)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 8,
          child: Stack(children: [
            Container(color: _adminLine),
            FractionallySizedBox(widthFactor: fraction, child: Container(color: color)),
          ]),
        ),
      ),
    ]);
  }
}

class _NewAdminUsers extends StatefulWidget {
  const _NewAdminUsers({required this.controller});
  final AppController controller;
  @override State<_NewAdminUsers> createState() => _NewAdminUsersState();
}

enum _CameraFilter { all, active, limited }

class _NewAdminUsersState extends State<_NewAdminUsers> {
  final search = TextEditingController();
  _CameraFilter filter = _CameraFilter.all;
  @override void dispose(){search.dispose();super.dispose();}
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: widget.controller, builder: (_,__) {
    final q=search.text.toLowerCase();
    final users=widget.controller.farmUsers.where((u)=>u.displayName.toLowerCase().contains(q)||u.username.toLowerCase().contains(q)||u.farmName.toLowerCase().contains(q)).where((u){
      switch (filter) {
        case _CameraFilter.all: return true;
        case _CameraFilter.active: return u.cameraAccessEnabled;
        case _CameraFilter.limited: return !u.cameraAccessEnabled;
      }
    }).toList();
    return SafeArea(child: Column(children: [
      Padding(padding:const EdgeInsets.fromLTRB(8,12,18,16),child:Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Users',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),SizedBox(height:3),Text('Manage and view all user accounts.',style:TextStyle(color:Color(0xFFB7C0CD),fontSize:14))])),FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor:_adminOrange, padding: const EdgeInsets.symmetric(horizontal:12)),
        onPressed: ()=>_showAddUser(context), icon: const Icon(Icons.add,size:20), label: const Text('Add User',style:TextStyle(fontSize:14,fontWeight:FontWeight.w700)))])),
      Padding(padding: const EdgeInsets.symmetric(horizontal:18), child: _SearchBox(
        controller:search,hint:'Search users...',onChanged:(_)=>setState((){}),
        filterButton: PopupMenuButton<_CameraFilter>(
          tooltip: 'Filter by camera access',
          icon: Icon(Icons.filter_alt_outlined, size: 22,
              color: filter == _CameraFilter.all ? const Color(0xFFB7C0CD) : _adminOrange),
          color: _adminSurface2,
          onSelected: (value) => setState(() => filter = value),
          itemBuilder: (_) => const [
            PopupMenuItem(value: _CameraFilter.all, child: Text('All users')),
            PopupMenuItem(value: _CameraFilter.active, child: Text('Camera access: Active')),
            PopupMenuItem(value: _CameraFilter.limited, child: Text('Camera access: Limited')),
          ],
        ),
      )),
      const SizedBox(height:10),
      Expanded(child: users.isEmpty
        ? const Center(child: Text('No users match this search or filter.', style: TextStyle(color: _adminMuted, fontSize: 15)))
        : ListView.separated(padding:const EdgeInsets.fromLTRB(18,0,18,24), itemCount:users.length,
          separatorBuilder:(_,__)=>const SizedBox(height:8), itemBuilder:(_,i)=>_UserRow(user:users[i], controller:widget.controller))),
    ]));
  });
  Future<void> _showAddUser(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AddAdminUserPage(controller: widget.controller),
      ),
    );
  }
}

class _AddAdminUserPage extends StatefulWidget {
  const _AddAdminUserPage({required this.controller});

  final AppController controller;

  @override
  State<_AddAdminUserPage> createState() => _AddAdminUserPageState();
}

class _AddAdminUserPageState extends State<_AddAdminUserPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _farm = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _passwordVisible = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _farm.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    if (_name.text.trim().isEmpty || email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a full name and a valid email address.');
      return;
    }
    if (_password.text.trim().isEmpty) {
      setState(() => _error = 'Enter a temporary password.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = widget.controller.addUser(
      username: email,
      displayName: _name.text,
      email: email,
      farmName: _farm.text,
      contactNumber: _phone.text,
      password: _password.text,
    );
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _submitting = false;
        _error = widget.controller.lastError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildAppTheme(Brightness.dark).copyWith(
        scaffoldBackgroundColor: _adminBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: _adminBg,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'Add New User',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                decoration: BoxDecoration(
                  color: _adminSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _adminLine),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: _adminOrange.withValues(alpha: .08),
                        shape: BoxShape.circle,
                        border: Border.all(color: _adminOrange, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _adminOrange.withValues(alpha: .18),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: _adminOrange,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 11),
                    const Text(
                      'Add a new user account.',
                      style: TextStyle(color: Color(0xFFB7C0CD), fontSize: 15),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A111C),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF152231)),
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
                            textInputAction: TextInputAction.next,
                          ),
                          _AddUserField(
                            controller: _password,
                            label: 'Password (Temporary)',
                            hint: 'Enter temporary password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: !_passwordVisible,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            suffix: IconButton(
                              tooltip: _passwordVisible
                                  ? 'Hide password'
                                  : 'Show password',
                              onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: _adminMuted,
                                size: 20,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: _adminOrange.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: _adminOrange.withValues(alpha: .55),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.person_search_outlined,
                                  color: _adminOrange,
                                  size: 25,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'The user can change their password after 1 week (7 days) from first login.',
                                    style: TextStyle(fontSize: 14, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFF6B72),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Add User',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
      data: buildAppTheme(Brightness.dark).copyWith(
        scaffoldBackgroundColor: _adminBg,
        appBarTheme: const AppBarTheme(backgroundColor: _adminBg, foregroundColor: Colors.white, elevation: 0),
      ),
      child: Scaffold(
        appBar: AppBar(centerTitle: true, title: const Text('Edit User', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
        body: SafeArea(
          top: false,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF0A111C), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF152231))),
                child: Column(children: [
                  _AddUserField(controller: _name, label: 'Full Name', hint: 'Enter full name', icon: Icons.person_outline_rounded, textInputAction: TextInputAction.next, textCapitalization: TextCapitalization.words),
                  _AddUserField(controller: _email, label: 'Email Address', hint: 'Enter email address', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next),
                  _AddUserField(controller: _farm, label: 'Farm / Business Name', hint: 'Enter farm or business name', icon: Icons.business_center_outlined, textInputAction: TextInputAction.next, textCapitalization: TextCapitalization.words),
                  _AddUserField(controller: _phone, label: 'Phone Number (Optional)', hint: 'Enter phone number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, textInputAction: TextInputAction.done, onSubmitted: (_) => _save()),
                ]),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _adminOrange, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: _save,
                child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
    this.obscureText = false,
    this.suffix,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _adminBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF152231)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Icon(icon, color: const Color(0xFFAAB5C3), size: 22),
          ),
          Container(width: 1, color: const Color(0xFF152231)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 4, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      textInputAction: textInputAction,
                      textCapitalization: textCapitalization,
                      obscureText: obscureText,
                      onSubmitted: onSubmitted,
                      style: const TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 18,
                      ),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: const TextStyle(
                          color: Color(0xFFAAB5C3),
                          fontSize: 17,
                        ),
                        suffixIcon: suffix,
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 48,
                          maxHeight: 48,
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
  const _SearchBox({required this.controller,required this.hint,required this.onChanged,this.filterButton});
  final TextEditingController controller; final String hint; final ValueChanged<String> onChanged; final Widget? filterButton;
  @override Widget build(BuildContext context)=>TextField(controller:controller,onChanged:onChanged,style:const TextStyle(color:Colors.white,fontSize:16),decoration:InputDecoration(hintText:hint,hintStyle:const TextStyle(color:Color(0xFFB7C0CD),fontSize:15),prefixIcon:const Icon(Icons.search,size:22,color:Color(0xFFB7C0CD)),suffixIcon:filterButton ?? const Icon(Icons.filter_alt_outlined,size:22,color:Color(0xFFB7C0CD)),filled:true,fillColor:_adminSurface,border:OutlineInputBorder(borderRadius:BorderRadius.circular(9),borderSide:const BorderSide(color:_adminLine)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(9),borderSide:const BorderSide(color:_adminLine))));
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user,required this.controller}); final AppUser user; final AppController controller;
  @override Widget build(BuildContext context)=>Container(decoration:BoxDecoration(color:_adminSurface,borderRadius:BorderRadius.circular(11),border:Border.all(color:_adminLine)),child:ListTile(
    onTap:()=>showModalBottomSheet<void>(context:context,backgroundColor:_adminSurface2,builder:(ctx)=>_UserActions(user:user,controller:controller)),
    leading:CircleAvatar(backgroundColor:[_adminOrange,const Color(0xFFF0AE2D),const Color(0xFF367FEA),const Color(0xFF8847DF)][user.username.hashCode.abs()%4],child:Text(user.displayName.isEmpty?'?':user.displayName[0].toUpperCase(),style:const TextStyle(color:Colors.white))),
    title:Text(user.displayName,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
    subtitle:Text('${user.email.isEmpty?user.username:user.email}\n${user.farmName.isEmpty?'Farm account':user.farmName}',style:const TextStyle(fontSize:14,color:Color(0xFFB7C0CD),height:1.45)),
    trailing:Row(mainAxisSize:MainAxisSize.min,children:[Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:(user.cameraAccessEnabled?_adminGreen:_adminOrange).withValues(alpha:.12),borderRadius:BorderRadius.circular(5)),child:Text(user.cameraAccessEnabled?'Active':'Limited',style:TextStyle(fontSize:13,color:user.cameraAccessEnabled?_adminGreen:_adminOrange,fontWeight:FontWeight.w800))),const Icon(Icons.chevron_right,color:Color(0xFFB7C0CD),size:20)]),
  ));
}

class _UserActions extends StatelessWidget {
 const _UserActions({required this.user,required this.controller}); final AppUser user; final AppController controller;

 Future<void> _editUser(BuildContext context) async {
   Navigator.pop(context);
   await Navigator.of(context).push(MaterialPageRoute<void>(
     builder: (_) => _EditAdminUserPage(controller: controller, username: user.username),
   ));
 }

 Future<void> _resetPassword(BuildContext context) async {
   Navigator.pop(context);
   await showDialog<void>(context: context, builder: (_) => _ResetPasswordDialog(controller: controller, user: user));
 }

 Future<void> _confirmRemove(BuildContext context) async {
   final confirmed = await showDialog<bool>(
     context: context,
     builder: (dialogContext) => AlertDialog(
       backgroundColor: _adminSurface2,
       title: const Text('Remove user?'),
       content: Text('This permanently removes ${user.displayName} (@${user.username}) and their support conversation history. This cannot be undone.'),
       actions: [
         TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
         FilledButton(
           style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF5D65)),
           onPressed: () => Navigator.of(dialogContext).pop(true),
           child: const Text('Remove'),
         ),
       ],
     ),
   );
   if (confirmed == true && context.mounted) {
     controller.removeUser(user.username);
     Navigator.pop(context);
   }
 }

 @override Widget build(BuildContext context)=>SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  Text(user.displayName,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),Text('@${user.username}',style:const TextStyle(color:_adminMuted)),const SizedBox(height:18),
  SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Camera scan access'),value:user.cameraAccessEnabled,activeThumbColor:_adminOrange,onChanged:(_){controller.toggleCameraAccess(user.username);Navigator.pop(context);}),
  const SizedBox(height:6),
  OutlinedButton.icon(onPressed:()=>_editUser(context),icon:const Icon(Icons.edit_outlined),label:const Text('Edit User')),
  const SizedBox(height:10),
  OutlinedButton.icon(onPressed:()=>_resetPassword(context),icon:const Icon(Icons.key_outlined),label:const Text('Reset Password')),
  const SizedBox(height:10),
  OutlinedButton.icon(style:OutlinedButton.styleFrom(foregroundColor:const Color(0xFFFF5D65)),onPressed:()=>_confirmRemove(context),icon:const Icon(Icons.delete_outline),label:const Text('Remove User')),
 ])));
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

  void _submit() {
    final ok = widget.controller.adminResetPassword(widget.user.username, _password.text);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = widget.controller.lastError);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _adminSurface2,
      title: Text('Reset password for ${widget.user.displayName}'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              onPressed: () => setState(() => _visible = !_visible),
              icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Color(0xFFFF6B72), fontSize: 13)),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: _adminOrange), onPressed: _submit, child: const Text('Reset')),
      ],
    );
  }
}

class _NewAdminCctv extends StatelessWidget {
 const _NewAdminCctv({required this.controller}); final AppController controller;
 @override Widget build(BuildContext context)=>AnimatedBuilder(animation: controller, builder: (_,__) {
  final entries = controller.farmUsers
      .expand((u) => u.liveCctvStreams.asMap().entries.map((e) => (u, e.key, e.value)))
      .toList();
  bool isOnline((AppUser, int, LiveCctvStream) e) => e.$3.inspection.state != CctvInspectionState.error;
  final online = entries.where(isOnline).length;
  final allNormal = entries.isNotEmpty && online == entries.length;
  final statusColor = entries.isEmpty ? const Color(0xFFB7C0CD) : (allNormal ? _adminGreen : const Color(0xFFFF6B72));
  return SafeArea(child:Column(children:[
  const Padding(padding:EdgeInsets.fromLTRB(8,12,18,16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('CCTV',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),SizedBox(height:3),Text('View and monitor all user cameras.',style:TextStyle(color:Color(0xFFB7C0CD),fontSize:14))])),
  Padding(padding:const EdgeInsets.symmetric(horizontal:18),child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:const Color(0xFF09241F),borderRadius:BorderRadius.circular(13),border:Border.all(color:const Color(0xFF145B44))),child:Row(children:[CircleAvatar(radius:27,backgroundColor:const Color(0xFF0D4A35),child:Icon(Icons.videocam_outlined,color:statusColor)),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('CCTV Status',style:TextStyle(fontSize:15,fontWeight:FontWeight.w800)),Text(entries.isEmpty?'No Cameras Connected':(allNormal?'All Systems Normal':'Attention Required'),style:TextStyle(fontSize:20,color:statusColor,fontWeight:FontWeight.w900)),Text('$online / ${entries.length} cameras online',style:const TextStyle(fontSize:14,color:Color(0xFFB7C0CD)))])),Icon(Icons.wifi,color:statusColor)]))),
  const SizedBox(height:13),
  Expanded(child:entries.isEmpty?const Center(child:Text('No cameras connected',style:TextStyle(color:Color(0xFFB7C0CD),fontSize:16))):ListView.separated(padding:const EdgeInsets.fromLTRB(18,0,18,24),itemCount:entries.length,separatorBuilder:(_,__)=>const SizedBox(height:10),itemBuilder:(_,i){final e=entries[i];final isOn=isOnline(e);final label=cctvStreamDisplayLabel(e.$2,e.$1.liveCctvStreams.length);return Container(decoration:BoxDecoration(color:_adminSurface,borderRadius:BorderRadius.circular(11),border:Border.all(color:_adminLine)),child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:6),leading:Container(width:54,height:46,decoration:BoxDecoration(color:_adminSurface2,borderRadius:BorderRadius.circular(7)),child:Icon(Icons.videocam,color:isOn?_adminGreen:const Color(0xFFB7C0CD))),title:Text(label,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),subtitle:Text('${e.$1.displayName} • ${e.$3.streamUrl}',overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:14,color:Color(0xFFB7C0CD))),trailing:Text(isOn?'Online':'Offline',style:TextStyle(fontSize:13,color:isOn?_adminGreen:const Color(0xFFFF6B72),fontWeight:FontWeight.w800))));})),
 ]));});
}

class _NewAdminInbox extends StatefulWidget {const _NewAdminInbox({required this.controller});final AppController controller;@override State<_NewAdminInbox> createState()=>_NewAdminInboxState();}
class _NewAdminInboxState extends State<_NewAdminInbox>{int filter=0;@override Widget build(BuildContext context)=>AnimatedBuilder(animation:widget.controller,builder:(_,__){var threads=widget.controller.supportThreads;if(filter==1)threads=threads.where((t)=>t.unreadByAdmin).toList();if(filter==2)threads=threads.where((t)=>t.resolved).toList();return SafeArea(child:Column(children:[
 Padding(padding:const EdgeInsets.fromLTRB(8,12,18,16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Inbox',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),const SizedBox(height:3),const Text('Messages and reports from users.',style:TextStyle(color:_adminMuted,fontSize:14))])),
 Padding(padding:const EdgeInsets.symmetric(horizontal:18),child:Row(children:List.generate(3,(i)=>Expanded(child:InkWell(onTap:()=>setState(()=>filter=i),child:Container(padding:const EdgeInsets.only(bottom:12),decoration:BoxDecoration(border:Border(bottom:BorderSide(color:filter==i?_adminOrange:Colors.transparent,width:2))),alignment:Alignment.center,child:Text(['All','Unread','Resolved'][i],style:TextStyle(fontSize:14,color:filter==i?_adminOrange:_adminMuted,fontWeight:FontWeight.w800)))))))),
 const SizedBox(height:10),
 Expanded(child:threads.isEmpty?const Center(child:Text('No messages here',style:TextStyle(color:_adminMuted,fontSize:16))):ListView.separated(padding:const EdgeInsets.fromLTRB(18,0,18,24),itemCount:threads.length,separatorBuilder:(_,__)=>const SizedBox(height:10),itemBuilder:(_,i){final t=threads[i],u=widget.controller.userByUsername(t.username),last=t.messages.isEmpty?null:t.messages.last;return InkWell(onTap:(){widget.controller.markThreadRead(t.id);Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>AdminThreadPage(controller:widget.controller,threadId:t.id)));},child:Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:_adminSurface,borderRadius:BorderRadius.circular(11),border:Border.all(color:_adminLine)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[CircleAvatar(radius:22,backgroundColor:t.resolved?const Color(0xFF246E58):_adminOrange,child:Icon(t.resolved?Icons.check:Icons.mail_outline,color:Colors.white,size:21)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(u?.displayName??t.username,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800))),Text(last?.timestamp??'',style:const TextStyle(color:_adminMuted,fontSize:13))]),const SizedBox(height:5),Text(last?.text??'No messages',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Color(0xFFB7C0CD),fontSize:14,height:1.4))])),const SizedBox(width:8),Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:(t.unreadByAdmin?_adminOrange:_adminGreen).withValues(alpha:.12),borderRadius:BorderRadius.circular(4)),child:Text(t.unreadByAdmin?'New':'Read',style:TextStyle(fontSize:13,color:t.unreadByAdmin?_adminOrange:_adminGreen,fontWeight:FontWeight.w800)))])));})),
 ]));});}
