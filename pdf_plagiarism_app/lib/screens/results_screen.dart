import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/comparison_result.dart';
import '../services/report_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'detail_screen.dart';
import 'main_navigation_shell.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<AppState>();
      if (state.results.isEmpty) {
        state.reloadSavedResults();
      }
    });
  }

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
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.compare_arrows_rounded, size: 48, color: AppColors.brand),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Similarity Comparisons Yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select two or more documents from your submissions or run a batch evaluation to compare documents for similarity.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: const Icon(Icons.dashboard_outlined, size: 18),
                          label: const Text('Go to Documents'),
                          onPressed: () => MainNavigationShell.switchTab(context, 0),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          icon: const Icon(Icons.hub_outlined, size: 18),
                          label: const Text('Batch Lab'),
                          onPressed: () => MainNavigationShell.switchTab(context, 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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

                  // Pairwise summary explanation banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.info_outline_rounded, color: AppColors.brand, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Showing ${results.length} Document Pair Combinations',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.text),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                high > 0
                                    ? '$high high-risk match detected. Tap any comparison card to inspect matching phrases.'
                                    : 'All document pairs compared. Tap any card to inspect side-by-side matches.',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Analytics Summary Metric Cards (Responsive LayoutBuilder)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 520;
                      final cardTotal = _StatCard(
                        title: '${results.length}',
                        label: 'Total Pairs',
                        color: AppColors.ink,
                        icon: Icons.hub_outlined,
                      );
                      final cardHigh = _StatCard(
                        title: '$high',
                        label: 'High Risk',
                        color: AppColors.high,
                        icon: Icons.warning_amber_rounded,
                      );
                      final cardReview = _StatCard(
                        title: '$review',
                        label: 'Needs Review',
                        color: AppColors.review,
                        icon: Icons.flag_outlined,
                      );
                      final cardLow = _StatCard(
                        title: '$low',
                        label: 'Low / Safe',
                        color: AppColors.low,
                        icon: Icons.check_circle_outline,
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: cardTotal),
                                const SizedBox(width: 10),
                                Expanded(child: cardHigh),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: cardReview),
                                const SizedBox(width: 10),
                                Expanded(child: cardLow),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: cardTotal),
                          const SizedBox(width: 10),
                          Expanded(child: cardHigh),
                          const SizedBox(width: 10),
                          Expanded(child: cardReview),
                          const SizedBox(width: 10),
                          Expanded(child: cardLow),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Search & Filter Bar (Responsive)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 560;
                      final searchField = TextField(
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
                      );

                      final filterChips = SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'All (${results.length})',
                              selected: _selectedFilter == 'all',
                              onTap: () => setState(() => _selectedFilter = 'all'),
                            ),
                            const SizedBox(width: 6),
                            _FilterChip(
                              label: 'High ($high)',
                              color: AppColors.high,
                              selected: _selectedFilter == 'high',
                              onTap: () => setState(() => _selectedFilter = 'high'),
                            ),
                            const SizedBox(width: 6),
                            _FilterChip(
                              label: 'Review ($review)',
                              color: AppColors.review,
                              selected: _selectedFilter == 'review',
                              onTap: () => setState(() => _selectedFilter = 'review'),
                            ),
                            const SizedBox(width: 6),
                            _FilterChip(
                              label: 'Low ($low)',
                              color: AppColors.low,
                              selected: _selectedFilter == 'low',
                              onTap: () => setState(() => _selectedFilter = 'low'),
                            ),
                          ],
                        ),
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            searchField,
                            const SizedBox(height: 10),
                            filterChips,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: searchField),
                          const SizedBox(width: 12),
                          filterChips,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  if (filteredResults.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.filter_list_off_rounded, size: 40, color: AppColors.muted),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No document pairs match "$_searchQuery".'
                                  : 'No document pairs match filter "${_selectedFilter.toUpperCase()}".',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${results.length} total comparisons are available.',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Show All Comparisons'),
                              onPressed: () {
                                setState(() {
                                  _selectedFilter = 'all';
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  for (int i = 0; i < filteredResults.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ResultCard(
                        result: filteredResults[i],
                        pairIndex: i + 1,
                        totalPairs: filteredResults.length,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DetailScreen(result: filteredResults[i]),
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
    return AppCard(
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
  final int? pairIndex;
  final int? totalPairs;

  const _ResultCard({
    required this.result,
    required this.onTap,
    this.pairIndex,
    this.totalPairs,
  });

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
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (pairIndex != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Text(
                          totalPairs != null ? 'Pair #$pairIndex of $totalPairs' : 'Pair #$pairIndex',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
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
