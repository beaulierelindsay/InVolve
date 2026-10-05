import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../models/category.dart'; // adjust path to wherever category.dart lives
import '../models/events.dart';
import '../services/legistar_service.dart';

// Mock events for categories without a live data source yet.
const _mockEvents = [
  Event(
    id: 'evt-001',
    categoryId: CategoryIds.civic,
    title: 'Community Board 6 Monthly Meeting',
    org: 'Brooklyn Community Board 6',
    date: 'Thu, Sep 24 · 7:00 PM',
    distance: '0.4 mi',
    action: 'Add to calendar',
    description:
        'Public session covering zoning proposals, housing updates, and open comment period.',
  ),
  Event(
    id: 'evt-002',
    categoryId: CategoryIds.directService,
    title: 'Weekend Shift — Food Pantry',
    org: 'Park Slope Food Coop',
    date: 'Sat, Sep 27 · 9:00–12:00 AM',
    distance: '0.7 mi',
    action: 'Sign up',
    description:
        'Help sort and distribute groceries to 200+ households. All training provided on-site.',
    spots: 4,
  ),
  Event(
    id: 'evt-003',
    categoryId: CategoryIds.neighborhood,
    title: 'Prospect Park Fall Cleanup',
    org: 'Prospect Park Alliance',
    date: 'Sun, Sep 28 · 10:00 AM',
    distance: '1.1 mi',
    action: 'RSVP',
    description:
        'Join 60+ volunteers for a seasonal trail and meadow cleanup. Gloves & tools provided.',
    spots: 18,
  ),
  Event(
    id: 'evt-004',
    categoryId: CategoryIds.causeAction,
    title: 'Tenant Rights Letter-Writing Bank',
    org: 'Right to Counsel NYC',
    date: 'Wed, Sep 24 · 6:30 PM',
    distance: '1.8 mi',
    action: 'Join session',
    description:
        'Write letters to council members supporting the expansion of free legal counsel for tenants.',
  ),
];

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  // null = "All"; otherwise an EngagementCategory.id
  String? _activeCategoryId;
  final Set<String> _saved =
      {}; // event ids, so bookmarks survive filter changes

  final _legistar = LegistarService();
  List<Event> _liveEvents = [];
  bool _loading = true;
  String? _loadError;

  List<Event> get _events => [..._liveEvents, ..._mockEvents];

  List<Event> get _visible => _activeCategoryId == null
      ? _events
      : _events.where((e) => e.categoryId == _activeCategoryId).toList();

  @override
  void initState() {
    super.initState();
    _loadLiveEvents();
  }

  Future<void> _loadLiveEvents() async {
    try {
      final events = await _legistar.fetchUpcomingEvents();
      if (!mounted) return;
      setState(() {
        _liveEvents = events;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Legistar fetch failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = "Couldn't load council meetings. Showing sample events.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return Scaffold(
      backgroundColor: AppColors.ground,
      body: CustomScrollView(
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
                            'BROOKLYN, NY',
                            style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.4,
                                color: AppColors.amber),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.fraunces(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w300,
                                  color: AppColors.ink),
                              children: const [
                                TextSpan(text: "What's happening "),
                                TextSpan(
                                    text: 'near you',
                                    style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w400)),
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
                      child:
                          Icon(Icons.search, size: 18, color: AppColors.inkMid),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  // +1 for the "All" chip at index 0; the rest are generated
                  // from allCategories so chips can never drift from the model.
                  itemCount: allCategories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final String? chipId =
                        i == 0 ? null : allCategories[i - 1].id;
                    final String chipLabel =
                        i == 0 ? 'All' : allCategories[i - 1].shortLabel;
                    final isActive = _activeCategoryId == chipId;
                    return GestureDetector(
                      onTap: () => setState(() => _activeCategoryId = chipId),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.forest : AppColors.ground,
                          borderRadius: BorderRadius.circular(20),
                          border: isActive
                              ? null
                              : Border.all(color: AppColors.border),
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
          if (_loading || _loadError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _loading
                    ? const LinearProgressIndicator(minHeight: 2)
                    : Text(_loadError!,
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: AppColors.inkMuted)),
              ),
            ),
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
                        () => isSaved
                            ? _saved.remove(event.id)
                            : _saved.add(event.id),
                      ),
                    ),
                  );
                },
                childCount: visible.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final bool isSaved;
  final VoidCallback onSave;

  const _EventCard(
      {required this.event, required this.isSaved, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final category = event.category;

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: category.lightColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(category.shortLabel,
                      style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: category.color)),
                ),
                const Spacer(),
                if (event.spots != null)
                  Text('${event.spots} spots left',
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: AppColors.inkMuted)),
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
            Text(event.title,
                style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
            const SizedBox(height: 3),
            Text(event.org,
                style: GoogleFonts.outfit(
                    fontSize: 11, color: AppColors.inkMuted)),
            const SizedBox(height: 8),
            Text(event.description,
                style: GoogleFonts.outfit(
                    fontSize: 12, color: AppColors.inkMid, height: 1.5)),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 12, color: AppColors.inkMuted),
                const SizedBox(width: 4),
                Text(event.date,
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.inkMuted)),
                const SizedBox(width: 12),
                Icon(Icons.location_on_outlined,
                    size: 12, color: AppColors.inkMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(event.distance ?? event.location ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: AppColors.inkMuted)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: category.color,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(event.action,
                      style: GoogleFonts.outfit(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
