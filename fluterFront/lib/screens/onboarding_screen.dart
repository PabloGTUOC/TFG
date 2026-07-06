import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Port of views/OnboardingView.vue: create a family, join by invite or token.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _familyName = TextEditingController();
  final _alias = TextEditingController();
  final _token = TextEditingController();
  final _tokenAlias = TextEditingController();
  List<dynamic> _invites = [];

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  @override
  void dispose() {
    _familyName.dispose();
    _alias.dispose();
    _token.dispose();
    _tokenAlias.dispose();
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
      app.setError('Family name is required.');
      return;
    }
    final ok = await app.runAction(() async {
      await app.api.post('/api/families', {
        'name': _familyName.text.trim(),
        'alias': _alias.text.trim().isEmpty ? null : _alias.text.trim(),
        'caretakers': const [],
        'objectsOfCare': const [],
      });
      await app.fetchUserData();
    }, 'Family created!');
    if (ok) _familyName.clear();
  }

  Future<void> _joinByToken() async {
    final app = context.read<AppState>();
    if (_token.text.trim().isEmpty) {
      app.setError('Enter an invite code.');
      return;
    }
    await app.runAction(() async {
      await app.api.post('/api/families/join-by-token', {
        'token': _token.text.trim(),
        if (_tokenAlias.text.trim().isNotEmpty)
          'alias': _tokenAlias.text.trim(),
      });
      await app.fetchUserData();
    }, 'Joined family!');
  }

  Future<void> _acceptInvite(Map invite) async {
    final app = context.read<AppState>();
    await app.runAction(() async {
      await app.api.post(
          '/api/families/join-request', {'familyId': invite['family_id']});
      await app.fetchUserData();
    }, 'Join request sent!');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final wide = MediaQuery.sizeOf(context).width > kMobileBreakpoint;

    final createCard = VCard(
      title: 'Create a Family',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Start a new care circle and invite the rest later.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
          const SizedBox(height: 20),
          VInput(
              controller: _familyName,
              label: 'Family Name',
              placeholder: 'e.g. The Torres Family'),
          const SizedBox(height: 14),
          VInput(
              controller: _alias,
              label: 'Your Alias (optional)',
              placeholder: 'e.g. Mom, Pablo…'),
          const SizedBox(height: 20),
          VButton(
              onPressed: _createFamily,
              block: true,
              child: const Text('Create Family')),
        ],
      ),
    );

    final joinCard = VCard(
      title: 'Join a Family',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
              'Got an invite code? Enter it here to join an existing family.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
          const SizedBox(height: 20),
          VInput(
              controller: _token,
              label: 'Invite Code',
              placeholder: 'Paste your code'),
          const SizedBox(height: 14),
          VInput(
              controller: _tokenAlias,
              label: 'Your Alias (optional)',
              placeholder: 'e.g. Grandma'),
          const SizedBox(height: 20),
          VButton(
              type: VButtonType.outline,
              onPressed: _joinByToken,
              block: true,
              child: const Text('Join Family')),
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
                  const PageHeading(
                      title: 'Welcome to CareCoins',
                      subtitle:
                          'Set up your family to start sharing care responsibly.'),
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
                        'Your request to join "${(app.pendingRequests.first as Map)['name'] ?? 'a family'}" is pending approval.',
                        style: const TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (_invites.isNotEmpty)
                    VCard(
                      title: 'Your Invitations',
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
                                            '${(inv as Map)['family_name'] ?? 'Family'}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800)),
                                        Text(
                                            'Invited by ${inv['inviter_name'] ?? 'a member'}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  VButton(
                                      onPressed: () => _acceptInvite(inv),
                                      child: const Text('Accept')),
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
                        Expanded(child: createCard),
                        const SizedBox(width: 16),
                        Expanded(child: joinCard),
                      ],
                    )
                  else ...[createCard, joinCard],
                  Center(
                    child: TextButton(
                      onPressed: () => app.logout(),
                      child: const Text('Logout',
                          style: TextStyle(color: AppColors.textSecondary)),
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
}
