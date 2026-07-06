import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/family_circle.dart';
import '../widgets/ui.dart';
import '../utils/json.dart';

/// Port of views/ProfileView.vue: family banner, wallet panel with ledger,
/// account settings and logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Map<String, dynamic>> _ledger = [];
  DateTime _month = DateTime.now();
  final _displayName = TextEditingController();

  @override
  void initState() {
    super.initState();
    _displayName.text =
        context.read<AppState>().profile?['display_name']?.toString() ?? '';
    _loadLedger();
  }

  @override
  void dispose() {
    _displayName.dispose();
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

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _loadLedger();
  }

  Future<void> _updateProfile() async {
    final app = context.read<AppState>();
    await app.runAction(() async {
      await app.api
          .put('/api/me/profile', {'displayName': _displayName.text.trim()});
      await app.fetchUserData();
    }, 'Profile updated!');
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
      onPrevMonth: () => _changeMonth(-1),
      onNextMonth: () => _changeMonth(1),
    );

    final account = VCard(
      title: 'Account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VInput(
              controller: _displayName,
              label: 'Display Name',
              placeholder: 'Your name'),
          const SizedBox(height: 8),
          Text(app.user?.email ?? '',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          VButton(
              onPressed: _updateProfile, child: const Text('Update Profile')),
          const SizedBox(height: 12),
          VButton(
            type: VButtonType.danger,
            onPressed: () => app.logout(),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    return RefreshIndicator(
      onRefresh: () async {
        await app.fetchUserData();
        await _loadLedger();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        children: [
          const PageHeading(
              title: 'Personal Area',
              subtitle: 'Your wallet, your family and your account.'),

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

          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(children: [
                    wallet,
                    const SizedBox(height: 24),
                    const FamilyCircle()
                  ]),
                ),
                const SizedBox(width: 24),
                Expanded(child: account),
              ],
            )
          else ...[
            wallet,
            const SizedBox(height: 24),
            const FamilyCircle(),
            account,
          ],
        ],
      ),
    );
  }
}

/// Port of components/profile/WalletPanel.vue (dark balance widget + ledger).
class _WalletPanel extends StatelessWidget {
  final num balance;
  final DateTime month;
  final List<Map<String, dynamic>> ledger;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  const _WalletPanel({
    required this.balance,
    required this.month,
    required this.ledger,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CURRENT BALANCE',
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
              Text('$balance',
                  style: const TextStyle(
                      fontSize: 44.8,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: Colors.white)),
              const SizedBox(width: 5),
              const Text('cc',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text('Ledger',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
              IconButton(
                  onPressed: onPrevMonth,
                  icon: const Icon(Icons.chevron_left_rounded,
                      color: AppColors.inkMuted)),
              Text(DateFormat('MMM yyyy').format(month),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              IconButton(
                  onPressed: onNextMonth,
                  icon: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.inkMuted)),
            ],
          ),
          const SizedBox(height: 8),
          if (ledger.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(
                child: Text('No movements this month.',
                    style: TextStyle(fontSize: 13.6, color: Color(0xFF475569))),
              ),
            )
          else
            for (final row in ledger)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          Text(
                              (row['title'] ?? row['reason'] ?? 'Movement')
                                  .toString(),
                              style: const TextStyle(
                                  fontSize: 14.4,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF1F5F9))),
                          if (row['created_at'] != null)
                            Text(
                                DateFormat('d MMM · HH:mm').format(
                                    DateTime.tryParse(
                                            row['created_at'].toString()) ??
                                        DateTime.now()),
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Builder(builder: (_) {
                      final amount = toNum(row['amount']);
                      final positive = amount >= 0;
                      return Text('${positive ? '+' : ''}$amount',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: positive
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFF87171)));
                    }),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
