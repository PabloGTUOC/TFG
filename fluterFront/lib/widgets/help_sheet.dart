import 'package:flutter/material.dart';

import '../services/tour_service.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// "How CareCoins works" — the always-available help surface from
/// docs/onboarding-help-plan.md (Phase 1). Bottom sheet on phones, centered
/// dialog on wide layouts. Copy mirrors the landing page's four steps so the
/// story users saw before signing up is the one the app tells inside.
Future<void> showHelpSheet(BuildContext context) {
  if (isWideLayout(context)) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
          child: const _HelpContent(),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg))),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.88),
        child: const _HelpContent(),
      ),
    ),
  );
}

// ── Copy (single source; mirror into the Vue frontend when porting) ──

const _steps = [
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

const _glossary = [
  (
    'CareCoin (cc)',
    'The family\'s own currency. Coins have no real-money value: they make contribution visible and buy rewards in your family\'s store.'
  ),
  (
    'Monthly budget',
    'Each month the family pool (1,000 cc by default) is allocated. Task coin values draw from it — the Budget gauge in Activities shows what\'s left.'
  ),
  (
    'Template vs. scheduled task',
    'A template describes a job: title, duration, coin value. Scheduling places a copy of it on a specific day and time.'
  ),
  (
    'Validation',
    'After someone marks a task done, a caregiver confirms it. Only then do the coins land in the earner\'s wallet.'
  ),
  (
    'Bounty',
    'Bonus coins a caregiver attaches to a task to make it more attractive. Whoever takes the task over earns the bonus on completion.'
  ),
  (
    'Object of care',
    'Someone (or something) you care for who doesn\'t use the app themselves: a child, an elderly relative, a pet.'
  ),
  (
    'Ledger',
    'The record of every coin earned and spent. A caregiver can revert an entry from the Personal Area if something was validated by mistake.'
  ),
];

const _faq = [
  (
    'Where do coins come from?',
    'From the family\'s monthly budget. Once a month the pool is distributed, and every task you define carries a value paid out of it. Nothing is bought with real money.'
  ),
  (
    'Why does a new activity need approval?',
    'Caregivers review new tasks before they enter the catalogue so coin values stay fair. You\'ll find pending ones in the Activities tab.'
  ),
  (
    'Why can\'t I change a completed activity?',
    'Completed means validated and paid: the coins are already in someone\'s wallet. To undo one, revert its coin entry from the ledger in the Personal Area.'
  ),
  (
    'How do I make a task repeat?',
    'Mark it as recurring (🔁) when you create it. Then, in the Daily view, tap its card before it\'s validated and choose how far into the future to copy it.'
  ),
  (
    'What is a bounty and how do I use one?',
    'Open a scheduled task in the Daily view and delegate it with extra coins attached. It appears under Task Offers on the Family hub until someone takes it.'
  ),
  (
    'Who can create rewards?',
    'Caregivers, from the Rewards tab. The store is private to your family — a reward can be anything you agree is worth earning toward.'
  ),
];

// ── Widgets ──────────────────────────────────────────────────────────

class _HelpContent extends StatelessWidget {
  const _HelpContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 12, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('How CareCoins works',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close help',
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            children: [
              const Text(
                'Tasks earn coins from your family\'s monthly budget; coins '
                'buy rewards in your family\'s private store. That\'s the '
                'whole economy — here it is in four steps.',
                style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              for (final (i, step) in _steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: step.$4, shape: BoxShape.circle),
                        child: Text('${i + 1}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: step.$3)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(step.$1,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(step.$2,
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
              const _HelpSectionTitle('Glossary'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                child: Column(
                  children: [
                    for (final (i, entry) in _glossary.indexed) ...[
                      if (i > 0)
                        const Divider(color: AppColors.border, height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 118,
                              child: Text(entry.$1,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(entry.$2,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      height: 1.5,
                                      color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const _HelpSectionTitle('Common questions'),
              for (final (q, a) in _faq)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    // Strip the ExpansionTile's default divider lines.
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      title: Text(q,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      iconColor: AppColors.textSecondary,
                      collapsedIconColor: AppColors.textSecondary,
                      expandedCrossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(a,
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.55,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              // Phase 2: forget the tab tours; screens listening to
              // TourService re-run their coach marks, starting with the
              // tab that's currently visible.
              VButton(
                type: VButtonType.outline,
                block: true,
                onPressed: () {
                  TourService.I.resetTabTours();
                  Navigator.pop(context);
                },
                child: const Text('Replay the guided tour'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HelpSectionTitle extends StatelessWidget {
  final String text;

  const _HelpSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Text(text,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3)),
    );
  }
}
