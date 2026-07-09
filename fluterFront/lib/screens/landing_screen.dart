import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Port of views/LandingView.vue: dark hero with the phone mockup and family
/// figures, "How it works" steps, the tabbed "See it in action" demo, the
/// fairness section with a sample ledger card, closing CTA and footer.
/// All CTAs lead to the login screen.
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
            _buildHero(context, wide),

            // ── How it works ──
            _Section(
              background: AppColors.surface,
              child: Column(
                children: [
                  const _Reveal(
                      child: _SectionHead(
                          'How it works', 'Four steps, one shared ledger.')),
                  _StepsGrid(steps: _steps),
                ],
              ),
            ),

            // ── See it in action ──
            _Section(
              background: AppColors.bg,
              child: Column(
                children: [
                  const _Reveal(
                      child: _SectionHead('See it in action',
                          'A preview of what your family sees every day.')),
                  const _Reveal(delayMs: 90, child: _DemoSection()),
                ],
              ),
            ),

            // ── Fairness, not guesswork ──
            _Section(
              background: AppColors.surface,
              child: LayoutBuilder(builder: (context, c) {
                final isWide = c.maxWidth > kMobileBreakpoint;
                final text = _Reveal(
                  child: Column(
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
                  ),
                );
                final ledger =
                    _Reveal(delayMs: 120, child: _LedgerCard(rows: _ledgerRows));
                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: text),
                          const SizedBox(width: 48),
                          Expanded(child: ledger),
                        ],
                      )
                    : Column(
                        children: [text, const SizedBox(height: 32), ledger]);
              }),
            ),

            // ── CTA ──
            Container(
              color: AppColors.ink,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
              child: _Reveal(
                child: Column(
                  children: [
                    const Text(
                        'Your family\'s shared economy, starting today.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    const Text(
                        'Five minutes to set up. No subscriptions, no algorithms.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 15, color: Color(0xBFFFFFFF))),
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
            ),

            // ── Footer ──
            Container(
              color: AppColors.surface,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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

  Widget _buildHero(BuildContext context, bool wide) {
    final heroText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Entrance(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x24FFFFFF)),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: const Text('For families',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xBFFFFFFF))),
          ),
        ),
        const SizedBox(height: 24),
        _Entrance(
          delayMs: 80,
          child: Text.rich(
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
        ),
        const SizedBox(height: 24),
        const _Entrance(
          delayMs: 160,
          child: SizedBox(
            width: 560,
            child: Text(
              'CareCoins tracks who does what in your household, '
              'pays out coins from a shared monthly budget, and '
              'lets your family spend earnings in a private '
              'rewards store.',
              style: TextStyle(
                  fontSize: 16, height: 1.65, color: Color(0xBFFFFFFF)),
            ),
          ),
        ),
        const SizedBox(height: 36),
        _Entrance(
          delayMs: 240,
          child: Wrap(
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
                      borderRadius: BorderRadius.circular(AppRadii.pill)),
                ),
                child: const Text('Get started free  →',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              OutlinedButton(
                onPressed: onSignIn,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x38FFFFFF)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 26, vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.pill)),
                ),
                child: const Text('Sign in',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
        ),
      ],
    );

    // The illustration column: phone mockup with the family figures below,
    // mirroring .hero-visual. Decorative, so hidden from screen readers.
    final heroVisual = _Entrance(
      delayMs: 320,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _PhoneMockup(),
            SizedBox(height: 20),
            _FamilyFigures(),
          ],
        ),
      ),
    );

    return Container(
      color: AppColors.ink,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: wide ? 72 : 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // The CareCoins coin mark (same asset as the launcher/PWA
                  // icons); its rounded corners are baked into the image.
                  Image.asset('assets/icon/icon-512.png',
                      width: 30,
                      height: 30,
                      cacheWidth:
                          (30 * MediaQuery.devicePixelRatioOf(context))
                              .round()),
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
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: heroText),
                    const SizedBox(width: 64),
                    heroVisual,
                  ],
                )
              else ...[
                heroText,
                const SizedBox(height: 48),
                Center(child: heroVisual),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Motion ───────────────────────────────────────────────────────────

/// One-time page-load entrance (fade + rise) used by the hero. Skipped
/// entirely when the platform asks for reduced motion.
class _Entrance extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _Entrance({required this.child, this.delayMs = 0});

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> {
  bool _shown = false;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    if (MediaQuery.of(context).disableAnimations) {
      _shown = true;
      return;
    }
    Future.delayed(Duration(milliseconds: 60 + widget.delayMs), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutQuart,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutQuart,
        child: widget.child,
      ),
    );
  }
}

