import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Port of views/LandingView.vue (condensed): dark hero, "How it works"
/// steps, the fairness section with a sample ledger card, closing CTA and
/// footer. All CTAs lead to the login screen.
class LandingScreen extends StatelessWidget {
  final VoidCallback onSignIn;

  const LandingScreen({super.key, required this.onSignIn});

  static const _steps = [
    (
      'Define tasks',
      'Create templates for care and household work. Set a coin value and duration for each one.',
      AppColors.primary,
      AppColors.primarySoft,
    ),
    (
      'Schedule routines',
      'Place tasks on a shared daily timeline. Set up recurring assignments across caregivers.',
      AppColors.success,
      AppColors.successSoft,
    ),
    (
      'Complete and earn',
      'Members check off tasks. Caregivers validate with a tap — coins land immediately in the earner\'s account.',
      AppColors.warning,
      AppColors.warningSoft,
    ),
    (
      'Spend on rewards',
      'Your family\'s private store holds whatever you decide is worth earning toward. Coins spent, rewards given.',
      AppColors.danger,
      AppColors.dangerSoft,
    ),
  ];

  static const _ledgerRows = [
    ('Today', 'Mama', 'Redeemed: Coffee Treat', '-30 cc', AppColors.danger),
    ('Today', 'Papa', 'Completed: Feed Pet (Fido)', '+10 cc', AppColors.success),
    (
      'Yesterday',
      'Mama',
      'Completed: Clean Room (Sofia)',
      '+20 cc',
      AppColors.success
    ),
    ('Yesterday', 'System', 'Budget allocation', '+500 cc', AppColors.success),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = isWideLayout(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero ──
            Container(
              color: AppColors.ink,
              padding: EdgeInsets.symmetric(
                  horizontal: 24, vertical: wide ? 72 : 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nav row
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                                gradient: AppColors.accentGradient,
                                shape: BoxShape.circle),
                            child: const Text('¢',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                          ),
                          const SizedBox(width: 8),
                          const Text('CareCoins',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Colors.white)),
                          const Spacer(),
                          TextButton(
                            onPressed: onSignIn,
                            child: const Text('Sign in',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      SizedBox(height: wide ? 72 : 48),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0x24FFFFFF)),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: const Text('For families',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xA6FFFFFF))),
                      ),
                      const SizedBox(height: 24),
                      Text.rich(
                        const TextSpan(children: [
                          TextSpan(text: 'Every caregiver counted.\n'),
                          TextSpan(
                              text: 'Every task rewarded.',
                              style: TextStyle(color: Color(0xFF93C5FD))),
                        ]),
                        style: TextStyle(
                            fontSize: wide ? 56 : 34,
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                            letterSpacing: -1.5,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      const SizedBox(
                        width: 560,
                        child: Text(
                          'CareCoins tracks who does what in your household, '
                          'pays out coins from a shared monthly budget, and '
                          'lets your family spend earnings in a private '
                          'rewards store.',
                          style: TextStyle(
                              fontSize: 16,
                              height: 1.65,
                              color: Color(0xBFFFFFFF)),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Wrap(
                        spacing: 14,
                        runSpacing: 12,
                        children: [
                          FilledButton(
                            onPressed: onSignIn,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 26, vertical: 18),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.pill)),
                            ),
                            child: const Text('Get started free  →',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                          ),
                          OutlinedButton(
                            onPressed: onSignIn,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side:
                                  const BorderSide(color: Color(0x38FFFFFF)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 26, vertical: 18),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.pill)),
                            ),
                            child: const Text('Sign in',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── How it works ──
            _Section(
              background: AppColors.surface,
              child: Column(
                children: [
                  const _SectionHead(
                      'How it works', 'Four steps, one shared ledger.'),
                  LayoutBuilder(builder: (context, c) {
                    final perRow = c.maxWidth > kMobileBreakpoint ? 4 : 1;
                    final w = (c.maxWidth - (perRow - 1) * 24) / perRow;
                    return Wrap(
                      spacing: 24,
                      runSpacing: 28,
                      children: [
                        for (final (i, step) in _steps.indexed)
                          SizedBox(
                            width: w,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: step.$4,
                                      shape: BoxShape.circle),
                                  child: Text('${i + 1}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: step.$3)),
                                ),
                                const SizedBox(height: 14),
                                Text(step.$1,
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Text(step.$2,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.6,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),

            // ── Fairness, not guesswork ──
            _Section(
              background: AppColors.bg,
              child: LayoutBuilder(builder: (context, c) {
                final isWide = c.maxWidth > kMobileBreakpoint;
                final text = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fairness, not guesswork',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 14),
                    const Text(
                        'Chore charts get ignored because they carry no '
                        'weight. CareCoins puts a real value on caregiving '
                        'work — tracked, validated, and paid out from a '
                        'budget the whole family can see.',
                        style: TextStyle(
                            fontSize: 15,
                            height: 1.65,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 28),
                    for (final (icon, title, body) in [
                      (
                        Icons.trending_up_rounded,
                        'Contribution history at a glance',
                        'See who did what this month, this year, and since '
                            'you started. Charts by category, person, and trend.'
                      ),
                      (
                        Icons.verified_user_rounded,
                        'One family, one ledger',
                        'Every coin earned and spent is recorded. Caregivers '
                            'approve tasks; the ledger does not lie.'
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 20, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5)),
                                  const SizedBox(height: 4),
                                  Text(body,
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          height: 1.55,
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
                final ledger = _LedgerCard(rows: _ledgerRows);
                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: text),
                          const SizedBox(width: 48),
                          Expanded(child: ledger),
                        ],
                      )
                    : Column(children: [text, const SizedBox(height: 32), ledger]);
              }),
            ),

            // ── CTA ──
            Container(
              color: AppColors.ink,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
              child: Column(
                children: [
                  const Text('Your family\'s shared economy, starting today.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Colors.white)),
                  const SizedBox(height: 12),
                  const Text('Five minutes to set up. No subscriptions, no algorithms.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15, color: Color(0xBFFFFFFF))),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: onSignIn,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadii.pill)),
                    ),
                    child: const Text('Create your family  →',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ],
              ),
            ),

            // ── Footer ──
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Row(
                    children: [
                      const Text('CareCoins',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('© 2026. All rights reserved.',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary)),
                      ),
                      TextButton(
                          onPressed: onSignIn, child: const Text('Log in')),
                      TextButton(
                          onPressed: onSignIn, child: const Text('Register')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final Color background;
  final Widget child;

  const _Section({required this.background, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080), child: child),
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHead(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 44),
      child: Column(
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// The "Recent transactions" sample card from the fairness section.
class _LedgerCard extends StatelessWidget {
  final List<(String, String, String, String, Color)> rows;

  const _LedgerCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 30, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Recent transactions',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              PillBadge(
                  text: 'Verified',
                  color: AppColors.success,
                  background: AppColors.successSoft,
                  fontSize: 11),
            ],
          ),
          const SizedBox(height: 14),
          for (final (date, name, desc, amount, color) in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(date,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800)),
                        Text(desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text(amount,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
