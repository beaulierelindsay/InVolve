import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../models/category.dart';
import '../models/event.dart';
import '../services/event_service.dart';
import '../services/mock_events.dart';
import '../services/preferences_store.dart';

/// Flip to true to develop against placeholder data (no Firestore needed).
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
  final Set<String> _saved = {}; // event ids, so bookmarks survive filter changes

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
    super.dispose();
  }

  List<Event> _filter(List<Event> events) {
    if (_activeCategoryId == null) return events;
    if (_activeCategoryId == _forYouId) {
      final mine = PreferencesStore.instance.prefs.categoryIds;
      return events.where((e) => mine.contains(e.categoryId)).toList();
    }
    return events.where((e) => e.categoryId == _activeCategoryId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = PreferencesStore.instance.prefs;
    final chips = <({String? id, String label})>[
      if (prefs.hasInterests) (id: _forYouId, label: 'For you'),
      (id: null, label: 'All'),
      for (final c in allCategories) (id: c.id, label: c.shortLabel),
    ];

    return Scaffold(
      backgroundColor: AppColors.ground,
      body: StreamBuilder<List<Event>>(
        stream: _eventsStream,
        builder: (context, snap) {
          final visible = snap.hasData ? _filter(snap.data!) : const <Event>[];

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.canvas,
                surfaceTintColor: Colors.transparent,
                shadowColor: AppColors.border,
                elevation: 1,
                automaticallyImplyLeading: false,
                expandedHeight: 110,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: Container(
                    color: AppColors.canvas,
                    padding: const EdgeInsets.fromLTRB(24, 52, 24, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prefs.locationLabel.toUpperCase(),
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
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.ground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Icon(Icons.search, size: 18, color: AppColors.inkMid),
                        ),
                      ],
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    height: 48,
                    color: AppColors.canvas,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: chips.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final String? chipId = chips[i].id;
                        final String chipLabel = chips[i].label;
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
                              chipLabel,
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
                ),
              ),

              // Error → loading → empty → list
              if (snap.hasError)
                _MessageSliver(
                  message: "Couldn't load events. Check your connection and try again.",
                  detail: kDebugMode ? '${snap.error}' : null,
                )
              else if (!snap.hasData)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: AppColors.forest)),
                )
              else if (visible.isEmpty)
                _MessageSliver(
                  message: _activeCategoryId == _forYouId
                      ? 'Nothing matching your interests yet.\nTry "All" or edit your interests in the You tab.'
                      : 'No events in this category yet.',
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final event = visible[i];
                        final isSaved = _saved.contains(event.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _EventCard(
                            event: event,
                            isSaved: isSaved,
                            onSave: () => setState(
                              () => isSaved ? _saved.remove(event.id) : _saved.add(event.id),
                            ),
                          ),
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
    );
  }
}

class _MessageSliver extends StatelessWidget {
  final String message;
  final String? detail;
  const _MessageSliver({required this.message, this.detail});

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
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final bool isSaved;
  final VoidCallback onSave;

  const _EventCard({required this.event, required this.isSaved, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final category = event.category;
    final where = event.distanceLabel ?? event.location;

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
                GestureDetector(
                  onTap: onSave,
                  child: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_outline,
                    size: 20,
                    color: isSaved ? category.color : AppColors.inkMuted,
                  ),
                ),
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
                      if (event.dateLabel.isNotEmpty) ...[
                        Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.inkMuted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(event.dateLabel,
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
                  onPressed: () {},
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
