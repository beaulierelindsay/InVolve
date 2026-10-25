import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../models/category.dart';
import '../models/events.dart';
import '../services/event_service.dart';
import '../services/mock_events.dart';
import '../services/preferences_store.dart';
import '../widgets/save_button.dart';
import 'package:go_router/go_router.dart';

/// Flip to true to develop against placeholder data instead of Firestore.
const bool _useMockEvents = false;

// Sentinel for the personalized chip. null means "All".
const _forYouId = '__for_you__';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  // null = "All"; _forYouId = interests; otherwise an EngagementCategory.id
  String? _activeCategoryId;

  // Search
  bool _searching = false;
  String _query = '';
  final _searchController = TextEditingController();
  // Lowercased searchable text per Event object. Keyed by identity, so a
  // refreshed event from Firestore is recomputed automatically.
  final _searchText = Expando<String>();

  // Created once so rebuilds (filter taps) don't restart the Firestore listener.
  late final Stream<List<Event>> _eventsStream =
      _useMockEvents ? Stream.value(kMockEvents) : EventService().watchEvents();

  @override
  void initState() {
    super.initState();
    // Land on "For you" if the user picked interests; otherwise show everything.
    _activeCategoryId =
        PreferencesStore.instance.prefs.hasInterests ? _forYouId : null;
    PreferencesStore.instance.addListener(_onPrefsChanged);
  }

  void _onPrefsChanged() {
    if (!mounted) return;
    setState(() {
      // If interests were cleared while "For you" was active, fall back to All.
      if (_activeCategoryId == _forYouId &&
          !PreferencesStore.instance.prefs.hasInterests) {
        _activeCategoryId = null;
      }
    });
  }

  @override
  void dispose() {
    PreferencesStore.instance.removeListener(_onPrefsChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _toggleSearch() {
    setState(() {
      if (_searching) {
        _searching = false;
        _query = '';
        _searchController.clear();
      } else {
        _searching = true;
      }
    });
  }

  void _clearQuery() {
    _searchController.clear();
    setState(() => _query = '');
  }

  List<String> get _tokens =>
      _query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  String _searchTextFor(Event e) => _searchText[e] ??=
      '${e.title} ${e.org} ${e.description} ${e.location ?? ''} ${e.date} ${e.category.label}'
          .toLowerCase();

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<Event> _filter(List<Event> events) {
    var result = events;

    if (_activeCategoryId == _forYouId) {
      final mine = PreferencesStore.instance.prefs.categoryIds;
      result = result.where((e) => mine.contains(e.categoryId)).toList();
    } else if (_activeCategoryId != null) {
      result = result.where((e) => e.categoryId == _activeCategoryId).toList();
    }

    // Every word typed must appear somewhere in the event's text.
    final tokens = _tokens;
    if (tokens.isNotEmpty) {
      result = result.where((e) {
        final text = _searchTextFor(e);
        return tokens.every((t) => text.contains(t));
      }).toList();
    }
    return result;
  }

  Widget _buildSearchField() {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        );

    return TextField(
      controller: _searchController,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: (value) => setState(() => _query = value),
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: 'Search events, groups, places…',
        hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppColors.inkMuted),
        prefixIcon: Icon(Icons.search, size: 18, color: AppColors.inkMuted),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.cancel, size: 18, color: AppColors.inkMuted),
                tooltip: 'Clear',
                onPressed: _clearQuery,
              ),
        filled: true,
        fillColor: AppColors.ground,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.forest),
      ),
    );
  }

  Widget _buildSearchRow() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildSearchField(),
        ),
      );

  Widget _searchButton() => Semantics(
        button: true,
        label: _searching ? 'Close search' : 'Search events',
        child: GestureDetector(
          onTap: _toggleSearch,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _searching ? AppColors.forestLight : AppColors.ground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              _searching ? Icons.close : Icons.search,
              size: 18,
              color: _searching ? AppColors.forest : AppColors.inkMid,
            ),
          ),
        ),
      );

  Widget _buildChipsRow(List<({String? id, String label})> chips) {
    return Row(
      children: [
        Expanded(
          child: _FadingScroller(
            itemCount: chips.length,
            itemBuilder: (context, i) {
              final String? chipId = chips[i].id;
              final isActive = _activeCategoryId == chipId;
              return GestureDetector(
                onTap: () => setState(() => _activeCategoryId = chipId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.forest : AppColors.ground,
                    borderRadius: BorderRadius.circular(20),
                    border: isActive ? null : Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    chips[i].label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isActive ? Colors.white : AppColors.inkMid,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _searchButton(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = PreferencesStore.instance.prefs;
    final topInset = MediaQuery.of(context).padding.top;
    final chips = <({String? id, String label})>[
      if (prefs.hasInterests) (id: _forYouId, label: 'For you'),
      (id: null, label: 'All'),
      for (final c in allCategories) (id: c.id, label: c.shortLabel),
    ];

    return Scaffold(
      backgroundColor: AppColors.ground,
      body: Column(
        children: [
          // Solid strip under the status bar: content scrolls below it, never
          // behind the clock, and the pinned bar needs no extra top padding.
          Container(height: topInset, color: AppColors.canvas),
          Expanded(
            child: StreamBuilder<List<Event>>(
        stream: _eventsStream,
        builder: (context, snap) {
          final all = snap.data ?? const <Event>[];
          final visible = _filter(all);
          final hasQuery = _query.trim().isNotEmpty;

          final stillLoading = !snap.hasData && !snap.hasError;
          // Small inline notice when the stream errored but we still have events.
          final notice = snap.hasError && all.isNotEmpty
              ? "Couldn't load community events."
              : null;

          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              // Big title: scrolls away with the content.
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.canvas,
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prefs.displayLocation.toUpperCase(),
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: AppColors.amber),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w300, color: AppColors.ink),
                          children: const [
                            TextSpan(text: "What's happening "),
                            TextSpan(text: 'near you', style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w400)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Pinned: category chips and the search button stay reachable
              // while scrolling. The search field joins them when opened.
              SliverPersistentHeader(
                pinned: true,
                delegate: _FeedHeaderDelegate(
                  searchRow: _searching ? _buildSearchRow() : null,
                  chipsRow: _buildChipsRow(chips),
                ),
              ),

              // Result count
              if (hasQuery && visible.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 20, 0),
                    child: Text(
                      '${visible.length} ${visible.length == 1 ? 'result' : 'results'}',
                      style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted),
                    ),
                  ),
                ),

              // Partial-failure notice
              if (notice != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Text(notice, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
                  ),
                ),

              // Loading → error → empty → list
              if (all.isEmpty && stillLoading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: AppColors.forest)),
                )
              else if (all.isEmpty && snap.hasError)
                _MessageSliver(
                  message: "Couldn't load events. Check your connection and try again.",
                  detail: kDebugMode ? '${snap.error}' : null,
                )
              else if (visible.isEmpty)
                _MessageSliver(
                  message: hasQuery
                      ? 'No events match “${_query.trim()}”.'
                      : (_activeCategoryId == _forYouId
                          ? 'Nothing matching your interests yet.\nTry "All" or edit your interests in the You tab.'
                          : 'No events in this category yet.'),
                  // Offer to widen the search when a category chip is limiting it.
                  actionLabel: hasQuery && _activeCategoryId != null ? 'Search all events' : null,
                  onAction: () => setState(() => _activeCategoryId = null),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final event = visible[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _EventCard(event: event),
                        );
                      },
                      childCount: visible.length,
                    ),
                  ),
                ),
            ],
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned header: [optional search field] + category chips + search button.
class _FeedHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const double _chipsHeight = 52;
  static const double _searchHeight = 62;

  final Widget? searchRow;
  final Widget chipsRow;

  _FeedHeaderDelegate({
    required this.searchRow,
    required this.chipsRow,
  });

  // +1 for the bottom border, which takes 1px of the box (this was the
  // "bottom overflowed by 1 pixel" error).
  double get _extent => _chipsHeight + (searchRow != null ? _searchHeight : 0) + 1;

  @override
  double get minExtent => _extent;
  @override
  double get maxExtent => _extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        // Soft shadow only once the list is scrolling underneath.
        boxShadow: overlapsContent
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Column(
        children: [
          if (searchRow != null) SizedBox(height: _searchHeight, child: searchRow),
          SizedBox(height: _chipsHeight, child: chipsRow),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FeedHeaderDelegate oldDelegate) => true;
}

/// Horizontal list whose edges fade out where more content is hidden, so
/// items dissolve instead of being cut off hard (e.g. next to the search button).
/// The left fade only shows after scrolling; the right fade disappears once
/// the end is reached.
class _FadingScroller extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  const _FadingScroller({required this.itemCount, required this.itemBuilder});

  @override
  State<_FadingScroller> createState() => _FadingScrollerState();
}

class _FadingScrollerState extends State<_FadingScroller> {
  static const double _fadeWidth = 28;
  bool _fadeLeft = false;
  bool _fadeRight = true; // assume overflow until the first layout says otherwise

  void _update(ScrollMetrics m) {
    final left = m.pixels > 4;
    final right = m.pixels < m.maxScrollExtent - 4;
    if (left != _fadeLeft || right != _fadeRight) {
      setState(() {
        _fadeLeft = left;
        _fadeRight = right;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) {
        _update(n.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          _update(n.metrics);
          return false;
        },
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) {
            final f = _fadeWidth / rect.width;
            return LinearGradient(
              colors: [
                _fadeLeft ? Colors.transparent : Colors.white,
                Colors.white,
                Colors.white,
                _fadeRight ? Colors.transparent : Colors.white,
              ],
              stops: [0, f, 1 - f, 1],
            ).createShader(rect);
          },
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
            itemCount: widget.itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: widget.itemBuilder,
          ),
        ),
      ),
    );
  }
}

class _MessageSliver extends StatelessWidget {
  final String message;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _MessageSliver({required this.message, this.detail, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.inkMuted, height: 1.5),
              ),
              if (detail != null) ...[
                const SizedBox(height: 10),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 10, color: AppColors.inkMuted),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onAction,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      actionLabel!,
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.forest),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final category = event.category;
    final String where = event.distance ?? event.location ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: category.lightColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(category.shortLabel, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: category.color)),
                ),
                const Spacer(),
                if (event.spots != null)
                  Text('${event.spots} spots left', style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
                const SizedBox(width: 10),
                SaveButton(event: event),
              ],
            ),
            const SizedBox(height: 12),
            Text(event.title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
            if (event.org.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(event.org, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
            ],
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(event.description, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.inkMid, height: 1.5)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (event.date.isNotEmpty) ...[
                        Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.inkMuted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(event.date,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
                        ),
                      ],
                      if (where.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.location_on_outlined, size: 12, color: AppColors.inkMuted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(where,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => context.push('/feed/event', extra: event),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: category.color,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(event.action, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
