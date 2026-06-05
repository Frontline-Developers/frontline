import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/bookmark_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/widgets/scroll_nav_buttons.dart';
import '../../../feed/domain/entities/news_item.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

class _P {
  static const surface = Color(0xFFF8F9FA);
  static const card = Colors.white;
  static const navy = AppColors.reportNavy;
  static const ink = Color(0xFF212529);
  static const inkSub = Color(0xFF495057);
  static const inkMuted = Color(0xFF868E96);
  static const hairline = Color(0xFFE9ECEF);
  static const citizen = Color(0xFFB54708);
}

const _kMaxWidth = 700.0;

// ── Filter ────────────────────────────────────────────────────────────────────

enum _Filter { all, citizen, wire }

// ── Screen ────────────────────────────────────────────────────────────────────

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  final _ctrl = ScrollController();
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<NewsItem> _applyFilter(List<NewsItem> items) => switch (_filter) {
    _Filter.citizen =>
      items.where((i) => i.source == NewsSource.citizen).toList(),
    _Filter.wire => items.where((i) => i.source == NewsSource.wire).toList(),
    _Filter.all => items,
  };

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(bookmarkNotifierProvider);
    final filtered = _applyFilter(all);

    final citizenCount = all
        .where((i) => i.source == NewsSource.citizen)
        .length;
    final wireCount = all.where((i) => i.source == NewsSource.wire).length;

    return Scaffold(
      backgroundColor: _P.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      size: 18,
                      color: _P.ink,
                    ),
                    onPressed: () => context.pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                  const Icon(Icons.bookmark, size: 20, color: _P.navy),
                  const SizedBox(width: 8),
                  Text(
                    'Saved',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _P.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (all.isNotEmpty)
                    Text(
                      '${all.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: _P.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Filter tabs ──────────────────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _Tab(
                    label: 'All',
                    count: all.length,
                    selected: _filter == _Filter.all,
                    onTap: () => setState(() => _filter = _Filter.all),
                  ),
                  const SizedBox(width: 8),
                  _Tab(
                    label: 'On the ground',
                    count: citizenCount,
                    selected: _filter == _Filter.citizen,
                    onTap: () => setState(() => _filter = _Filter.citizen),
                  ),
                  const SizedBox(width: 8),
                  _Tab(
                    label: 'Major sources',
                    count: wireCount,
                    selected: _filter == _Filter.wire,
                    onTap: () => setState(() => _filter = _Filter.wire),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── List ─────────────────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(filter: _filter)
                  : ScrollNavButtons.wrap(
                      controller: _ctrl,
                      child: ListView.builder(
                        controller: _ctrl,
                        padding: const EdgeInsets.only(top: 4, bottom: 32),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _BookmarkCard(
                          item: filtered[i],
                          onToggle: () => ref
                              .read(bookmarkNotifierProvider.notifier)
                              .toggle(filtered[i]),
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

// ── Filter tab ────────────────────────────────────────────────────────────────

class _Tab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _P.ink : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _P.ink : const Color(0xFFDEE2E6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : _P.inkSub,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _P.inkMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Bookmark card ─────────────────────────────────────────────────────────────

class _BookmarkCard extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onToggle;

  const _BookmarkCard({required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isCitizen = item.source == NewsSource.citizen;
    final imageUrl = isCitizen
        ? (item.mediaUrls.isNotEmpty ? item.mediaUrls.first : null)
        : item.imageUrl;
    final sourceLabel = isCitizen
        ? 'CITIZEN'
        : (item.sourceName?.toUpperCase() ?? 'WIRE');
    final sourceColor = isCitizen ? _P.citizen : _P.navy;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxWidth),
        child: GestureDetector(
          onTap: () => context.push('/report/${item.id}', extra: item),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: _P.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _P.hairline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, e, s) =>
                                  _Placeholder(isCitizen: isCitizen),
                            )
                          : _Placeholder(isCitizen: isCitizen),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Source + time
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
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: sourceColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '· ${timeAgo(item.publishedAt)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _P.inkMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Title
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _P.ink,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Bookmark toggle button
                  GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _P.navy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.bookmark,
                        size: 18,
                        color: _P.navy,
                      ),
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

class _Placeholder extends StatelessWidget {
  final bool isCitizen;
  const _Placeholder({required this.isCitizen});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isCitizen ? const Color(0xFF5C3317) : const Color(0xFF1A3A5C),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _Filter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final msg = switch (filter) {
      _Filter.all =>
        'No saved items yet.\nTap the bookmark icon on any\nreport or article to save it.',
      _Filter.citizen => 'No citizen reports saved.',
      _Filter.wire => 'No wire news saved.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 44,
              color: _P.inkMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: _P.inkMuted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
