import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/push_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'activities_screen.dart';
import 'dashboard_screen.dart';
import 'marketplace_screen.dart';
import 'profile_screen.dart';
import 'stats_screen.dart';

/// Port of App.vue: pill header (logo, desktop nav, coin counter, avatar menu)
/// plus the mobile bottom tab bar with the same five tabs.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  // Lazy tab construction: a tab's screen (and its API calls) is only built
  // on first visit instead of firing ~10 requests at startup.
  final Set<int> _visited = {0};
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Port of the Vue visibilitychange refetch: refresh /api/me on resume.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (mounted) context.read<AppState>().fetchUserData();
      },
    );
    // Silent FCM re-registration when permission was already granted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) PushService.init(context.read<AppState>());
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Family'),
    (icon: Icons.calendar_today_rounded, label: 'Activities'),
    (icon: Icons.shopping_bag_rounded, label: 'Rewards'),
    (icon: Icons.bar_chart_rounded, label: 'Stats'),
    (icon: Icons.person_rounded, label: 'Me'),
  ];

  /// Navigate to a tab, marking it visited so it gets built.
  void _go(int i) => setState(() {
        _index = i;
        _visited.add(i);
      });

  @override
  Widget build(BuildContext context) {
    final wide = isWideLayout(context);

    // `active` tells a screen it just became the visible tab so it can
    // silently refetch — without it, tabs go stale (IndexedStack keeps
    // them alive but initState never runs again).
    final screens = [
      DashboardScreen(active: _index == 0, onOpenStats: () => _go(3)),
      ActivitiesScreen(active: _index == 1),
      MarketplaceScreen(active: _index == 2),
      StatsScreen(active: _index == 3),
      ProfileScreen(active: _index == 4),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _PillHeader(
              wide: wide,
              index: _index,
              onNavigate: _go,
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1140),
                  child: IndexedStack(
                    index: _index,
                    children: [
                      for (var i = 0; i < screens.length; i++)
                        if (_visited.contains(i))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: screens[i],
                          )
                        else
                          const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      for (var i = 0; i < _tabs.length; i++)
                        Expanded(
                          child: InkWell(
                            onTap: () => _go(i),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_tabs[i].icon,
                                    size: 22,
                                    color: i == _index
                                        ? AppColors.primary
                                        : AppColors.textSecondary),
                                const SizedBox(height: 2),
                                Text(_tabs[i].label,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: i == _index
                                            ? AppColors.primary
                                            : AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _PillHeader extends StatelessWidget {
  final bool wide;
  final int index;
  final ValueChanged<int> onNavigate;

  const _PillHeader(
      {required this.wide, required this.index, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final family = app.family;
    final alias =
        (family?['alias'] ?? app.profile?['display_name'] ?? 'C').toString();
    final balance = family?['coin_balance']?.toString() ?? '0';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 18, 12, 8),
      constraints: const BoxConstraints(maxWidth: 1140),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A0E1726), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Logo
          InkWell(
            onTap: () => onNavigate(0),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Row(
              children: [
                // Port of App.vue .logo-mark: primary square with the same
                // coin mark the PWA/launcher icons use (icon-mark.svg).
                Container(
                  width: wide ? 32 : 24,
                  height: wide ? 32 : 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadii.sm)),
                  child: Image.asset('assets/icon/icon-512.png',
                      width: 18,
                      height: 18,
                      cacheWidth:
                          (18 * MediaQuery.devicePixelRatioOf(context))
                              .round()),
                ),
                const SizedBox(width: 8),
                const Text('CareCoins',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
          const Spacer(),
          if (wide && app.hasFamilies) ...[
            _NavLink(
                label: 'Family',
                icon: Icons.home_rounded,
                active: index == 0,
                onTap: () => onNavigate(0)),
            _NavLink(
                label: 'Activities',
                icon: Icons.calendar_today_rounded,
                active: index == 1,
                onTap: () => onNavigate(1)),
            _NavLink(
                label: 'Marketplace',
                icon: Icons.shopping_bag_rounded,
                active: index == 2,
                onTap: () => onNavigate(2)),
            _NavLink(
                label: 'Personal',
                icon: Icons.person_rounded,
                active: index == 4,
                onTap: () => onNavigate(4)),
            const Spacer(),
          ],
          // Coin counter
          if (app.hasFamilies)
            InkWell(
              onTap: () => onNavigate(4),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Row(
                  children: [
                    AvatarCircle(
                        name: alias,
                        size: 24,
                        background: AppColors.warning,
                        foreground: Colors.white),
                    const SizedBox(width: 8),
                    Text(balance,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning)),
                    const SizedBox(width: 3),
                    const Text('cc',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning)),
                  ],
                ),
              ),
            ),
          if (wide) ...[
            const SizedBox(width: 10),
            PopupMenuButton<String>(
              tooltip: 'User Menu',
              offset: const Offset(0, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md)),
              onSelected: (v) {
                if (v == 'logout') app.logout();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'logout', child: Text('Logout')),
              ],
              child: AvatarCircle(
                  name: (app.profile?['display_name'] ?? app.user?.email ?? '?')
                      .toString(),
                  imageUrl: app.profile?['avatar_url']?.toString(),
                  size: 34),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavLink(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: active ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? AppColors.primary
                          : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
