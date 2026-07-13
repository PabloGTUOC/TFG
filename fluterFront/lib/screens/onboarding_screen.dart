import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Port of views/OnboardingView.vue: create-family wizard (details,
/// additional caretakers, objects of care), pending invitations with an
/// alias prompt, and join by invite link/token.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _CaretakerEntry {
  final name = TextEditingController();
  final email = TextEditingController();

  void dispose() {
    name.dispose();
    email.dispose();
  }
}

class _CareObjectEntry {
  final name = TextEditingController();
  String type = 'child';
  String careTime = 'full_time';

  void dispose() => name.dispose();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _familyName = TextEditingController();
  final _alias = TextEditingController();
  final _mainCaretakerName = TextEditingController();
  final _token = TextEditingController();
  final _tokenAlias = TextEditingController();
  final List<_CaretakerEntry> _caretakers = [_CaretakerEntry()];
  final List<_CareObjectEntry> _careObjects = [_CareObjectEntry()];
  List<dynamic> _invites = [];

  List<(String, String)> _typeOptions(AppLocalizations l) => [
        ('child', l.typeChildPlain),
        ('elderly', l.typeElderlyPlain),
        ('pet', l.typePetPlain),
      ];
  List<(String, String)> _careTimeOptions(AppLocalizations l) => [
        ('full_time', l.careFullTime),
        ('part_time', l.carePartTime),
      ];

  @override
  void initState() {
    super.initState();
    _mainCaretakerName.text =
        context.read<AppState>().profile?['display_name']?.toString() ?? '';
    _loadInvites();
  }

