import 'package:flutter/material.dart';

import '../models/comparison_result.dart';
import '../theme/app_theme.dart';

/// App bar shared by every screen: clean surface, bold title, and crisp hairline divider.
AppBar buildAppBar(String title, {List<Widget>? actions, Widget? leading}) {
  return AppBar(
    backgroundColor: Colors.white,
    scrolledUnderElevation: 0,
    elevation: 0,
    leading: leading,
    centerTitle: false,
    title: Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        letterSpacing: -0.3,
        color: AppColors.text,
      ),
    ),
    actions: actions,
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, thickness: 1, color: AppColors.line),
    ),
  );
}

/// Keeps content in a readable column on wide desktop screens.
class PageFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const PageFrame({super.key, required this.child, this.maxWidth = 920});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Modern surface card with rounded corners, clean 1px border, and soft elevation.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;
  final double borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.borderColor,
    this.color,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Similarity score drawn as an animated circular gauge.
class ScoreRing extends StatelessWidget {
  final double score;
  final Color color;
  final double size;

  const ScoreRing({
    super.key,
    required this.score,
    required this.color,
    this.size = 58,
  });

  @override
  Widget build(BuildContext context) {
    final value = score.clamp(0.0, 1.0).toDouble();
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 750);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (context, animated, _) => CircularProgressIndicator(
                value: animated,
                strokeWidth: size * 0.11,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              fontSize: size * 0.26,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Clean empty state with icon circle and informative guidance.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.brand.withValues(alpha: 0.15)),
              ),
              child: Icon(icon, size: 34, color: AppColors.brand),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.45, fontSize: 13.5),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Small rounded pill tag with colored dot and border.
class StatPill extends StatelessWidget {
  final String label;
  final Color? color;

  const StatPill({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

/// Clean page title and subtitle block.
class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.text,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Square icon tile used for files and actions.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final Color? backgroundColor;

  const IconBadge({
    super.key,
    required this.icon,
    this.size = 42,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.brand;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.15)),
      ),
      child: Icon(icon, size: size * 0.52, color: c),
    );
  }
}

/// Sub-scores breakdown row.
class MetricRow extends StatelessWidget {
  final ComparisonResult result;

  const MetricRow({super.key, required this.result});

  String _pct(double v) => '${(v * 100).toStringAsFixed(0)}%';

  @override
  Widget build(BuildContext context) {
    final semantic = result.semanticSimilarity;
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        _Metric(label: 'Phrase Match', value: _pct(result.shingleSimilarity)),
        _Metric(label: 'Word Overlap', value: _pct(result.cosineSimilarity)),
        if (semantic != null)
          _Metric(label: 'AI Semantic', value: _pct(semantic)),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11.5, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.text),
        ),
      ],
    );
  }
}
