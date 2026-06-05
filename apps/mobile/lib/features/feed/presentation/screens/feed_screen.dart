import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/bookmark_provider.dart';
import '../../../../core/providers/device_country_provider.dart';
import '../../../../core/widgets/scroll_nav_buttons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../comments/presentation/widgets/comments_sheet.dart';
import '../../domain/entities/news_item.dart';
import '../providers/feed_provider.dart';
import '../providers/vote_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kMaxWidth = 700.0;

class _P {
  static const surface = Color(0xFFF8F9FA);
  static const card = Colors.white;
  static const navy = AppColors.reportNavy;
  static const ink = AppColors.reportInk;
  static const inkSecondary = AppColors.reportInkSecondary;
  static const inkTertiary = AppColors.reportInkTertiary;
  static const hairline = AppColors.reportHairline;
  static const citizen = Color(0xFFB54708);
  static const citizenSoft = Color(0xFFFEF3C7);
  static const verified = AppColors.reportVerified;
  static const verifiedSoft = AppColors.reportVerifiedSoft;
  static const disputed = AppColors.reportDisputed;
  static const disputedSoft = Color(0xFFFEE2E2);
  static const pending = Color(0xFF6B7280);
  static const pendingSoft = Color(0xFFF3F4F6);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  int _activeFilter = 0;