  @override
  void dispose() {
    _familyName.dispose();
    _alias.dispose();
    _mainCaretakerName.dispose();
    _token.dispose();
    _tokenAlias.dispose();
    for (final c in _caretakers) {
      c.dispose();
    }
    for (final o in _careObjects) {
      o.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInvites() async {
    try {
      final data = await context.read<AppState>().api.get('/api/me/invites');
      if (mounted) {
        setState(() =>
            _invites = data is List ? data : (data['invites'] as List? ?? []));
      }
    } catch (_) {}
  }

  Future<void> _createFamily() async {
    final app = context.read<AppState>();
    if (_familyName.text.trim().isEmpty) {
      app.setError(AppLocalizations.of(context).errFamilyNameRequired);
      return;
    }
    await app.runAction(() async {
      await app.api.post('/api/families', {
        'name': _familyName.text.trim(),
        'alias': _alias.text.trim().isEmpty ? null : _alias.text.trim(),
        'mainCaretakerName': _mainCaretakerName.text.trim(),
        'caretakers': [
          for (final c in _caretakers)
            if (c.email.text.trim().isNotEmpty)
              {'name': c.name.text.trim(), 'email': c.email.text.trim()},
        ],
        'objectsOfCare': [
          for (final o in _careObjects)
            if (o.name.text.trim().isNotEmpty)
              {
                'name': o.name.text.trim(),
                'type': o.type,
                'careTime': o.careTime,
              },
        ],
      });
      await app.fetchUserData();
    }, AppLocalizations.of(context).toastFamilyCreated);
  }

  Future<void> _joinByToken() async {
    final app = context.read<AppState>();
    final l = AppLocalizations.of(context);
    // Accept a full invite link or a bare token (mirror of joinByToken).
    final match = RegExp(
            r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
            caseSensitive: false)
        .firstMatch(_token.text.trim());
    if (match == null) {
      app.setError(l.errNoValidToken);
      return;
    }
    await app.runAction(() async {
      await app.api.post('/api/families/join-by-token', {
        'token': match.group(0),
        if (_tokenAlias.text.trim().isNotEmpty)
          'alias': _tokenAlias.text.trim(),
      });
      await app.fetchUserData();
    }, l.toastJoinedFamily);
  }

  Future<void> _acceptInvite(Map invite) async {
    final app = context.read<AppState>();
    final l = AppLocalizations.of(context);
    final aliasCtl = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg)),
        title: Text(
            l.joinFamilyPrompt(
                (invite['family_name'] ?? l.fallbackFamily).toString()),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: VInput(
            controller: aliasCtl,
            label: l.aliasOptional,
            placeholder: l.aliasJoinHint),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.join)),
        ],
      ),
    );
    if (accepted != true) {
      aliasCtl.dispose();
      return;
    }
    await app.runAction(() async {
      await app.api.post('/api/families/join-request', {
        'familyId': invite['family_id'],
        if (aliasCtl.text.trim().isNotEmpty) 'alias': aliasCtl.text.trim(),
      });
      await app.fetchUserData();
    }, l.toastJoinedFamily);
    aliasCtl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final wide = isWideLayout(context);
    final l = AppLocalizations.of(context);

    final createCard = _buildCreateWizard(app);

    final joinCard = VCard(
      title: l.joinTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.joinIntro,
              style: const TextStyle(
                  color: AppColors.textSecondary, height: 1.6)),
          const SizedBox(height: 20),
          VInput(
              controller: _token,
              label: l.inviteLinkOrToken,
              placeholder: l.inviteLinkHint),
          const SizedBox(height: 14),
          VInput(
              controller: _tokenAlias,
              label: l.aliasOptional,
              placeholder: l.aliasGrandmaHint),
          const SizedBox(height: 20),
          VButton(
              type: VButtonType.outline,
              onPressed: _joinByToken,
              block: true,
              child: Text(l.joinFamilyBtn)),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  PageHeading(
                      title: l.onboardingTitle,
                      subtitle: l.onboardingSubtitle),
                  if (app.pendingRequests.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Text(
                        l.requestPending(
                            ((app.pendingRequests.first as Map)['name'] ??
                                    l.fallbackAFamily)
                                .toString()),
                        style: const TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (_invites.isNotEmpty)
                    VCard(
                      title: l.invitedToJoin,
                      child: Column(
                        children: [
                          for (final inv in _invites)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            ((inv as Map)['family_name'] ??
                                                    l.fallbackFamily)
                                                .toString(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800)),
                                        Text(
                                            l.invitedBy((inv['inviter_name'] ??
                                                    l.fallbackAMember)
                                                .toString()),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  VButton(
                                      onPressed: () => _acceptInvite(inv),
                                      child: Text(l.accept)),
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
                        Expanded(flex: 3, child: createCard),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: joinCard),
                      ],
                    )
                  else ...[createCard, joinCard],
                  Center(
                    child: TextButton(
                      onPressed: () => app.logout(),
                      child: Text(l.menuLogout,
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateWizard(AppState app) {
    final l = AppLocalizations.of(context);
    return VCard(
      title: l.setupFamilyTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Family details ──
          _StepTitle(l.step1Title, l.step1Desc),
          VInput(
              controller: _familyName,
              label: l.familyNameLabel,
              placeholder: l.familyNameHint),
          const SizedBox(height: 12),
          VInput(
              controller: _alias,
              label: l.aliasRoleLabel,
              placeholder: l.aliasRoleHint),
          const Divider(height: 36),

          // ── 2. Caregivers ──
          _StepTitle(l.step2Title, l.step2Desc),
          VInput(
              controller: _mainCaretakerName,
              label: l.yourDisplayName,
              placeholder: l.yourNameHint),
          const SizedBox(height: 6),
          Text((app.profile?['email'] ?? '').toString(),
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          for (final (i, c) in _caretakers.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Short placeholders: the long ones truncated to
                  // "Name (op…" / "caregiver…" on 390dp-wide screens.
                  Expanded(
                      child: VInput(
                          controller: c.name, placeholder: l.nameLabel)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: VInput(
                          controller: c.email,
                          placeholder: l.emailAddressHint,
                          keyboardType: TextInputType.emailAddress)),
                  IconButton(
                    onPressed: () => setState(() {
                      _caretakers.removeAt(i).dispose();
                    }),
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: AppColors.danger),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: VButton(
                type: VButtonType.outline,
                onPressed: () =>
                    setState(() => _caretakers.add(_CaretakerEntry())),
                child: Text(l.addAnotherCaregiver)),
          ),
          const Divider(height: 36),

          // ── 3. Objects of care ──
          _StepTitle(l.step3Title, l.step3Desc),
          for (final (i, o) in _careObjects.indexed)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: VInput(
                              controller: o.name,
                              placeholder: l.careObjectNameHint)),
                      IconButton(
                        onPressed: () => setState(() {
                          _careObjects.removeAt(i).dispose();
                        }),
                        icon: const Icon(Icons.close_rounded,
                            size: 20, color: AppColors.danger),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: o.type,
                          isExpanded: true,
                          decoration: const InputDecoration(isDense: true),
                          items: [
                            for (final (v, label) in _typeOptions(l))
                              DropdownMenuItem(value: v, child: Text(label)),
                          ],
                          onChanged: (v) =>
                              setState(() => o.type = v ?? 'child'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        // isExpanded ellipsizes the long "Full Time (24
                        // coins/day)" label instead of colliding with the
                        // dropdown arrow on narrow screens.
                        child: DropdownButtonFormField<String>(
                          initialValue: o.careTime,
                          isExpanded: true,
                          decoration: const InputDecoration(isDense: true),
                          items: [
                            for (final (v, label) in _careTimeOptions(l))
                              DropdownMenuItem(
                                  value: v,
                                  child: Text(label,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13))),
                          ],
                          onChanged: (v) =>
                              setState(() => o.careTime = v ?? 'full_time'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: VButton(
                type: VButtonType.outline,
                onPressed: () =>
                    setState(() => _careObjects.add(_CareObjectEntry())),
                child: Text(l.addSomeoneToCareFor)),
          ),
          const SizedBox(height: 24),
          VButton(
              onPressed: _createFamily,
              block: true,
              child: Text(l.completeSetup)),
        ],
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  final String title;
  final String description;
  const _StepTitle(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(description,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}
