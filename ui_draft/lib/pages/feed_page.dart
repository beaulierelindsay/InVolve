import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

class _Event {
  final String type;
  final String title;
  final String org;
  final String date;
  final String distance;
  final String action;
  final Color color;
  final Color lightColor;
  final String description;
  final int? spots;

  const _Event({
    required this.type,
    required this.title,
    required this.org,
    required this.date,
    required this.distance,
    required this.action,
    required this.color,
    required this.lightColor,
    required this.description,
    this.spots,
  });
}

const _events = [
  _Event(
    type: 'Civic',
    title: 'Community Board 6 Monthly Meeting',
    org: 'Brooklyn Community Board 6',
    date: 'Thu, Sep 24 · 7:00 PM',
    distance: '0.4 mi',
    action: 'Add to calendar',
    color: Color(0xFF1B4D3E),
    lightColor: Color(0xFFE8F0ED),
    description: 'Public session covering zoning proposals, housing updates, and open comment period.',
  ),
  _Event(
    type: 'Volunteer',
    title: 'Weekend Shift — Food Pantry',
    org: 'Park Slope Food Coop',
    date: 'Sat, Sep 27 · 9:00–12:00 AM',
    distance: '0.7 mi',
    action: 'Sign up',
    color: Color(0xFFC9631A),
    lightColor: Color(0xFFFDF0E6),
    description: 'Help sort and distribute groceries to 200+ households. All training provided on-site.',
    spots: 4,
  ),
  _Event(
    type: 'Stewardship',
    title: 'Prospect Park Fall Cleanup',
    org: 'Prospect Park Alliance',
    date: 'Sun, Sep 28 · 10:00 AM',
    distance: '1.1 mi',
    action: 'RSVP',
    color: Color(0xFF2D6A55),
    lightColor: Color(0xFFE4F0EB),
    description: 'Join 60+ volunteers for a seasonal trail and meadow cleanup. Gloves & tools provided.',
    spots: 18,
  ),
  _Event(
    type: 'Causes',
    title: 'Tenant Rights Letter-Writing Bank',
    org: 'Right to Counsel NYC',
    date: 'Wed, Sep 24 · 6:30 PM',
    distance: '1.8 mi',
    action: 'Join session',
    color: Color(0xFF5B3A8C),
    lightColor: Color(0xFFEEE8F5),
    description: 'Write letters to council members supporting the expansion of free legal counsel for tenants.',
  ),
];

const _filters = ['All', 'Civic', 'Volunteer', 'Causes', 'Culture', 'Mutual Aid'];

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  String _activeFilter = 'All';
  final Set<int> _saved = {};

  List<_Event> get _visible => _activeFilter == 'All'
      ? _events
      : _events.where((e) => e.type.toLowerCase().contains(_activeFilter.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
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
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final f = _filters[i];
                    final isActive = _activeFilter == f;
                    return GestureDetector(
                      onTap: () => setState(() => _activeFilter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.forest : AppColors.ground,
                          borderRadius: BorderRadius.circular(20),
                          border: isActive ? null : Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          f,
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
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  if (i >= _visible.length) return null;
                  final event = _visible[i];
                  final isSaved = _saved.contains(i);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _EventCard(
                      event: event,
                      isSaved: isSaved,
                      onSave: () => setState(() => isSaved ? _saved.remove(i) : _saved.add(i)),
                    ),
                  );
                },
                childCount: _visible.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final _Event event;
  final bool isSaved;
  final VoidCallback onSave;

  const _EventCard({required this.event, required this.isSaved, required this.onSave});

  @override
  Widget build(BuildContext context) {
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
                    color: event.lightColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(event.type, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: event.color)),
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
                    color: isSaved ? event.color : AppColors.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(event.title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 3),
            Text(event.org, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
            const SizedBox(height: 8),
            Text(event.description, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.inkMid, height: 1.5)),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.inkMuted),
                const SizedBox(width: 4),
                Text(event.date, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
                const SizedBox(width: 12),
                Icon(Icons.location_on_outlined, size: 12, color: AppColors.inkMuted),
                const SizedBox(width: 4),
                Text(event.distance, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: event.color,
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