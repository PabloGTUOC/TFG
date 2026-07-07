import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_upload.dart';
import 'ui.dart';

/// Where invite links land — the web app serves the /join route.
/// Override per environment: --dart-define=WEB_APP_ORIGIN=https://carecoins.example
const String kWebAppOrigin = String.fromEnvironment('WEB_APP_ORIGIN',
    defaultValue: 'http://localhost:5173');

/// Port of components/profile/FamilyCircle.vue: the family roster
/// (members + dependents), add/remove dependents, e-mail invitations and
/// share-able invite links with QR code.
class FamilyCircle extends StatefulWidget {
  const FamilyCircle({super.key});

  @override
  State<FamilyCircle> createState() => _FamilyCircleState();
}

class _FamilyCircleState extends State<FamilyCircle> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _invitations = [];
  String _inviteLink = '';
  bool _generatingLink = false;
  bool _linkCopied = false;

  static const _badges = {
    'child': ('Junior Explorer', Color(0xFF6366F1)),
    'pet': ('Furry Friend', Color(0xFF10B981)),
    'elderly': ('Guiding Star', Color(0xFFF59E0B)),
    'caregiver': ('Caregiver', Color(0xFF059669)),
    'member': ('Family Member', Color(0xFF3B82F6)),
    'person': ('Family Member', Color(0xFF3B82F6)),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    if (app.familyId == 0) return;
    try {
      final mem = await app.api.get('/api/families/${app.familyId}/members');
      if (mounted) {
        setState(() => _members = ((mem['members'] as List?) ?? [])
            .cast<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList());
      }
    } catch (_) {}
    if (app.isCaregiver) {
      try {
        final inv =
            await app.api.get('/api/families/${app.familyId}/invitations');
        if (mounted) {
          setState(() => _invitations = ((inv['invitations'] as List?) ?? [])
              .cast<Map>()
              .map((m) => m.cast<String, dynamic>())
              .toList());
        }
      } catch (_) {}
    }
  }

  /// Members first, then care actors — same as combinedCircleItems in Vue.
  List<Map<String, dynamic>> get _circle {
    final app = context.read<AppState>();
    return [
      for (final m in _members)
        {
          'key': 'user_${m['id']}',
          'name': m['name'] ?? 'Member',
          'type': (m['role'] ?? 'member').toString(),
          'avatarUrl': m['avatar_url'],
          'isActor': false,
        },
      for (final a in app.actors.cast<Map>())
        {
          'key': 'actor_${a['id']}',
          'id': a['id'],
          'name': a['name'] ?? 'Dependent',
          'type': (a['actor_type'] ?? 'person').toString(),
          'avatarUrl': a['avatar_url'],
          'isActor': true,
        },
    ];
  }

  Future<void> _uploadActorAvatar(dynamic actorId) async {
    final app = context.read<AppState>();
    final ok = await pickAndUploadAvatar(
        context, '/api/families/${app.familyId}/actors/$actorId/avatar',
        successMessage: 'Avatar updated!');
    if (ok && mounted) {
      await app.fetchUserData();
      await _load();
    }
  }

  Future<void> _addActor() async {
    final name = TextEditingController();
    var actorType = 'child';
    var careTime = 'full_time';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg)),
          title: const Text('Add Dependent',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VInput(
                  controller: name,
                  label: 'Name',
                  placeholder: 'e.g. Luna, Grandpa…'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: actorType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                      value: 'child', child: Text('👶 Child / Baby')),
                  DropdownMenuItem(value: 'pet', child: Text('🐾 Pet')),
                  DropdownMenuItem(value: 'elderly', child: Text('👴 Elderly')),
                ],
                onChanged: (v) => setLocal(() => actorType = v ?? 'child'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: careTime,
                decoration: const InputDecoration(labelText: 'Care time'),
                items: const [
                  DropdownMenuItem(
                      value: 'full_time', child: Text('Full Time')),
                  DropdownMenuItem(
                      value: 'part_time', child: Text('Part Time')),
                ],
                onChanged: (v) => setLocal(() => careTime = v ?? 'full_time'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final app = context.read<AppState>();
    if (name.text.trim().isEmpty) {
      app.setError('Name is required.');
      return;
    }
    await app.runAction(() async {
      await app.api.post('/api/families/${app.familyId}/actors', {
        'name': name.text.trim(),
        'actorType': actorType,
        'careTime': careTime,
      });
      await app.fetchUserData();
      await _load();
    }, 'Dependent added to the circle!');
  }

  Future<void> _removeActor(dynamic actorId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg)),
        title: const Text('Remove dependent?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Remove "$name" from the family circle?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    final app = context.read<AppState>();
    await app.runAction(() async {
      await app.api.delete('/api/families/${app.familyId}/actors/$actorId');
      await app.fetchUserData();
      await _load();
    }, 'Dependent removed.');
  }

  Future<void> _inviteByEmail() async {
    final email = TextEditingController();
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg)),
        title: const Text('Invite a Caregiver',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VInput(
                controller: email,
                label: 'Email Address *',
                placeholder: 'caregiver@email.com',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            VInput(
                controller: name,
                label: 'Their Name (optional)',
                placeholder: 'e.g. Maria'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send invite')),
        ],
      ),
    );
    if (ok != true) return;
    final app = context.read<AppState>();
    final mail = email.text.trim();
    if (mail.isEmpty) {
      app.setError('Email is required.');
      return;
    }
    await app.runAction(() async {
      await app.api.post('/api/families/${app.familyId}/invitations', {
        'email': mail,
        if (name.text.trim().isNotEmpty) 'name': name.text.trim(),
      });
      await _load();
    }, 'Invitation sent!');
  }

  Future<void> _generateInviteLink() async {
    final app = context.read<AppState>();
    setState(() => _generatingLink = true);
    try {
      final data =
          await app.api.post('/api/families/${app.familyId}/invite-links', {});
      final id = (data['link'] as Map?)?['id'];
      setState(() => _inviteLink = '$kWebAppOrigin/join?token=$id');
    } catch (e) {
      app.setError('Failed to generate invite link.');
    } finally {
      if (mounted) setState(() => _generatingLink = false);
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _inviteLink));
    setState(() => _linkCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _linkCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return VCard(
      title: 'Family Circle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in _circle)
                _CircleCard(
                  name: item['name'].toString(),
                  imageUrl: item['avatarUrl']?.toString(),
                  badge: _badges[item['type']] ??
                      (
                        item['type'].toString().replaceAll('_', ' '),
                        const Color(0xFF94A3B8)
                      ),
                  onRemove: item['isActor'] == true && app.isCaregiver
                      ? () => _removeActor(item['id'], item['name'].toString())
                      : null,
                  onAvatarTap: item['isActor'] == true && app.isCaregiver
                      ? () => _uploadActorAvatar(item['id'])
                      : null,
                ),
            ],
          ),
          if (app.isCaregiver) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                VButton(
                    type: VButtonType.outline,
                    onPressed: _addActor,
                    child: const Text('＋ Add Dependent',
                        style: TextStyle(fontSize: 14))),
                const SizedBox(width: 10),
                VButton(
                    type: VButtonType.secondary,
                    onPressed: _inviteByEmail,
                    child: const Text('✉️ Invite Caregiver',
                        style: TextStyle(fontSize: 14))),
              ],
            ),
            if (_invitations.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('PENDING INVITATIONS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              for (final inv in _invitations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline_rounded,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${inv['email'] ?? inv['name'] ?? 'Invitee'}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                      const PillBadge(
                          text: 'pending',
                          color: AppColors.warning,
                          background: AppColors.warningSoft,
                          fontSize: 10),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 24),
            const Divider(color: AppColors.border),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text('Invite Link',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                VButton(
                  type: VButtonType.outline,
                  disabled: _generatingLink,
                  onPressed: _generateInviteLink,
                  child: Text(
                      _generatingLink
                          ? 'Generating…'
                          : _inviteLink.isEmpty
                              ? '🔗 Generate Link'
                              : '↻ New Link',
                      style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
            if (_inviteLink.isNotEmpty) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: QrImageView(
                    data: _inviteLink,
                    size: 180,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(_inviteLink,
                    style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 10),
              VButton(
                type: VButtonType.secondary,
                block: true,
                onPressed: _copyLink,
                child: Text(_linkCopied ? '✓ Copied!' : 'Copy link',
                    style: const TextStyle(fontSize: 14)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CircleCard extends StatelessWidget {
  final String name;
  final (String, Color) badge;
  final String? imageUrl;
  final VoidCallback? onRemove;
  final VoidCallback? onAvatarTap;

  const _CircleCard(
      {required this.name,
      required this.badge,
      this.imageUrl,
      this.onRemove,
      this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: onAvatarTap,
                child: AvatarCircle(
                    name: name,
                    size: 48,
                    imageUrl: imageUrl,
                    background: badge.$2.withValues(alpha: 0.15),
                    foreground: badge.$2),
              ),
              if (onAvatarTap != null)
                Positioned(
                  bottom: -4,
                  left: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: badge.$2, shape: BoxShape.circle),
                    child: const Text('📷', style: TextStyle(fontSize: 9)),
                  ),
                ),
              if (onRemove != null)
                Positioned(
                  // Padding enlarges the tap area (22px visual → ~38px hit)
                  // while keeping the ✕ in the same visual spot.
                  top: -14,
                  right: -14,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onRemove,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            color: AppColors.dangerSoft,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded,
                            size: 14, color: AppColors.danger),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 5),
          PillBadge(
              text: badge.$1,
              color: badge.$2,
              background: badge.$2.withValues(alpha: 0.12),
              fontSize: 9),
        ],
      ),
    );
  }
}
