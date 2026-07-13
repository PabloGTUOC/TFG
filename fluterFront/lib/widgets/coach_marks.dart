import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/telemetry.dart';
import '../services/tour_service.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// One spotlight step of a guided tour: the widget under [targetKey] is cut
/// out of a dark scrim with [title]/[body] explained alongside.
class CoachMark {
  final GlobalKey targetKey;
  final String title;
  final String body;

  const CoachMark({
    required this.targetKey,
    required this.title,
    required this.body,
  });
}

bool _tourRunning = false;

/// Runs the [tourId] tour once: checks the seen-flag, shows the marks whose
/// targets are actually rendered, then records the tour as seen (skipping
/// counts as seen — being interrupted twice is worse than once).
Future<void> maybeShowTour(
    BuildContext context, String tourId, List<CoachMark> marks) async {
  if (_tourRunning) return;
  if (!await TourService.I.shouldShow(tourId)) return;
  if (!context.mounted) return;
  final valid = marks
      .where((m) =>
          m.targetKey.currentContext?.findRenderObject() is RenderBox)
      .toList();
  if (valid.isEmpty) return;

  _tourRunning = true;
  try {
    final completed = await Navigator.of(context, rootNavigator: true)
        .push<bool>(PageRouteBuilder(
      opaque: false,
      pageBuilder: (_, __, ___) => _CoachOverlay(marks: valid),
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
    Telemetry.log(completed == true ? 'tour_completed' : 'tour_skipped',
        {'tour': tourId});
    await TourService.I.markSeen(tourId);
  } finally {
    _tourRunning = false;
  }
}

class _CoachOverlay extends StatefulWidget {
  final List<CoachMark> marks;

  const _CoachOverlay({required this.marks});

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay> {
  int _index = 0;
  Rect? _target;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusCurrent());
  }

  CoachMark get _mark => widget.marks[_index];

  /// Scrolls the current target into view, then measures its global rect.
  Future<void> _focusCurrent() async {
    final ctx = _mark.targetKey.currentContext;
    if (ctx == null) {
      _advance();
      return;
    }
    final reduced = MediaQuery.of(context).disableAnimations;
    await Scrollable.ensureVisible(ctx,
        alignment: 0.35,
        duration:
            reduced ? Duration.zero : const Duration(milliseconds: 250),
        curve: Curves.easeOutQuart);
    if (!mounted) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) {
      _advance();
      return;
    }
    setState(() {
      _target =
          (box.localToGlobal(Offset.zero) & box.size).inflate(6);
    });
  }

  void _advance() {
    if (_index + 1 >= widget.marks.length) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _index++;
      _target = null;
    });
    _focusCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final target = _target;
    final reduced = MediaQuery.of(context).disableAnimations;
    final fade = reduced ? Duration.zero : const Duration(milliseconds: 180);

    // Tooltip card geometry: prefer whichever side of the target has room,
    // and clamp to the viewport either way — tall targets (e.g. the phone
    // week agenda) can span most of the screen, and anchoring blindly to
    // their top edge would push the card off-screen.
    final pad = MediaQuery.paddingOf(context);
    const cardSpace = 220.0; // tooltip height incl. margins, worst case
    final cardWidth = size.width < 400 ? size.width - 32.0 : 340.0;
    double? cardTop, cardBottom;
    var cardLeft = 16.0;
    if (target != null) {
      cardLeft = target.left.clamp(16.0, size.width - cardWidth - 16.0);
      final spaceBelow = size.height - pad.bottom - target.bottom;
      final spaceAbove = target.top - pad.top;
      if (spaceBelow >= cardSpace || spaceBelow >= spaceAbove) {
        cardTop = (target.bottom + 14)
            .clamp(pad.top + 16.0, size.height - pad.bottom - cardSpace);
      } else {
        // Above the target; never let the card's bottom edge rise so high
        // that the card itself leaves the screen.
        cardBottom = (size.height - target.top + 14)
            .clamp(pad.bottom + 16.0, size.height - pad.top - cardSpace);
      }
    }

    return AnimatedSwitcher(
      duration: fade,
      child: target == null
          ? const SizedBox.expand()
          : Stack(
              key: ValueKey(_index),
              children: [
                // Scrim with the spotlight cutout. Tapping anywhere advances.
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _advance,
                    child: CustomPaint(
                        painter: _SpotlightPainter(cutout: target)),
                  ),
                ),
                Positioned(
                  left: cardLeft,
                  width: cardWidth,
                  top: cardTop,
                  bottom: cardBottom,
                  child: _TooltipCard(
                    title: _mark.title,
                    body: _mark.body,
                    stepLabel: '${_index + 1}/${widget.marks.length}',
                    isLast: _index + 1 >= widget.marks.length,
                    onNext: _advance,
                    onSkip: () => Navigator.of(context).pop(false),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect cutout;

  const _SpotlightPainter({required this.cutout});

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(14)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, scrim, hole),
      // Ink at 78%: dark enough to focus, light enough to keep context.
      Paint()..color = const Color(0xC70E1726),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.cutout != cutout;
}

class _TooltipCard extends StatelessWidget {
  final String title;
  final String body;
  final String stepLabel;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TooltipCard({
    required this.title,
    required this.body,
    required this.stepLabel,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: const [
            BoxShadow(
                color: Color(0x330E1726),
                blurRadius: 30,
                offset: Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(body,
                style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(AppLocalizations.of(context).skipTour,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary)),
                    ),
                  ),
                ),
                Text(stepLabel,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                VButton(
                    onPressed: onNext,
                    child: Text(isLast
                        ? AppLocalizations.of(context).gotIt
                        : AppLocalizations.of(context).next)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
