import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/assignment_document.dart';
import '../services/ai_detection_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_authorship_dialog.dart';
import '../widgets/ui_kit.dart';
import 'document_viewer_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController;
  String? _photoBase64;
  bool _saving = false;
  List<AppUser>? _allUsers;
  bool _loadingUsers = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().currentUser!;
    _nameController = TextEditingController(text: user.displayName);
    _photoBase64 = user.photoBase64;
    if (user.role == UserRole.admin) {
      _loadUsers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _loadingUsers = true);
    try {
      final users = await context.read<AppState>().getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _loadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _choosePhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || !mounted) return;
    setState(() => _photoBase64 = base64Encode(bytes));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<AppState>().updateProfile(
          displayName: _nameController.text.trim(),
          photoBase64: _photoBase64,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Profile updated.')));
  }

  void _showChangePasswordDialog() {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    String? dialogError;
    bool isChanging = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dialogError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      dialogError!,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: currentPassController,
                  obscureText: true,
                  decoration: fieldDecoration('Current Password', icon: Icons.lock_outline),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassController,
                  obscureText: true,
                  decoration: fieldDecoration('New Password (min. 6 chars)', icon: Icons.lock_reset_outlined),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassController,
                  obscureText: true,
                  decoration: fieldDecoration('Confirm New Password', icon: Icons.check_circle_outline),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isChanging ? null : () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isChanging
                  ? null
                  : () async {
                      final curr = currentPassController.text.trim();
                      final next = newPassController.text.trim();
                      final conf = confirmPassController.text.trim();
                      if (curr.isEmpty || next.isEmpty || conf.isEmpty) {
                        setDialogState(() => dialogError = 'Please fill in all fields.');
                        return;
                      }
                      if (next.length < 6) {
                        setDialogState(() => dialogError = 'New password must be at least 6 characters.');
                        return;
                      }
                      if (next != conf) {
                        setDialogState(() => dialogError = 'New passwords do not match.');
                        return;
                      }

                      setDialogState(() {
                        isChanging = true;
                        dialogError = null;
                      });

                      try {
                        await appState.changePassword(
                              currentPassword: curr,
                              newPassword: next,
                            );
                        if (dialogCtx.mounted) {
                          Navigator.of(dialogCtx).pop();
                        }
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Password updated successfully.')),
                        );
                      } catch (e) {
                        setDialogState(() {
                          isChanging = false;
                          dialogError = e.toString().replaceFirst('StateError: ', '').replaceFirst('Exception: ', '');
                        });
                      }
                    },
              child: isChanging
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteUser(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User Account'),
        content: Text(
          'Are you sure you want to delete "${user.email}" and remove all their uploaded documents? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AppState>().deleteUser(user.id);
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User ${user.email} removed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser!;
    final appState = context.watch<AppState>();
    final image = _photoBase64 == null ? null : base64Decode(_photoBase64!);
    final shownName = user.displayName.isEmpty ? user.email : user.displayName;

    return Scaffold(
      appBar: buildAppBar(
        'Profile',
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () {
              appState.logout();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: PageFrame(
        maxWidth: 620,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.ink.withValues(alpha: 0.1),
                    foregroundColor: AppColors.ink,
                    backgroundImage: image == null ? null : MemoryImage(image),
                    child: image == null
                        ? Text(
                            shownName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      tooltip: 'Choose profile photo',
                      onPressed: _choosePhoto,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                shownName,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: StatPill(
                label: user.role == UserRole.admin ? 'Administrator' : 'Student / Researcher',
              ),
            ),
            const SizedBox(height: 20),
            _buildAccountStats(appState, user),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Profile Details',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    decoration: fieldDecoration(
                      'Display name',
                      icon: Icons.badge_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: user.email,
                    readOnly: true,
                    decoration: fieldDecoration(
                      'Email (fixed)',
                      icon: Icons.mail_outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showChangePasswordDialog,
                          icon: const Icon(Icons.lock_reset_outlined, size: 18),
                          label: const Text('Change Password'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check, size: 18),
                          label: Text(_saving ? 'Saving…' : 'Save Name'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (user.role == UserRole.admin) ...[
              const SizedBox(height: 20),
              _buildAdminUserManagement(appState),
              const SizedBox(height: 20),
              _buildAdminAiChecks(appState),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out'),
              onPressed: () {
                appState.logout();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountStats(AppState appState, AppUser user) {
    final userDocs = appState.documents
        .where((d) => d.ownerId == user.id || user.role == UserRole.admin)
        .length;
    final resultsCount = appState.results.length;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Documents', '$userDocs', Icons.description_outlined),
          Container(width: 1, height: 32, color: AppColors.line),
          _buildStatItem('Comparisons', '$resultsCount', Icons.compare_arrows_rounded),
          Container(width: 1, height: 32, color: AppColors.line),
          _buildStatItem('Role', user.role == UserRole.admin ? 'Admin' : 'Student', Icons.badge_outlined),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.muted),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _buildAdminUserManagement(AppState appState) {
    final currentUserId = appState.currentUser?.id;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Management (Admin)',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage registered accounts, roles, and permissions.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh user list',
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadingUsers ? null : _loadUsers,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingUsers)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_allUsers == null || _allUsers!.isEmpty)
            const Text('No users found.', style: TextStyle(color: AppColors.muted))
          else
            for (final targetUser in _allUsers!) ...[
              if (targetUser != _allUsers!.first)
                const Divider(height: 16, color: AppColors.line),
              Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.ink.withValues(alpha: 0.08),
                    child: Text(
                      (targetUser.displayName.isNotEmpty ? targetUser.displayName : targetUser.email)[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                targetUser.displayName.isEmpty ? targetUser.email : targetUser.displayName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (targetUser.id == currentUserId) ...[
                              const SizedBox(width: 6),
                              const Text(
                                '(You)',
                                style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          targetUser.email,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Account actions',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: targetUser.role == UserRole.admin
                            ? AppColors.ink.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            targetUser.role == UserRole.admin ? 'Admin' : 'User',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: targetUser.role == UserRole.admin ? AppColors.ink : AppColors.muted,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_drop_down, size: 16),
                        ],
                      ),
                    ),
                    onSelected: (action) async {
                      if (action == 'toggle_role') {
                        final newRole = targetUser.role == UserRole.admin ? UserRole.user : UserRole.admin;
                        await appState.updateUserRole(targetUser.id, newRole);
                        _loadUsers();
                      } else if (action == 'delete') {
                        _confirmDeleteUser(targetUser);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'toggle_role',
                        enabled: targetUser.id != currentUserId,
                        child: Row(
                          children: [
                            Icon(
                              targetUser.role == UserRole.admin ? Icons.person_outline : Icons.shield_outlined,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(targetUser.role == UserRole.admin ? 'Change to Regular User' : 'Promote to Admin'),
                          ],
                        ),
                      ),
                      if (targetUser.id != currentUserId)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete Account', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildAdminAiChecks(AppState appState) {
    final documents = appState.documents;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'AI Screening & Document Inspector',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Review uploaded files and AI screening probability across all users.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          if (documents.isEmpty)
            const Text(
              'No uploaded documents yet.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            for (final document in documents) ...[
              if (document != documents.first)
                const Divider(height: 20, color: AppColors.line),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(
                  document.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                subtitle: InkWell(
                  onTap: (document.aiProbability != null || document.aiClassification != null)
                      ? () => AiAuthorshipDialog.show(context, document: document)
                      : null,
                  child: Text(
                    'Owner: ${document.ownerName ?? 'Unknown'}\n'
                    '${_aiStatus(document)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (document.aiProbability != null || document.aiClassification != null)
                      IconButton(
                        icon: const Icon(Icons.psychology_outlined, color: AppColors.brand, size: 20),
                        tooltip: 'View AI Authorship Breakdown (Edited vs Generated)',
                        onPressed: () => AiAuthorshipDialog.show(context, document: document),
                      ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.ink),
                      tooltip: 'View Document / PDF',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DocumentViewerScreen(document: document),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            ],
        ],
      ),
    );
  }
}

String _aiStatus(AssignmentDocument document) {
  if (document.aiProbability == null && document.aiClassification == null) {
    return 'AI check not run';
  }

  final classification = AiAuthorshipType.fromId(document.aiClassification);
  final synth = ((document.aiSyntheticScore ?? (document.aiProbability ?? 0.0)) * 100).round();
  final edit = ((document.aiEditingScore ?? 0.0) * 100).round();

  switch (classification) {
    case AiAuthorshipType.aiEdited:
      return '✍️ AI-Polished: $edit% Assistance (Original Human Draft Preserved)';
    case AiAuthorshipType.aiGenerated:
      return '🤖 Synthetic AI: $synth% (Generated from scratch by AI)';
    case AiAuthorshipType.hybridCoCreated:
      return '⚡ Hybrid AI: $synth% Synthetic • $edit% Polish';
    case AiAuthorshipType.humanOriginal:
      return '👤 Human Original (Natural rhythm & voice)';
  }
}