/// Scroll-triggered reveal, the Flutter twin of the Vue `[data-reveal]`
/// IntersectionObserver: content is fully laid out from the start (no
/// blank sections if the listener never fires) and fades in the first
/// time it enters the viewport. Reduced motion renders instantly.
class _Reveal extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _Reveal({required this.child, this.delayMs = 0});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _shown = false;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _shown = true;
      return;
    }
    final pos = Scrollable.maybeOf(context)?.position;
    if (!identical(pos, _position)) {
      _position?.removeListener(_check);
      _position = pos?..addListener(_check);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted || _shown) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < MediaQuery.sizeOf(context).height * 0.93) {
      _position?.removeListener(_check);
      if (widget.delayMs == 0) {
        setState(() => _shown = true);
      } else {
        Future.delayed(Duration(milliseconds: widget.delayMs), () {
          if (mounted) setState(() => _shown = true);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutQuart,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : const Offset(0, 0.05),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutQuart,
        child: widget.child,
      ),
    );
  }
}

// ── Hero visual ──────────────────────────────────────────────────────

/// The phone frame from .phone-frame: a miniature of the Daily view with
/// timeline cards, the NOW divider, a free-time gap and the bottom tabs.
/// Purely illustrative; the tiny type mirrors the Vue mockup's scale.
class _PhoneMockup extends StatelessWidget {
  const _PhoneMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0x0FFFFFFF)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x8C000000), blurRadius: 80, offset: Offset(0, 40)),
          BoxShadow(
              color: Color(0x4D000000), blurRadius: 32, offset: Offset(0, 16)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Notch
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            decoration: BoxDecoration(
                color: const Color(0xFF1E2D40),
                borderRadius: BorderRadius.circular(AppRadii.pill)),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Container(
              height: 372,
              color: AppColors.bg,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 8, 14, 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('9:41',
                            style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary)),
                        Text('●●●',
                            style: TextStyle(
                                fontSize: 8.5,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                    decoration: const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: AppColors.border))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Mon, Jun 2',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: AppColors.warningSoft,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill)),
                          child: const Text('🪙 460cc',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.warning)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 7, 14, 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            child: const LinearProgressIndicator(
                              value: 0.4,
                              minHeight: 4,
                              backgroundColor: AppColors.border,
                              valueColor:
                                  AlwaysStoppedAnimation(AppColors.success),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Text('2/5 done',
                            style: TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        const _PsRow('8:00', 'School run (Leo)',
                            '30m · 🪙 15cc ✓', AppColors.primary),
                        const _PsNow(),
                        const _PsRow('14:00', 'Walk the dog', '30m · 🪙 10cc',
                            AppColors.success),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 1),
                          child: Text('1h free',
                              style: TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                        ),
                        const _PsRow('18:00', 'Dinner prep', '45m · 🪙 20cc',
                            AppColors.warning),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
                    decoration: const BoxDecoration(
                      color: Color(0xEBFFFFFF),
                      border:
                          Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _PsNavItem('📅', 'Today', active: true),
                        _PsNavItem('🏠', 'Hub'),
                        _PsNavItem('🏆', 'Rewards'),
                        _PsNavItem('📊', 'Stats'),
                        _PsNavItem('👤', 'Me'),
                      ],
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

class _PsRow extends StatelessWidget {
  final String time;
  final String title;
  final String meta;
  final Color color;

  const _PsRow(this.time, this.title, this.meta, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 10, 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(time,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 1),
                  Text(meta,
                      style: const TextStyle(
                          fontSize: 8, color: Color(0xD1FFFFFF))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PsNow extends StatelessWidget {
  const _PsNow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 1, 10, 1),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.danger, height: 1)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: Text('NOW',
                style: TextStyle(
                    fontSize: 6.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger)),
          ),
          const Expanded(child: Divider(color: AppColors.danger, height: 1)),
        ],
      ),
    );
  }
}

class _PsNavItem extends StatelessWidget {
  final String emoji;
  final String label;
  final bool active;

  const _PsNavItem(this.emoji, this.label, {this.active = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
            opacity: active ? 1 : 0.35,
            child: Text(emoji, style: const TextStyle(fontSize: 13))),
        Text(label,
            style: TextStyle(
                fontSize: 6.5,
                fontWeight: FontWeight.w700,
                color:
                    active ? AppColors.primary : AppColors.textSecondary)),
      ],
    );
  }
}

