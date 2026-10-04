import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Minimalist curved authentication screen matching Design 4 & Design 1 aesthetic.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _fillCredentials(String email, String password) {
    final state = context.read<AppState>();
    state.authError = null;
    setState(() {
      _email.text = email;
      _password.text = password;
      _registering = false;
    });
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid email and a password of at least 6 characters.',
          ),
          backgroundColor: AppColors.high,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final state = context.read<AppState>();
    if (_registering) {
      await state.register(_email.text.trim(), _password.text);
    } else {
      await state.login(_email.text.trim(), _password.text);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final authError = context.watch<AppState>().authError;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;

          if (!wide) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  // Curved Dark Header (Design 4)
                  _buildCurvedHeader(compact: true),

                  // Floating Auth Card
                  Transform.translate(
                    offset: const Offset(0, -32),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: AppCard(
                          padding: const EdgeInsets.all(28),
                          borderRadius: 22,
                          child: _buildForm(authError),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }

          // Wide Desktop Layout
          return Row(
            children: [
              const Expanded(flex: 5, child: _BrandHeroPanel()),
              Expanded(
                flex: 6,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: AppCard(
                        padding: const EdgeInsets.all(36),
                        borderRadius: 22,
                        child: _buildForm(authError),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurvedHeader({required bool compact}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 60),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.mint.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: AppColors.mint,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Plagiarism Checker',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Dual-Layer AI Screening & Academic Integrity Suite',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(String? authError) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tab Switcher (Sign In vs Register)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: _AuthTabButton(
                  title: 'Sign In',
                  selected: !_registering,
                  onTap: () {
                    context.read<AppState>().authError = null;
                    setState(() => _registering = false);
                  },
                ),
              ),
              Expanded(
                child: _AuthTabButton(
                  title: 'Create Account',
                  selected: _registering,
                  onTap: () {
                    context.read<AppState>().authError = null;
                    setState(() => _registering = true);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(
          _registering ? 'Create your account' : 'Welcome back',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _registering
              ? 'Register to upload assignments, research reports, and screen authorship.'
              : 'Sign in to access your persistent student records and batch reports.',
          style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 22),

        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: fieldDecoration('Email Address', icon: Icons.mail_outline),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _password,
          obscureText: _hidePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_busy) _submit();
          },
          decoration: fieldDecoration(
            'Password',
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              tooltip: _hidePassword ? 'Show password' : 'Hide password',
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.muted,
                size: 20,
              ),
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
            ),
          ),
        ),

        if (_registering) ...[
          const SizedBox(height: 8),
          const Text(
            'Password must be at least 6 characters.',
            style: TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
        ],

        if (authError != null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(message: authError),
        ],

        const SizedBox(height: 22),

        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppColors.brand,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  _registering ? 'Create Account' : 'Sign In',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
        ),

        const SizedBox(height: 20),

        // Quick Demo Fill Credentials
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt, size: 16, color: AppColors.brand),
                  SizedBox(width: 6),
                  Text(
                    'Quick Demo Logins',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () => _fillCredentials('admin@example.com', 'admin123'),
                      child: const Text('Demo Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () => _fillCredentials('student1@example.com', 'password123'),
                      child: const Text('Demo Student', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthTabButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _AuthTabButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? AppColors.brand : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.high.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.high.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.high),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.high,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Brand panel on wide desktop displays
class _BrandHeroPanel extends StatelessWidget {
  const _BrandHeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.mint.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: AppColors.mint,
                  size: 32,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Academic Integrity &\nAuthorship Suite',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Accurate pairwise document similarity combined with dual-layer AI screening to distinguish AI-generated essays from AI-polished drafts.',
                style: TextStyle(
                  fontSize: 14.5,
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              _buildFeatureRow(
                icon: Icons.psychology_outlined,
                title: 'Dual-Layer AI Classification',
                description: 'Protects students who use grammar assistance from unfair zero-tolerance AI flags.',
              ),
              const SizedBox(height: 20),
              _buildFeatureRow(
                icon: Icons.hub_outlined,
                title: 'Offline Batch Cross-Evaluation',
                description: 'Scalable N*(N-1)/2 matrix analysis with student leaderboard and heatmap.',
              ),
              const SizedBox(height: 20),
              _buildFeatureRow(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Side-by-Side Synced PDF View',
                description: 'Granular passage-level inspection with synchronized dual scrolling.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.mint, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
