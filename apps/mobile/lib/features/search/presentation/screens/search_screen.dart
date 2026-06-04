import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../feed/domain/entities/news_item.dart';
import '../providers/search_provider.dart'
    show TrendingCountry, searchNotifierProvider;

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
    // Reset stale state after the first frame so we don't modify a provider
    // while the widget tree is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(searchNotifierProvider.notifier).clearQuery();
      ref.read(searchNotifierProvider.notifier).loadRecents();
    });
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

  Future<void> _onSubmitted(String value) async {
    final term = value.trim();
    if (term.isEmpty) return;
    _debounce?.cancel();
    ref.read(searchNotifierProvider.notifier).setQuery(term);
    await ref.read(searchNotifierProvider.notifier).saveSearch(term);
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
    context.push('/report/${item.id}', extra: item);
  }

  void _onBack() {
    if (_controller.text.isNotEmpty) {
      _controller.clear();
      ref.read(searchNotifierProvider.notifier).clearQuery();
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);

    return Scaffold(
      backgroundColor: _P.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // White sheet: extends behind status bar so top area matches header
          ColoredBox(
            color: _P.card,
            child: SafeArea(
              bottom: false,
              child: _SearchHeader(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onQueryChanged,
                onSubmitted: _onSubmitted,
                onBack: _onBack,
                onClear: () {
                  _controller.clear();
                  ref.read(searchNotifierProvider.notifier).clearQuery();
                },
                onSearch: () => _onSubmitted(_controller.text),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: state.query.isNotEmpty
                        ? _ScopeChips(
                            key: const ValueKey('chips'),
                            scope: state.scope,
                            onChanged: (s) => ref
                                .read(searchNotifierProvider.notifier)
                                .setScope(s),
                          )
                        : const SizedBox.shrink(key: ValueKey('no-chips')),
                  ),
                  const Divider(height: 1, thickness: 0.5, color: _P.hairline),
                  Expanded(
                    child: state.query.isEmpty
                        ? _EmptyView(
                            recents: state.recentSearches,
                            trendingCountries: state.trendingCountries,
                            includeDisputed: state.includeDisputed,
                            onSelectTerm: _selectTerm,
                            onRemoveTerm: (term) => ref
                                .read(searchNotifierProvider.notifier)
                                .removeSearch(term),
                            onClearAll: () => ref
                                .read(searchNotifierProvider.notifier)
                                .clearAllSearches(),
                            onToggleDisputed: () => ref
                                .read(searchNotifierProvider.notifier)
                                .toggleIncludeDisputed(),
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
          ),
        ],
      ),
    );
  }
}

// ── Search header ─────────────────────────────────────────────────────────────

class _SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final VoidCallback onSearch;

  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onBack,
    required this.onClear,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back,
              color: _P.inkSecondary,
              size: 22,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
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
                      onSubmitted: onSubmitted,
                      textInputAction: TextInputAction.search,
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
            onPressed: onSearch,
            style: TextButton.styleFrom(
              backgroundColor: _P.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Search',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
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
  final List<TrendingCountry> trendingCountries;
  final bool includeDisputed;
  final ValueChanged<String> onSelectTerm;
  final ValueChanged<String> onRemoveTerm;
  final VoidCallback onClearAll;
  final VoidCallback onToggleDisputed;

  const _EmptyView({
    required this.recents,
    required this.trendingCountries,
    required this.includeDisputed,
    required this.onSelectTerm,
    required this.onRemoveTerm,
    required this.onClearAll,
    required this.onToggleDisputed,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      children: [
        Row(
          children: [
            const _SectionLabel('RECENT'),
            const Spacer(),
            if (recents.isNotEmpty)
              GestureDetector(
                onTap: onClearAll,
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                    fontSize: 12,
                    color: _P.navy,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
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
                .take(5)
                .map(
                  (t) => _RecentPill(
                    term: t,
                    onTap: onSelectTerm,
                    onRemove: onRemoveTerm,
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            const _SectionLabel("WHAT'S GOING ON"),
            const Spacer(),
            const Text(
              'Include disputed',
              style: TextStyle(fontSize: 12, color: _P.inkTertiary),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onToggleDisputed,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 36,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: includeDisputed ? _P.navy : _P.hairline,
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 180),
                  alignment: includeDisputed
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (trendingCountries.isEmpty)
          const Text(
            'No data yet',
            style: TextStyle(fontSize: 13, color: _P.inkTertiary),
          )
        else
          ...trendingCountries.asMap().entries.map(
            (e) => _TrendingRow(
              rank: e.key + 1,
              country: e.value,
              onTap: onSelectTerm,
            ),
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
  final ValueChanged<String> onRemove;

  const _RecentPill({
    required this.term,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(term),
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 6, top: 9, bottom: 9),
        decoration: BoxDecoration(
          color: _P.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _P.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 14, color: _P.inkTertiary),
            const SizedBox(width: 6),
            Text(
              term,
              style: const TextStyle(fontSize: 13, color: _P.inkSecondary),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => onRemove(term),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 18, color: _P.inkTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingRow extends StatelessWidget {
  final int rank;
  final TrendingCountry country;
  final ValueChanged<String> onTap;

  const _TrendingRow({
    required this.rank,
    required this.country,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(country.name),
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
                country.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _P.ink,
                ),
              ),
            ),
            Text(
              '${country.count} report${country.count == 1 ? '' : 's'}',
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
