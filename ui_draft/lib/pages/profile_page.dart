import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _interests = ['Civic Meetings', 'Direct-Service Volunteering', 'Neighborhood Stewardship'];
  static const _stats = [
    (n: '3', label: 'Events\nattended'),
    (n: '1', label: 'Shifts\ncompleted'),
    (n: '2', label: 'Actions\ntaken'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.canvas,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                color: AppColors.canvas,
                padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: AppColors.forest, shape: BoxShape.circle),
                      child: Center(
                        child: Text('J', style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Jordan', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink)),
                        Text('Brooklyn, NY · Member since Sep 2026',
                            style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Divider(height: 1, color: AppColors.border)),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stats
                Row(
                  children: _stats.map((s) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: s == _stats.last ? 0 : 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.canvas,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Text(s.n, style: GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.forest)),
                            const SizedBox(height: 4),
                            Text(s.label, style: GoogleFonts.outfit(fontSize: 10, color: AppColors.inkMuted, height: 1.3), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  )).toList(),
                ),

                const SizedBox(height: 14),

                // Interests card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('MY INTERESTS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.inkMuted)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => context.go('/interests'),
                            child: Text('Edit', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.forest)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _interests.map((i) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.forestLight, borderRadius: BorderRadius.circular(20)),
                          child: Text(i, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.forest)),
                        )).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Location card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LOCATION', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.inkMuted)),
                            const SizedBox(height: 6),
                            Text('Brooklyn, New York', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/welcome'),
                        child: Text('Change', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.forest)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Sign out
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.inkMuted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Sign out', style: GoogleFonts.outfit(fontSize: 14)),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