/// The four family figures from .family-svg, drawn 1:1 from the Vue SVG
/// coordinates (viewBox 200×72) with the semantic accent palette.
class _FamilyFigures extends StatelessWidget {
  const _FamilyFigures();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
        size: Size(150, 54), painter: _FamilyFiguresPainter());
  }
}

class _FamilyFiguresPainter extends CustomPainter {
  const _FamilyFiguresPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200; // scale from the 200×72 viewBox
    void figure(Color color, double cx, double cy, double r, Rect body,
        double rx) {
      final paint = Paint()..color = color;
      canvas.drawCircle(Offset(cx * s, cy * s), r * s, paint);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(body.left * s, body.top * s, body.width * s,
                  body.height * s),
              Radius.circular(rx * s)),
          paint);
    }

    figure(AppColors.primary, 34, 16, 12, const Rect.fromLTWH(22, 31, 24, 30), 7);
    figure(AppColors.success, 74, 19, 11, const Rect.fromLTWH(63, 33, 22, 27), 7);
    figure(AppColors.warning, 110, 26, 9, const Rect.fromLTWH(101, 38, 18, 22), 6);
    figure(AppColors.danger, 143, 31, 7, const Rect.fromLTWH(136, 41, 14, 17), 5);

    canvas.drawLine(
        Offset(12 * s, 62 * s),
        Offset(170 * s, 62 * s),
        Paint()
          ..color = const Color(0x2EFFFFFF)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _FamilyFiguresPainter oldDelegate) => false;
}

// ── How it works ─────────────────────────────────────────────────────

/// The steps grid with the connecting hairline behind the number circles
/// (the Vue `.steps::before`) on wide layouts; stacked on phones.
class _StepsGrid extends StatelessWidget {
  final List<(String, String, Color, Color)> steps;

  const _StepsGrid({required this.steps});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final fourAcross = c.maxWidth > kMobileBreakpoint;
      Widget step(int i) {
        final data = steps[i];
        return _Reveal(
          delayMs: i * 90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: data.$4, shape: BoxShape.circle),
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: data.$3)),
              ),
              const SizedBox(height: 14),
              Text(data.$1,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(data.$2,
                  style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppColors.textSecondary)),
            ],
          ),
        );
      }

      if (!fourAcross) {
        return Column(
          children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                  padding: const EdgeInsets.only(bottom: 28), child: step(i)),
          ],
        );
      }
      return Stack(
        children: [
          Positioned(
            top: 20,
            left: 56,
            right: 56,
            child: Container(height: 1, color: AppColors.border),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 32),
                Expanded(child: step(i)),
              ],
            ],
          ),
        ],
      );
    });
  }
}

// ── See it in action ─────────────────────────────────────────────────

class _DemoSection extends StatefulWidget {
  const _DemoSection();

  @override
  State<_DemoSection> createState() => _DemoSectionState();
}

