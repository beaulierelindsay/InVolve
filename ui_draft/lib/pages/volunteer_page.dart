import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

class _Shift {
  final String org;
  final String role;
  final String date;
  final int spots;
  final Color color;
  final Color lightColor;
  const _Shift({required this.org, required this.role, required this.date, required this.spots, required this.color, required this.lightColor});
}

const _shifts = [
  _Shift(org: 'Park Slope Food Coop', role: 'Food Distribution', date: 'Sat, Sep 27 · 9–12 AM', spots: 4, color: Color(0xFFC9631A), lightColor: Color(0xFFFDF0E6)),
  _Shift(org: 'Brooklyn Public Library', role: 'Adult Literacy Tutor', date: 'Tue & Thu · 5–7 PM', spots: 2, color: Color(0xFF1A5C8C), lightColor: Color(0xFFE6F0F8)),
  _Shift(org: 'Prospect Park Alliance', role: 'Trail Crew Volunteer', date: 'Sun, Sep 28 · 10 AM', spots: 18, color: Color(0xFF2D6A55), lightColor: Color(0xFFE4F0EB)),
];

class VolunteerPage extends StatelessWidget {
  const VolunteerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.canvas,
            surfaceTintColor: Colors.transparent,
            expandedHeight: 80,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                color: AppColors.canvas,
                padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OPEN NEAR YOU', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: AppColors.amber)),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w300, color: AppColors.ink),
                        children: const [
                          TextSpan(text: 'Volunteer '),
                          TextSpan(text: 'shifts', style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w400)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Divider(height: 1, color: AppColors.border)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  if (i >= _shifts.length) return null;
                  final s = _shifts[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.canvas,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: s.lightColor, borderRadius: BorderRadius.circular(20)),
                            child: Text('${s.spots} spots left', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: s.color)),
                          ),
                          const SizedBox(height: 12),
                          Text(s.role, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                          const SizedBox(height: 3),
                          Text(s.org, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
                          const SizedBox(height: 4),
                          Text(s.date, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: s.color,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Sign up', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: _shifts.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
