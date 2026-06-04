import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../feed/domain/entities/news_item.dart';
import '../providers/search_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

class _P {
  static const surface = AppColors.reportSurface;
  static const card = AppColors.reportSurfaceCard;
  static const raised = AppColors.reportSurfaceRaised;
  static const navy = AppColors.reportNavy;
  static const ink = AppColors.reportInk;
  static const inkSecondary = AppColors.reportInkSecondary;
  static const inkTertiary = AppColors.reportInkTertiary;
  static const hairline = AppColors.reportHairline;
  static const citizen = Color(0xFFB54708);
  static const wire = Color(0xFF1D4ED8);
}

// ── Static trending data (prototype) ─────────────────────────────────────────

const _kTrending = [
  _TrendingItem('Kharkiv power grid', 142),
  _TrendingItem('Zaporizhzhia residential', 98),
  _TrendingItem('Black Sea grain', 67),
  _TrendingItem('EU military aid', 54),
];

class _TrendingItem {
  final String term;
  final int count;
  const _TrendingItem(this.term, this.count);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  Timer? _autoFocus;

  @override
  void initState() {
    super.initState();
    _autoFocus = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _autoFocus?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchNotifierProvider.notifier).setQuery(value);
    });
  }

  void _selectTerm(String term) {
    _controller.text = term;
    ref.read(searchNotifierProvider.notifier).setQuery(term);
    _focusNode.requestFocus();
  }

  Future<void> _onResultTap(NewsItem item) async {
    await ref
        .read(searchNotifierProvider.notifier)
        .saveSearch(_controller.text.trim());
    if (!mounted) return;
    Navigator.pop(context);
    if (item.source == NewsSource.wire && item.url != null) {
      final uri = Uri.tryParse(item.url!);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      context.push('/report/${item.id}', extra: item);
    }
  }

  void _cancel() {
    _controller.clear();
    ref.read(searchNotifierProvider.notifier).clearQuery();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);

    return Scaffold(
      backgroundColor: _P.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchHeader(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onQueryChanged,
              onClear: () {
                _controller.clear();
                ref.read(searchNotifierProvider.notifier).clearQuery();
              },
              onCancel: _cancel,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: state.query.isNotEmpty
                  ? _ScopeChips(
                      key: const ValueKey('chips'),
                      scope: state.scope,
                      onChanged: (s) =>
                          ref.read(searchNotifierProvider.notifier).setScope(s),
                    )
                  : const SizedBox.shrink(key: ValueKey('no-chips')),
            ),
            const Divider(height: 1, thickness: 0.5, color: _P.hairline),
            Expanded(
              child: state.query.isEmpty
                  ? _EmptyView(
                      recents: state.recentSearches,
                      onSelectTerm: _selectTerm,
                    )
                  : state.results.isEmpty
                  ? _NoResultsView(query: state.query)
                  : _ResultsList(
                      query: state.query,
                      results: state.results,
                      onTap: _onResultTap,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search header ─────────────────────────────────────────────────────────────

class _SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onCancel;

  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _P.card,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: _P.raised,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search, size: 18, color: _P.inkTertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      style: const TextStyle(fontSize: 15, color: _P.ink),
                      decoration: const InputDecoration(
                        hintText: 'Search reports, places, sources…',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: _P.inkTertiary,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, child) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : GestureDetector(
                            onTap: onClear,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(
                                Icons.cancel,
                                size: 18,
                                color: _P.inkTertiary,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onCancel,
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _P.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scope chips ───────────────────────────────────────────────────────────────

class _ScopeChips extends StatelessWidget {
  final String scope;
  final ValueChanged<String> onChanged;

  const _ScopeChips({super.key, required this.scope, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _P.card,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          _Chip(
            label: 'All',
            value: 'all',
            active: scope == 'all',
            onTap: onChanged,
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'On the ground',
            value: 'citizen',
            active: scope == 'citizen',
            onTap: onChanged,
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Major sources',
            value: 'sources',
            active: scope == 'sources',
            onTap: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final bool active;
  final ValueChanged<String> onTap;

  const _Chip({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _P.ink : _P.raised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _P.ink : _P.hairline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : _P.inkSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Empty view ────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final List<String> recents;
  final ValueChanged<String> onSelectTerm;

  const _EmptyView({required this.recents, required this.onSelectTerm});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      children: [
        const _SectionLabel('RECENT'),
        const SizedBox(height: 10),
        if (recents.isEmpty)
          const Text(
            'No recent searches',
            style: TextStyle(fontSize: 13, color: _P.inkTertiary),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recents
                .take(4)
                .map((t) => _RecentPill(term: t, onTap: onSelectTerm))
                .toList(),
          ),
        const SizedBox(height: 24),
        const _SectionLabel('TRENDING NOW'),
        const SizedBox(height: 12),
        ..._kTrending.asMap().entries.map(
          (e) =>
              _TrendingRow(rank: e.key + 1, item: e.value, onTap: onSelectTerm),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _P.inkTertiary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _RecentPill extends StatelessWidget {
  final String term;
  final ValueChanged<String> onTap;

  const _RecentPill({required this.term, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(term),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _P.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _P.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 14, color: _P.inkTertiary),
            const SizedBox(width: 5),
            Text(
              term,
              style: const TextStyle(fontSize: 13, color: _P.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingRow extends StatelessWidget {
  final int rank;
  final _TrendingItem item;
  final ValueChanged<String> onTap;

  const _TrendingRow({
    required this.rank,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(item.term),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _P.inkTertiary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.term,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _P.ink,
                ),
              ),
            ),
            Text(
              '${item.count} reports',
              style: const TextStyle(fontSize: 13, color: _P.inkTertiary),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.trending_up, size: 16, color: Color(0xFF16A34A)),
          ],
        ),
      ),
    );
  }
}

// ── Results list ──────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  final String query;
  final List<NewsItem> results;
  final ValueChanged<NewsItem> onTap;

  const _ResultsList({
    required this.query,
    required this.results,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = results.length;
    final label = '$n ${n == 1 ? 'result' : 'results'} for "$query"';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: _P.inkTertiary),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: results.length,
            itemBuilder: (context, i) =>
                _ResultCard(item: results[i], onTap: onTap),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final NewsItem item;
  final ValueChanged<NewsItem> onTap;

  const _ResultCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCitizen = item.source == NewsSource.citizen;
    final sourceLabel = isCitizen
        ? 'CITIZEN'
        : (item.sourceName ?? 'WIRE').toUpperCase();
    final sourceColor = isCitizen ? _P.citizen : _P.wire;
    final location = item.locations.isNotEmpty ? item.locations.first : null;

    return GestureDetector(
      onTap: () => onTap(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _P.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _P.hairline, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(imageUrl: item.imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sourceColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          sourceLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: sourceColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                        if (location != null) ...[
                          const Text(
                            ' · ',
                            style: TextStyle(
                              fontSize: 10,
                              color: _P.inkTertiary,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              location,
                              style: const TextStyle(
                                fontSize: 10,
                                color: _P.inkTertiary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _P.ink,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? imageUrl;
  const _Thumbnail({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 64,
        height: 64,
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _PlaceholderThumbnail(),
              )
            : const _PlaceholderThumbnail(),
      ),
    );
  }
}

class _PlaceholderThumbnail extends StatelessWidget {
  const _PlaceholderThumbnail();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _P.raised,
      child: const Icon(Icons.article_outlined, color: _P.hairline, size: 28),
    );
  }
}

// ── No results view ───────────────────────────────────────────────────────────

class _NoResultsView extends StatelessWidget {
  final String query;
  const _NoResultsView({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 56, color: _P.inkTertiary.withAlpha(100)),
            const SizedBox(height: 16),
            Text(
              'No matches for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _P.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try a place name, source, or keyword',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _P.inkTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
