import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../models/category.dart';
import '../services/auth_service.dart';
import '../services/preferences_store.dart';
import '../services/saved_events_store.dart';
import '../services/submission_service.dart';

/// Profile tab. Shows a guest view when nobody is signed in, and the real
/// account (name, email, member-since, submissions) when someone is.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.changes,
      initialData: AuthService.instance.currentUser,
      builder: (context, snap) {
        final user = snap.data;
        // Anonymous sessions are treated as guests.
        final account = (user != null && !user.isAnonymous) ? user : null;
        return _ProfileView(user: account);
      },
    );
  }
}

class _ProfileView extends StatelessWidget {
  final User? user; // null = guest
  const _ProfileView({required this.user});

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String get _name {
    final u = user;
    if (u == null) return 'Guest';
    final display = u.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final email = u.email ?? '';
    return email.contains('@') ? email.split('@').first : 'You';
  }

  String _subtitle(String location) {
    final created = user?.metadata.creationTime;
    final since = created == null ? null : 'Member since ${_months[created.month - 1]} ${created.year}';
    return [location, if (since != null) since].join(' · ');
  }

  BoxDecoration get _card => BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.inkMuted),
      );

  @override
  Widget build(BuildContext context) {
    final prefs = PreferencesStore.instance.prefs;
    final myCategories = allCategories.where((c) => prefs.categoryIds.contains(c.id)).toList();
    final signedIn = user != null;

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
                      decoration: BoxDecoration(
                        color: signedIn ? AppColors.forest : AppColors.forestLight,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: signedIn
                            ? Text(_name.isEmpty ? '?' : _name[0].toUpperCase(),
                                style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white))
                            : Icon(Icons.person_outline, size: 26, color: AppColors.forest),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink)),
                          Text(_subtitle(prefs.locationLabel),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Real numbers only: nothing here is made up.
                _StatsRow(
                  key: ValueKey(user?.uid),
                  signedIn: signedIn,
                  interestCount: myCategories.length,
                ),
                const SizedBox(height: 14),

                // Account (signed in) or invitation (guest)
                if (signedIn) _accountCard(context) else _guestCard(context),
                const SizedBox(height: 12),

                // Interests
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _sectionLabel('MY INTERESTS'),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => context.go('/interests'),
                            child: Text('Edit', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.forest)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (myCategories.isEmpty)
                        Text('No interests yet — tap Edit to pick some.',
                            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.inkMuted))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: myCategories
                              .map((c) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: c.lightColor, borderRadius: BorderRadius.circular(20)),
                                    child: Text(c.shortLabel,
                                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: c.color)),
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Location
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _card,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('LOCATION'),
                            const SizedBox(height: 6),
                            Text(prefs.locationLabel,
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
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

                // Sign out only makes sense when signed in
                if (signedIn) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => AuthService.instance.signOut(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.inkMuted,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('Sign out', style: GoogleFonts.outfit(fontSize: 14)),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _card,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('SIGNED IN AS'),
                const SizedBox(height: 6),
                Text(user?.email ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => context.go('/create'),
            child: Text('Your submissions',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.forest)),
          ),
        ],
      ),
    );
  }

  Widget _guestCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('ACCOUNT'),
          const SizedBox(height: 8),
          Text('Create an account to add events and follow their review. Browsing and saving work without one.',
              style: GoogleFonts.outfit(fontSize: 12, height: 1.5, color: AppColors.inkMid)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/signin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Sign in or create account', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Saved events, interests, and (when signed in) submissions sent.
class _StatsRow extends StatefulWidget {
  final bool signedIn;
  final int interestCount;
  const _StatsRow({super.key, required this.signedIn, required this.interestCount});

  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow> {
  // Created once so rebuilds don't restart the Firestore listener.
  late final Stream<List<MySubmission>>? _submissions =
      widget.signedIn ? SubmissionService.instance.watchMine() : null;

  Widget _tile(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text(value, style: GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.forest)),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.outfit(fontSize: 10, color: AppColors.inkMuted, height: 1.3),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ListenableBuilder(
          listenable: SavedEventsStore.instance,
          builder: (context, _) => _tile('${SavedEventsStore.instance.count}', 'Saved\nevents'),
        ),
        const SizedBox(width: 8),
        _tile('${widget.interestCount}', 'Interests\nchosen'),
        const SizedBox(width: 8),
        if (_submissions == null)
          _tile('–', 'Events\nsubmitted')
        else
          StreamBuilder<List<MySubmission>>(
            stream: _submissions,
            builder: (context, snap) => _tile('${snap.data?.length ?? 0}', 'Events\nsubmitted'),
          ),
      ],
    );
  }
}
