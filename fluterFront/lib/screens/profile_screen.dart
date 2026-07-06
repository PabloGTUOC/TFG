import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/push_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_upload.dart';
import '../utils/json.dart';
import '../widgets/family_circle.dart';
import '../widgets/ui.dart';

/// Port of views/ProfileView.vue: family banner, deletion-request banner,
/// account settings (name/email/alias, notification prefs, delete account),
/// Family Circle with delete-family, and the wallet panel with humanised
/// ledger, un-check revert and insights. Mobile shows Profile/Family/Wallet
/// tabs like the Vue tab bar.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Map<String, dynamic>> _ledger = [];
  List<Map<String, dynamic>> _deletionRequests = [];
  DateTime _month = DateTime.now();
  int _tab = 0; // mobile: 0 profile, 1 family, 2 wallet
  bool _showFullLedger = false;

  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _alias = TextEditingController();

  static const _notifPrefDefs = [
    ('activity_assigned', 'Activity assigned to me'),
    ('activity_validated', 'Activity approved & coins earned'),
    ('activity_completed', 'Family activity completed'),
    ('bounty_offered', 'Bounty offered on a shift'),
    ('family_events', 'Family management events'),
  ];
  Map<String, bool> _notifPrefs = {};
  bool _notifGranted = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _displayName.text = app.profile?['display_name']?.toString() ?? '';
    _email.text = app.profile?['email']?.toString() ?? '';
    _alias.text = app.family?['alias']?.toString() ?? '';
    _loadLedger();
    _loadDeletionRequests();
    _checkNotifPermission();
  }

  Future<void> _checkNotifPermission() async {
    final granted = await PushService.granted;
    if (mounted) setState(() => _notifGranted = granted);
    if (granted) await _loadNotifPrefs();
  }

  Future<void> _enableNotifications() async {
    final app = context.read<AppState>();
    final ok = await PushService.enable(app);
    if (!mounted) return;
    setState(() => _notifGranted = ok);
    if (ok) {
      app.setSuccess('Notifications enabled!');
      await _loadNotifPrefs();
    }
  }

  Future<void> _disableNotifications() async {
    await PushService.disable(context.read<AppState>());
    if (mounted) setState(() => _notifGranted = false);
  }

  @override
  void dispose() {
    _displayName.dispose();
    _email.dispose();
    _alias.dispose();
    super.dispose();
  }

  Future<void> _loadLedger() async {
    final app = context.read<AppState>();
    if (app.familyId == 0) return;
    try {
      final month = DateFormat('yyyy-MM').format(_month);
      final data = await app.api
          .get('/api/me/ledger?familyId=${app.familyId}&month=$month');
      final list = data is List ? data : (data['ledger'] as List? ?? []);
      if (mounted) {
        setState(() => _ledger =
            list.cast<Map>().map((m) => m.cast<String, dynamic>()).toList());
      }
    } catch (_) {}
  }

  Future<void> _loadDeletionRequests() async {
    final app = context.read<AppState>();
    if (app.familyId == 0 || !app.isCaregiver) return;
    try {
      final data = await app.api
          .get('/api/families/${app.familyId}/deletion-requests');
      final list = (data['deletionRequests'] as List?) ?? [];
      if (mounted) {
        setState(() => _deletionRequests =
            list.cast<Map>().map((m) => m.cast<String, dynamic>()).toList());
      }
    } catch (_) {}
  }

  Future<void> _loadNotifPrefs() async {
    final app = context.read<AppState>();
    try {
      final data = await app.api.get('/api/me/notification-preferences');
      if (mounted && data is Map) {
        setState(() => _notifPrefs = {
              for (final (key, _) in _notifPrefDefs) key: data[key] != false,
            });
      }
    } catch (_) {}
  }

  Future<void> _saveNotifPrefs() async {
    final app = context.read<AppState>();
    try {
      await app.api.put('/api/me/notification-preferences', _notifPrefs);
    } catch (_) {
      app.setError('Failed to save notification preferences.');
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _loadLedger();
  }

  Future<bool> _confirm(String title, String body,
      {bool danger = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Confirm',
                  style: TextStyle(
                      color: danger ? AppColors.danger : AppColors.primary))),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _updateProfile() async {
    final app = context.read<AppState>();
    await app.runAction(() async {
      await app.api.patch('/api/me/profile', {
        'displayName': _displayName.text.trim(),
        'email': _email.text.trim(),
        if (app.familyId != 0) 'familyId': app.familyId,
        if (app.familyId != 0) 'alias': _alias.text.trim(),
      });
      await app.fetchUserData();
    }, 'Personal details updated successfully!');
  }

  Future<void> _deleteAccount() async {
    final app = context.read<AppState>();
    final ok = await _confirm(
        'Delete account',
        'Your profile will be anonymized and all your pending activities '
            'deleted. This cannot be undone.',
        danger: true);
    if (!ok) return;
    await app.runAction(() async {
      await app.api.delete('/api/me');
      await app.logout();
    }, 'Account deleted.');
  }

  Future<void> _deleteFamily() async {
    final app = context.read<AppState>();
    final ok = await _confirm(
        'Delete family',
        'If there are other caregivers this sends them a deletion request. '
            'All family data will be permanently removed.',
        danger: true);
    if (!ok) return;
    await app.runAction(() async {
      final res = await app.api.delete('/api/families/${app.familyId}');
      if (res is Map && res['deleted'] == true) {
        await app.fetchUserData();
      } else if (res is Map && res['pendingApproval'] == true) {
        app.setSuccess('Deletion request sent to other caregivers.');
        await _loadDeletionRequests();
      }
    });
  }

  Future<void> _respondToDeletionRequest(dynamic reqId, String action) async {
    final app = context.read<AppState>();
    await app.runAction(() async {
      final res = await app.api.post(
          '/api/families/${app.familyId}/deletion-requests/$reqId/$action');
      if (res is Map && res['deleted'] == true) {
        await app.fetchUserData();
      } else {
        await _loadDeletionRequests();
      }
    }, 'Deletion request ${action}d.');
  }

  Future<void> _uncheckActivity(Map<String, dynamic> item) async {
    final app = context.read<AppState>();
    final ok = await _confirm(
        'Un-check activity',
        'This will revert ${toNum(item['amount']).abs()} cc from your balance '
            'for "${item['activity_title'] ?? 'this activity'}".');
    if (!ok) return;
    await app.runAction(() async {
      await app.api.post('/api/activities/${item['activity_id']}/revert');
      await app.fetchUserData();
      await _loadLedger();
    }, 'Activity unchecked and balance reverted.');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final family = app.family;
    final wide = MediaQuery.sizeOf(context).width > kMobileBreakpoint;

    final wallet = _WalletPanel(
      balance: toNum(family?['coin_balance']),
      month: _month,
      ledger: _ledger,
      showFullLedger: _showFullLedger,
      onToggleLedger: () =>
          setState(() => _showFullLedger = !_showFullLedger),
      onPrevMonth: () => _changeMonth(-1),
      onNextMonth: () => _changeMonth(1),
      onUncheck: _uncheckActivity,
    );

    final account = _buildAccountCard(app, family);

    final familySection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FamilyCircle(),
        if (app.isCaregiver && family != null) ...[
          const SizedBox(height: 16),
          VButton(
              type: VButtonType.danger,
              onPressed: _deleteFamily,
              child: const Text('Delete Family')),
        ],
      ],
    );

    return RefreshIndicator(
      onRefresh: () async {
        await app.fetchUserData();
        await _loadLedger();
        await _loadDeletionRequests();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        children: [
          const PageHeading(
              title: 'Personal Area',
              subtitle:
                  'Manage your family profile and tracking preferences.'),

          // Family banner (gradient indigo → violet)
          if (family != null)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.indigo, AppColors.violet]),
                borderRadius: BorderRadius.circular(AppRadii.md),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x4D6366F1),
                      blurRadius: 20,
                      offset: Offset(0, 6)),
                ],
              ),
              child: Row(
                children: [
                  const Text('🏡', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            (family['name'] ??
                                    family['family_name'] ??
                                    'My Family')
                                .toString(),
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: Colors.white)),
                        Text(
                            'as ${family['alias'] ?? app.profile?['display_name'] ?? 'member'}',
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xA6FFFFFF))),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0x26FFFFFF),
                      border: Border.all(color: const Color(0x40FFFFFF)),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Column(
                      children: [
                        const Text('FAMILY ID',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: Color(0xA6FFFFFF))),
                        Text('${family['family_id'] ?? '—'}',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── Deletion requests banner ──
          for (final req in _deletionRequests)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                border: Border.all(color: AppColors.danger),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️ Pending Family Deletion Request',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.danger)),
                  const SizedBox(height: 8),
                  Text(
                      '${req['requested_by_name'] ?? 'A caregiver'} has requested '
                      'to permanently delete this family.',
                      style: const TextStyle(fontSize: 13.5)),
                  const SizedBox(height: 8),
                  for (final a in ((req['approvals'] as List?) ?? [])
                      .cast<Map>()
                      .map((m) => m.cast<String, dynamic>()))
                    Text(
                        '${a['caregiver_name']}: ${(a['status'] ?? '').toString().toUpperCase()}',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: a['status'] == 'approved'
                                ? AppColors.success
                                : a['status'] == 'rejected'
                                    ? AppColors.danger
                                    : AppColors.warning)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      VButton(
                          type: VButtonType.danger,
                          onPressed: () =>
                              _respondToDeletionRequest(req['id'], 'approve'),
                          child: const Text('Approve Deletion')),
                      const SizedBox(width: 10),
                      VButton(
                          type: VButtonType.outline,
                          onPressed: () =>
                              _respondToDeletionRequest(req['id'], 'reject'),
                          child: const Text('Reject')),
                    ],
                  ),
                ],
              ),
            ),

          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(children: [
                    account,
                    const SizedBox(height: 24),
                    familySection,
                  ]),
                ),
                const SizedBox(width: 24),
                Expanded(child: wallet),
              ],
            )
          else ...[
            SegmentedTabs(
              tabs: const ['My Profile', 'Family', 'Wallet'],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 20),
            if (_tab == 0) account,
            if (_tab == 1) familySection,
            if (_tab == 2) wallet,
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard(AppState app, Map<String, dynamic>? family) {
    return VCard(
      title: 'Account Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Tooltip(
                message: 'Tap to change photo',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    final ok = await pickAndUploadAvatar(
                        context, '/api/me/avatar',
                        successMessage: 'Your avatar updated successfully!');
                    if (ok && context.mounted) {
                      await context.read<AppState>().fetchUserData();
                    }
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AvatarCircle(
                          name: (app.profile?['display_name'] ??
                                  app.user?.email ??
                                  '?')
                              .toString(),
                          imageUrl: app.profile?['avatar_url']?.toString(),
                          size: 56),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                              color: AppColors.indigo,
                              shape: BoxShape.circle),
                          child: const Text('📷',
                              style: TextStyle(fontSize: 10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        (app.profile?['display_name'] ?? 'Your Name')
                            .toString(),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    Text((app.profile?['email'] ?? '').toString(),
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                    if (family?['role'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: PillBadge(
                            text: family!['role']
                                .toString()
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            fontSize: 10,
                            color: AppColors.indigo,
                            background: AppColors.primarySoft),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          VInput(
              controller: _displayName,
              label: 'Full Name',
              placeholder: 'Your full name'),
          const SizedBox(height: 12),
          VInput(
              controller: _email,
              label: 'Email Address',
              placeholder: 'your@email.com'),
          if (family != null) ...[
            const SizedBox(height: 12),
            VInput(
                controller: _alias,
                label: 'Your Alias',
                placeholder: 'e.g. Papa, Mama…'),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: VButton(
                    onPressed: _updateProfile,
                    block: true,
                    child: const Text('Update Profile')),
              ),
              const SizedBox(width: 10),
              VButton(
                  type: VButtonType.outline,
                  onPressed: _deleteAccount,
                  child: const Text('Delete Account',
                      style: TextStyle(color: AppColors.danger))),
            ],
          ),
          const Divider(height: 32),
          const Text('Push Notifications',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          if (!_notifGranted)
            VButton(
                type: VButtonType.secondary,
                onPressed: _enableNotifications,
                child: const Text('Enable Notifications'))
          else ...[
            Row(
              children: [
                const Expanded(
                  child: Text('✓ Notifications enabled',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success)),
                ),
                TextButton(
                    onPressed: _disableNotifications,
                    child: const Text('Disable',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.underline))),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (final (key, label) in _notifPrefDefs)
                    SwitchListTile(
                      dense: true,
                      activeThumbColor: AppColors.primary,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      title: Text(label,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                      value: _notifPrefs[key] ?? true,
                      onChanged: (v) {
                        setState(() => _notifPrefs[key] = v);
                        _saveNotifPrefs();
                      },
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          VButton(
            type: VButtonType.danger,
            onPressed: () => app.logout(),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

/// Port of components/profile/WalletPanel.vue: dark balance widget with a
/// 3-row preview, expandable monthly ledger with humanised reasons and
/// un-check revert, plus the Activity Insights card.
class _WalletPanel extends StatelessWidget {
  final num balance;
  final DateTime month;
  final List<Map<String, dynamic>> ledger;
  final bool showFullLedger;
  final VoidCallback onToggleLedger;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<Map<String, dynamic>> onUncheck;

  const _WalletPanel({
    required this.balance,
    required this.month,
    required this.ledger,
    required this.showFullLedger,
    required this.onToggleLedger,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onUncheck,
  });

  /// Port of formatLedgerLabel.
  static String ledgerLabel(Map<String, dynamic> item) {
    final title = item['activity_title']?.toString();
    switch (item['reason']?.toString()) {
      case 'activity_completed':
        return title ?? 'Activity completed';
      case 'activity_reverted':
        return title ?? 'Activity reverted';
      case 'bounty_escrow':
      case 'bounty_paid':
        return title != null ? 'You paid for not doing: $title' : 'Bounty paid';
      case 'bounty_earned':
        return title != null ? 'Bounty earned: $title' : 'Bounty earned';
      case 'bounty_refunded':
        return title != null ? 'Bounty refunded: $title' : 'Bounty refunded';
      case 'bounty_reverted':
        return title != null ? 'Bounty reverted: $title' : 'Bounty reverted';
      default:
        return title ?? (item['reason']?.toString() ?? 'Movement');
    }
  }

  /// Port of formatLedgerDate (Today/Yesterday, HH:mm else short date).
  static String ledgerDate(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (days == 0) return 'Today, ${DateFormat('HH:mm').format(d)}';
    if (days == 1) return 'Yesterday, ${DateFormat('HH:mm').format(d)}';
    return DateFormat('MMM d, yyyy').format(d);
  }

  static bool _isReverted(Map<String, dynamic> item) =>
      item['reason'] == 'activity_reverted' ||
      item['reason'] == 'bounty_reverted';

  ({String label, String icon}) get _coinTier {
    if (balance >= 1000) return (label: 'Platinum Parent', icon: '🏆');
    if (balance >= 500) return (label: 'Gold Caregiver', icon: '🥇');
    if (balance >= 200) return (label: 'Silver Helper', icon: '🥈');
    return (label: 'Bronze Starter', icon: '🥉');
  }

  @override
  Widget build(BuildContext context) {
    final preview = ledger.take(3).toList();
    final tasksThisMonth =
        ledger.where((i) => i['reason'] == 'activity_completed').length;
    final tier = _coinTier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Balance widget ──
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TOTAL BALANCE',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppColors.inkMuted)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(NumberFormat.decimalPattern().format(balance),
                      style: const TextStyle(
                          fontSize: 44.8,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: Colors.white)),
                  const SizedBox(width: 6),
                  const Text('COINS',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold)),
                ],
              ),
              const SizedBox(height: 20),
              if (preview.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(
                    child: Text('No activity this month.',
                        style: TextStyle(
                            fontSize: 13.6, color: Color(0xFF475569))),
                  ),
                )
              else
                for (final row in preview)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x0FFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ledgerLabel(row),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFF1F5F9)
                                          .withValues(
                                              alpha: _isReverted(row)
                                                  ? 0.6
                                                  : 1),
                                      decoration: _isReverted(row)
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationColor:
                                          const Color(0xFFF1F5F9))),
                              Text(ledgerDate(row['created_at']),
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        _AmountText(amount: toNum(row['amount'])),
                      ],
                    ),
                  ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onToggleLedger,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE2E8F0),
                    side: const BorderSide(color: Color(0x1FFFFFFF)),
                    backgroundColor: const Color(0x14FFFFFF),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadii.pill)),
                  ),
                  child: Text(
                      showFullLedger ? 'Hide Ledger' : 'View Full Ledger',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),

        // ── Full ledger ──
        if (showFullLedger) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Monthly Ledger',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                        onPressed: onPrevMonth,
                        icon: const Icon(Icons.chevron_left_rounded,
                            color: AppColors.textSecondary)),
                    Text(DateFormat('MMM yyyy').format(month),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    IconButton(
                        onPressed: onNextMonth,
                        icon: const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                if (ledger.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No activity this month.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  for (final row in ledger)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ledgerLabel(row),
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary
                                            .withValues(
                                                alpha: _isReverted(row)
                                                    ? 0.6
                                                    : 1),
                                        decoration: _isReverted(row)
                                            ? TextDecoration.lineThrough
                                            : null)),
                                Text(ledgerDate(row['created_at']),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                                if (toNum(row['duration_minutes']) > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: PillBadge(
                                        text:
                                            '${row['duration_minutes']} min',
                                        fontSize: 10,
                                        color: AppColors.violet,
                                        background: AppColors.primarySoft),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _AmountText(
                                  amount: toNum(row['amount']),
                                  suffix: ' cc',
                                  dark: false),
                              if (row['reason'] == 'activity_completed')
                                TextButton(
                                  onPressed: () => onUncheck(row),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    minimumSize: const Size(0, 28),
                                  ),
                                  child: const Text('Un-check',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.danger)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],

        // ── Insights ──
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Activity Insights',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              for (final (icon, bg, label, sub) in [
                (
                  '✅',
                  AppColors.successSoft,
                  'Tasks Mastered',
                  '$tasksThisMonth this month'
                ),
                (
                  tier.icon,
                  AppColors.warningSoft,
                  'Rank: ${tier.label}',
                  '${NumberFormat.decimalPattern().format(balance)} cc total'
                ),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration:
                            BoxDecoration(color: bg, shape: BoxShape.circle),
                        child:
                            Text(icon, style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          Text(sub,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmountText extends StatelessWidget {
  final num amount;
  final String suffix;
  final bool dark;

  const _AmountText({required this.amount, this.suffix = '', this.dark = true});

  @override
  Widget build(BuildContext context) {
    final positive = amount > 0;
    final color = dark
        ? (positive ? const Color(0xFF34D399) : const Color(0xFFF87171))
        : (positive ? AppColors.success : AppColors.danger);
    return Text('${positive ? '+' : ''}$amount$suffix',
        style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800, color: color));
  }
}