class _DemoSectionState extends State<_DemoSection> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _demoTab(0, Icons.verified_user_rounded, 'Family Dashboard'),
                const SizedBox(width: 6),
                _demoTab(1, Icons.shopping_bag_rounded, 'Activities & Rewards'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 380),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0D0E1726),
                    blurRadius: 24,
                    offset: Offset(0, 4)),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutQuart,
              switchOutCurve: Curves.easeOutQuart,
              child: _tab == 0
                  ? const _DashboardSim(key: ValueKey('dash'))
                  : const _MarketplaceSim(key: ValueKey('market')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _demoTab(int i, IconData icon, String label) {
    final on = _tab == i;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        onTap: () => setState(() => _tab = i),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        hoverColor: on ? Colors.transparent : AppColors.primarySoft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15,
                  color: on ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Family Hub" demo tab: member cards, KPI minis and the activity feed,
/// mirroring the Vue sim markup with the app's own component vocabulary.
class _DashboardSim extends StatelessWidget {
  const _DashboardSim({super.key});

  static const _members = [
    ('👩🏽', 'Mama', '120', AppColors.primary, AppColors.primarySoft),
    ('👨🏽', 'Papa', '340', AppColors.success, AppColors.successSoft),
    ('👶🏽', 'Leo', '80', AppColors.warning, AppColors.warningSoft),
    ('👧🏽', 'Sofia', '160', AppColors.danger, AppColors.dangerSoft),
  ];

  static const _feed = [
    ('✓', AppColors.primary, AppColors.primarySoft, 'Mama completed ',
        'Clean Room (Sofia)', '2 mins ago', '+20 cc', AppColors.success),
    ('✓', AppColors.primary, AppColors.primarySoft, 'Papa completed ',
        'Feed Pet (Fido)', '1 hour ago', '+10 cc', AppColors.success),
    ('🛍️', AppColors.danger, AppColors.dangerSoft, 'Mama redeemed ',
        'Coffee Treat', '3 hours ago', '-30 cc', AppColors.danger),
  ];

  @override
  Widget build(BuildContext context) {
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ACTIVE FAMILY MEMBERS',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (emoji, name, coins, accent, soft) in _members)
              Container(
                width: 92,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Column(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text(name,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800)),
                    Text('● $coins cc',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: accent)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _SimKpi('FAMILY BALANCE', '460', 'cc', 'across 4 members',
                AppColors.primary, null),
            _SimKpi('TASKS TODAY', '2/5', null, '2 awaiting validation',
                AppColors.success, 0.4),
            _SimKpi('OPEN BOUNTIES', '1', null, '15 cc up for grabs',
                AppColors.warning, null),
            _SimKpi('RECENT ACTIVITY', '3', null, 'completed recently',
                AppColors.textPrimary, null),
          ],
        ),
      ],
    );

    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Activity',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final (icon, fg, bg, verb, subject, time, amt, amtColor) in _feed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Text(icon,
                      style: TextStyle(fontSize: 12, color: fg)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: verb),
                          TextSpan(
                              text: subject,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                        ]),
                        style: const TextStyle(fontSize: 12.5, height: 1.4),
                      ),
                      Row(
                        children: [
                          Text(time,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                          const Spacer(),
                          Text(amt,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: amtColor)),
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

    return LayoutBuilder(builder: (context, c) {
      final isWide = c.maxWidth > 640;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Family Hub',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Good morning, Mama! Your family has earned '),
              TextSpan(
                  text: '460 cc',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              TextSpan(text: ' today. '),
              TextSpan(
                  text: '2 tasks',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              TextSpan(text: ' are waiting for validation.'),
            ]),
            style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: left),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: right),
              ],
            )
          else ...[
            left,
            const SizedBox(height: 20),
            right,
          ],
        ],
      );
    });
  }
}

class _SimKpi extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String subtitle;
  final Color accent;
  final double? progress;

  const _SimKpi(this.label, this.value, this.unit, this.subtitle, this.accent,
      this.progress);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: accent)),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(unit!,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.success),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Activities & Rewards" demo tab: task templates and the rewards store.
class _MarketplaceSim extends StatelessWidget {
  const _MarketplaceSim({super.key});

  @override
  Widget build(BuildContext context) {
    final templates = _simCard('Task Templates', const [
      ('📚', AppColors.primary, 'Do Homework', 'Care · 60 min', '+15 cc'),
      ('🌱', AppColors.success, 'Walk the Dog', 'Household · 30 min',
          '+10 cc'),
    ]);
    final rewards = _simCard('Rewards Store', const [
      ('🎮', AppColors.warning, '1 Hour Video Games', 'Cost: 50 cc · 3 left',
          'Redeem'),
      ('🍦', AppColors.danger, 'Ice Cream Treat', 'Cost: 30 cc', 'Redeem'),
    ]);

    return LayoutBuilder(builder: (context, c) {
      final isWide = c.maxWidth > 640;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Activities & Rewards Store',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🪙 ', style: TextStyle(fontSize: 12)),
                    Text('460',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                    Text('  Family Pool',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: templates),
                const SizedBox(width: 16),
                Expanded(child: rewards),
              ],
            )
          else ...[
            templates,
            const SizedBox(height: 16),
            rewards,
          ],
        ],
      );
    });
  }

  Widget _simCard(
      String title, List<(String, Color, String, String, String)> items) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final (emoji, color, name, sub, badge) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppRadii.sm)),
                    child:
                        Text(emoji, style: const TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700)),
                        Text(sub,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  badge == 'Redeem'
                      ? const PillBadge(
                          text: 'Redeem',
                          fontSize: 11,
                          color: Colors.white,
                          background: AppColors.primary)
                      : PillBadge(
                          text: badge,
                          fontSize: 11,
                          color: AppColors.success,
                          background: AppColors.successSoft),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shared section chrome ────────────────────────────────────────────

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