  List<NewsItem> _applyFilter(List<NewsItem> items) {
    return switch (_activeFilter) {
      1 => items.where((i) => i.source == NewsSource.citizen).toList(),
      2 => items.where((i) => i.source == NewsSource.wire).toList(),
      3 => items.where((i) => i.status == ItemStatus.verified).toList(),
      _ => items,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedNotifierProvider);
    final country = ref.watch(deviceCountryProvider).asData?.value ?? '';

    return ColoredBox(
      color: _P.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FeedAppBar(),
            _FeedHeader(
              country: country,
              citizenCount: state.items
                  .where((i) => i.source == NewsSource.citizen)
                  .length,
              wireSourceCount: state.items
                  .where(
                    (i) => i.source == NewsSource.wire && i.sourceName != null,
                  )
                  .map((i) => i.sourceName!)
                  .toSet()
                  .length,
            ),
            _FilterChips(
              active: _activeFilter,
              onChanged: (i) => setState(() => _activeFilter = i),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _P.navy),
                    )
                  : state.error != null
                  ? _ErrorState(error: state.error!)
                  : _FeedList(items: _applyFilter(state.items)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _FeedAppBar extends ConsumerWidget {
  const _FeedAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarkCount = ref.watch(bookmarkNotifierProvider).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _P.navy,
            ),
          ),
          const SizedBox(width: 7),
          const Text(
            'Frontline',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _P.ink,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search, color: _P.inkSecondary, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          // Bookmark icon — between search and notification
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => context.push('/bookmarks'),
                icon: const Icon(
                  Icons.bookmark_border,
                  color: _P.inkSecondary,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              if (bookmarkCount > 0)
                Positioned(
                  top: 8,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _P.navy,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_outlined,
              color: _P.inkSecondary,
              size: 22,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _FeedHeader extends StatelessWidget {
  final String country;
  final int citizenCount;
  final int wireSourceCount;
  const _FeedHeader({
    required this.country,
    required this.citizenCount,
    required this.wireSourceCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (country.isEmpty)
            Container(
              width: 160,
              height: 34,
              decoration: BoxDecoration(
                color: _P.hairline,
                borderRadius: BorderRadius.circular(6),
              ),
            )
          else
            Text(
              country,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: _P.ink,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
          const SizedBox(height: 5),
          Text(
            '$citizenCount citizen${citizenCount == 1 ? '' : 's'} reporting · $wireSourceCount source${wireSourceCount == 1 ? '' : 's'} active',
            style: const TextStyle(fontSize: 12, color: _P.inkTertiary),
          ),
        ],
      ),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final int active;
  final void Function(int) onChanged;
  const _FilterChips({required this.active, required this.onChanged});

  static const _labels = ['All', 'On the ground', 'Major sources', 'Verified'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _labels.length,
        separatorBuilder: (_, i) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = i == active;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _P.ink : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? _P.ink : _P.hairline),
              ),
              child: Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : _P.inkSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Feed list ─────────────────────────────────────────────────────────────────

class _FeedList extends StatefulWidget {
  final List<NewsItem> items;
  const _FeedList({required this.items});

  @override
  State<_FeedList> createState() => _FeedListState();
}

class _FeedListState extends State<_FeedList> {
  final _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(
        child: Text(
          'No items match this filter',
          style: TextStyle(color: _P.inkTertiary, fontSize: 14),
        ),
      );
    }
    return ScrollNavButtons.wrap(
      controller: _ctrl,
      child: ListView.builder(
        controller: _ctrl,
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: widget.items.length,
        itemBuilder: (_, i) {
          final item = widget.items[i];
          return item.source == NewsSource.citizen
              ? _CitizenCard(key: ValueKey(item.id), item: item)
              : _WireCard(key: ValueKey(item.id), item: item);
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          error,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _P.disputed, fontSize: 13),
        ),
      ),
    );
  }
}

// ── Citizen card ──────────────────────────────────────────────────────────────

class _CitizenCard extends ConsumerWidget {
  final NewsItem item;
  const _CitizenCard({super.key, required this.item});

  Future<void> _castVote(WidgetRef ref, String type) async {
    final ds = ref.read(voteDatasourceProvider);
    await ds.castVote(item.id, type);
    ref.invalidate(voteProvider(item.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voteAsync = ref.watch(voteProvider(item.id));
    final userVote = voteAsync.when(
      data: (v) => v,
      loading: () => null,
      error: (e, s) => null,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxWidth),
        child: GestureDetector(
          onTap: () => context.push('/report/${item.id}', extra: item),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _P.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      item.mediaUrls.isNotEmpty
                          ? Image.network(
                              item.mediaUrls.first,
                              fit: BoxFit.cover,
                              errorBuilder: (context, err, stack) =>
                                  const _CitizenPlaceholder(),
                            )
                          : const _CitizenPlaceholder(),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Wrap(
                          spacing: 6,
                          children: [
                            _Badge(
                              label: 'ON THE GROUND',
                              bgColor: _P.citizenSoft,
                              textColor: _P.citizen,
                            ),
                            if (item.status != null)
                              _StatusBadge(status: item.status!),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SourceLine(
                        dotColor: _P.citizen,
                        label: 'CITIZEN REPORT',
                        labelColor: _P.citizen,
                        meta: [
                          if (item.category != null)
                            _categoryLabel(item.category!),
                          timeAgo(item.publishedAt),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _P.ink,
                          height: 1.35,
                        ),
                      ),
                      if (item.body != null && item.body!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          item.body!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: _P.inkSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _VerifyMeter(
                        confirms: item.confirmCount,
                        disputes: item.disputeCount,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _ActionBtn(
                            icon: userVote == 'confirm'
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            count: item.confirmCount,
                            active: userVote == 'confirm',
                            activeColor: _P.verified,
                            onTap: () => _castVote(ref, 'confirm'),
                          ),
                          const SizedBox(width: 14),
                          _ActionBtn(
                            icon: userVote == 'dispute'
                                ? Icons.flag
                                : Icons.flag_outlined,
                            count: item.disputeCount,
                            active: userVote == 'dispute',
                            activeColor: _P.disputed,
                            onTap: () => _castVote(ref, 'dispute'),
                          ),
                          const SizedBox(width: 14),
                          _ActionBtn(
                            icon: Icons.chat_bubble_outline,
                            count: item.commentCount,
                            onTap: () => showCommentsSheet(
                              context,
                              reportId: item.id,
                              title: item.title,
                            ),
                          ),
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: () => context.push('/compare', extra: item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.compare_arrows,
                                    size: 16,
                                    color: _P.navy,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Compare',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _P.navy,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          _BookmarkBtn(item: item),
                          const SizedBox(width: 4),
                          _ActionBtn(
                            icon: Icons.share_outlined,
                            onTap: () => _showShareSheet(context, item),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE9ECEF)),
                _CompareWithRow(item: item),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CitizenPlaceholder extends StatelessWidget {
  const _CitizenPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF5C3317),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Color(0x44FFFFFF), size: 40),
      ),
    );
  }
}

// ── Verify meter ──────────────────────────────────────────────────────────────

class _VerifyMeter extends StatelessWidget {
  final int confirms;
  final int disputes;
  const _VerifyMeter({required this.confirms, required this.disputes});

  @override
  Widget build(BuildContext context) {
    final total = confirms + disputes;
    if (total == 0) return const SizedBox.shrink();
    final ratio = confirms / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 4,
            child: Row(
              children: [
                Expanded(
                  flex: (ratio * 100).round(),
                  child: Container(color: _P.verified),
                ),
                Expanded(
                  flex: 100 - (ratio * 100).round(),
                  child: Container(color: _P.disputed),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$confirms verified · $disputes flagged',
          style: const TextStyle(fontSize: 11, color: _P.inkTertiary),
        ),
      ],
    );
  }
}

// ── Wire card ─────────────────────────────────────────────────────────────────

class _WireCard extends StatelessWidget {
  final NewsItem item;
  const _WireCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxWidth),
        child: GestureDetector(
          onTap: () => context.push('/report/${item.id}', extra: item),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _P.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      item.imageUrl != null
                          ? Image.network(
                              item.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  Container(color: const Color(0xFF1A3A5C)),
                            )
                          : Container(color: const Color(0xFF1A3A5C)),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _Badge(
                          label: 'WIRE',
                          bgColor: Colors.white,
                          textColor: _P.navy,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SourceLine(
                        dotColor: _P.navy,
                        label: 'WIRE NEWS',
                        labelColor: _P.navy,
                        meta: [timeAgo(item.publishedAt)],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _P.ink,
                          height: 1.35,
                        ),
                      ),
                      if (item.body != null && item.body!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          item.body!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: _P.inkSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const Divider(height: 20, color: Color(0xFFE9ECEF)),
                      Row(
                        children: [
                          if (item.url != null)
                            GestureDetector(
                              onTap: () async {
                                final uri = Uri.tryParse(item.url!);
                                if (uri == null) return;
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.open_in_new,
                                    size: 14,
                                    color: _P.navy,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Open source',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _P.navy,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          _BookmarkBtn(item: item),
                          const SizedBox(width: 4),
                          _ActionBtn(
                            icon: Icons.share_outlined,
                            onTap: () => _showShareSheet(context, item),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE9ECEF)),
                _CompareWithRow(item: item),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Compare with row ──────────────────────────────────────────────────────────

class _CompareWithRow extends StatelessWidget {
  final NewsItem item;
  const _CompareWithRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/compare', extra: item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.compare_arrows, size: 15, color: _P.navy),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.category != null
                    ? 'Compare with other ${_categoryLabel(item.category!).toLowerCase()} reports'
                    : 'Compare with other reports',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _P.navy,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: _P.inkTertiary),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SourceLine extends StatelessWidget {
  final Color dotColor;
  final String label;
  final Color labelColor;
  final List<String> meta;
  const _SourceLine({
    required this.dotColor,
    required this.label,
    required this.labelColor,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: labelColor,
            letterSpacing: 0.3,
          ),
        ),
        for (final m in meta)
          Text(
            ' · $m',
            style: const TextStyle(fontSize: 11, color: _P.inkTertiary),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  const _Badge({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ItemStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      ItemStatus.verified => ('VERIFIED', _P.verifiedSoft, _P.verified),
      ItemStatus.disputed => ('DISPUTED', _P.disputedSoft, _P.disputed),
      ItemStatus.pending => ('PENDING REVIEW', _P.pendingSoft, _P.pending),
    };
    return _Badge(label: label, bgColor: bg, textColor: fg);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final int? count;
  final bool active;
  final Color? activeColor;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    this.count,
    this.active = false,
    this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? (activeColor ?? _P.navy) : _P.inkTertiary;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: count != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : Icon(icon, size: 20, color: color),
      ),
    );
  }
}

void _showShareSheet(BuildContext context, NewsItem item) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FeedShareSheet(item: item),
  );
}

// ── Share sheet ───────────────────────────────────────────────────────────────

class _FeedShareSheet extends StatelessWidget {
  final NewsItem item;
  const _FeedShareSheet({required this.item});

  String get _reportUrl => 'frontline.app/r/${item.id}';
  String get _fullUrl => 'https://$_reportUrl';

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.source == NewsSource.citizen
        ? (item.mediaUrls.isNotEmpty ? item.mediaUrls.first : null)
        : item.imageUrl;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDEE2E6),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            // ── Header ──────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.share_outlined,
                    color: Color(0xFF495057),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share report',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF212529),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Sharing never reveals the reporter',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF868E96),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFF868E96),
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Preview card ─────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE9ECEF)),
              ),
              child: Row(
                children: [
                  if (imageUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(11),
                        bottomLeft: Radius.circular(11),
                      ),
                      child: Image.network(
                        imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, e, s) => const _ShareThumb(),
                      ),
                    )
                  else
                    const ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(11),
                        bottomLeft: Radius.circular(11),
                      ),
                      child: _ShareThumb(),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _reportUrl.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF868E96),
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF212529),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ── Share buttons ─────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareBtn(
                  icon: Icons.link_rounded,
                  label: 'Copy link',
                  color: const Color(0xFF868E96),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _fullUrl));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied')),
                    );
                  },
                ),
                _ShareBtn(
                  icon: Icons.signal_cellular_alt,
                  label: 'Signal',
                  color: const Color(0xFF2C6BED),
                  onTap: () {
                    launchUrl(
                      Uri.parse('https://signal.me/share?url=$_fullUrl'),
                      mode: LaunchMode.externalApplication,
                    );
                    Navigator.pop(context);
                  },
                ),
                _ShareBtn(
                  icon: Icons.send_rounded,
                  label: 'Telegram',
                  color: const Color(0xFF0088CC),
                  onTap: () {
                    launchUrl(
                      Uri.parse(
                        'https://t.me/share/url?url=${Uri.encodeComponent(_fullUrl)}&text=${Uri.encodeComponent(item.title)}',
                      ),
                      mode: LaunchMode.externalApplication,
                    );
                    Navigator.pop(context);
                  },
                ),
                _ShareBtn(
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () {
                    launchUrl(
                      Uri.parse(
                        'https://wa.me/?text=${Uri.encodeComponent('${item.title}\n$_fullUrl')}',
                      ),
                      mode: LaunchMode.externalApplication,
                    );
                    Navigator.pop(context);
                  },
                ),
                _ShareBtn(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  color: const Color(0xFFE8421A),
                  onTap: () {
                    launchUrl(
                      Uri.parse(
                        'mailto:?subject=${Uri.encodeComponent(item.title)}&body=${Uri.encodeComponent(_fullUrl)}',
                      ),
                    );
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            // ── Privacy note ─────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: Color(0xFF1E3A8A),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'The shared link contains only the public report — no token, no device info, nothing tying it to the original reporter.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF495057),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareThumb extends StatelessWidget {
  const _ShareThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      color: const Color(0xFF1E3A8A),
      child: const Icon(
        Icons.article_outlined,
        color: Color(0x44FFFFFF),
        size: 28,
      ),
    );
  }
}

class _ShareBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF495057)),
          ),
        ],
      ),
    );
  }
}

class _BookmarkBtn extends ConsumerWidget {
  final NewsItem item;
  const _BookmarkBtn({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref
        .watch(bookmarkNotifierProvider)
        .any((i) => i.id == item.id);
    return _ActionBtn(
      icon: saved ? Icons.bookmark : Icons.bookmark_border,
      active: saved,
      activeColor: _P.navy,
      onTap: () => ref.read(bookmarkNotifierProvider.notifier).toggle(item),
    );
  }
}

String _categoryLabel(String category) {
  return switch (category) {
    'combat' => 'Combat',
    'aid' => 'Aid',
    'alert' => 'Alert',
    'displaced' => 'Displaced',
    'infra' => 'Infrastructure',
    _ => category,
  };
}
