import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/comparison_result.dart';
import '../services/report_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'detail_screen.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _exporting = false;
  String _selectedFilter = 'all'; // 'all', 'high', 'review', 'low'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = months[dt.month - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m ${dt.day}, ${dt.year} • $hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final results = appState.results;

    final high = results.where((r) => r.isHighRisk).length;
    final review = results.where((r) => r.isFlagged && !r.isHighRisk).length;
    final low = results.length - high - review;

    final filteredResults = results.where((r) {
      if (_selectedFilter == 'high' && !r.isHighRisk) return false;
      if (_selectedFilter == 'review' && (!r.isFlagged || r.isHighRisk)) {
        return false;
      }
      if (_selectedFilter == 'low' && r.isFlagged) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = r.docAName.toLowerCase().contains(q) ||
            r.docBName.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    final timeStr = appState.lastAnalyzedAt != null
        ? _formatDate(appState.lastAnalyzedAt!)
        : null;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: buildAppBar(
        'Plagiarism & Similarity Report',
        actions: [
          if (results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: _exporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('Export PDF Report', style: TextStyle(fontSize: 12)),
                onPressed: _exporting
                    ? null
                    : () async {
                        setState(() => _exporting = true);
                        try {
                          await ReportService.generateAndShareReport(
                            results,
                            appState.lastAnalyzedAt ?? DateTime.now(),
                          );
                        } finally {
                          if (mounted) setState(() => _exporting = false);
                        }
                      },
              ),
            ),
        ],
      ),
      body: results.isEmpty
          ? const EmptyState(
              icon: Icons.compare_arrows_rounded,
              title: 'No Analysis Results Found',
              message:
                  'Select at least two documents on the documents screen and tap "Run Plagiarism Comparison".',
            )
          : PageFrame(
              maxWidth: 960,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
                children: [
                  PageHeader(
                    title: 'Pairwise Document Analysis',
                    subtitle: timeStr != null
                        ? 'Analyzed on $timeStr. Documents ranked from highest to lowest similarity.'
                        : 'Ranked by highest similarity score. Tap any comparison to view matching phrases side-by-side.',
                  ),

                  // Analytics Summary Metric Cards
                  Row(
                    children: [
                      _StatCard(
                        title: '${results.length}',
                        label: 'Total Pairs',
                        color: AppColors.ink,
                        icon: Icons.hub_outlined,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        title: '$high',
                        label: 'High Risk',
                        color: AppColors.high,
                        icon: Icons.warning_amber_rounded,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        title: '$review',
                        label: 'Needs Review',
                        color: AppColors.review,
                        icon: Icons.flag_outlined,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        title: '$low',
                        label: 'Low / Safe',
                        color: AppColors.low,
                        icon: Icons.check_circle_outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Search & Filter Bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search compared documents...',
                            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.muted),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.line),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.line),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Wrap(
                        spacing: 6,
                        children: [
                          _FilterChip(
                            label: 'All (${results.length})',
                            selected: _selectedFilter == 'all',
                            onTap: () => setState(() => _selectedFilter = 'all'),
                          ),
                          _FilterChip(
                            label: 'High ($high)',
                            color: AppColors.high,
                            selected: _selectedFilter == 'high',
                            onTap: () => setState(() => _selectedFilter = 'high'),
                          ),
                          _FilterChip(
                            label: 'Review ($review)',
                            color: AppColors.review,
                            selected: _selectedFilter == 'review',
                            onTap: () => setState(() => _selectedFilter = 'review'),
                          ),
                          _FilterChip(
                            label: 'Low ($low)',
                            color: AppColors.low,
                            selected: _selectedFilter == 'low',
                            onTap: () => setState(() => _selectedFilter = 'low'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  if (filteredResults.isEmpty)
                    const AppCard(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No document pairs match your search query or filter selection.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ),

                  for (final r in filteredResults)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ResultCard(
                        result: r,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DetailScreen(result: r),
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

class _StatCard extends StatelessWidget {
  final String title;
  final String label;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderColor: color.withValues(alpha: 0.25),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? AppColors.brand;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? baseColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? baseColor : AppColors.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? baseColor : AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ComparisonResult result;
  final VoidCallback onTap;

  const _ResultCard({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final risk = Risk.of(result);
    final matchCount = result.matchedRangesA.length;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      borderColor: result.isFlagged
          ? risk.color.withValues(alpha: 0.35)
          : AppColors.line,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ScoreRing(score: result.overallScore, color: risk.color, size: 66),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: risk.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        risk.label,
                        style: TextStyle(
                          color: risk.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (matchCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.match.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.matchBorder),
                        ),
                        child: Text(
                          '$matchCount matching passages',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 16, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        result.docAName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Text('vs  ', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                    Expanded(
                      child: Text(
                        result.docBName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MetricRow(result: result),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.brand),
          ),
        ],
      ),
    );
  }
}
