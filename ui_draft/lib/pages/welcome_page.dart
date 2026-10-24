import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/preferences_store.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _locationController = TextEditingController();
  String _confirmedLocation = PreferencesStore.instance.prefs.locationLabel;
  bool _locationSet = false;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h >= 17) return 'Good evening';
    if (h >= 12) return 'Good afternoon';
    return 'Good morning';
  }

  void _confirmLocation() {
    if (_locationController.text.trim().isNotEmpty) {
      setState(() {
        _confirmedLocation = _locationController.text.trim();
        _locationSet = true;
      });
      PreferencesStore.instance.setLocation(_confirmedLocation);
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  /// First word of the display name, else the start of the email.
  String _firstName(User u) {
    final display = u.displayName?.trim();
    if (display != null && display.isNotEmpty) return display.split(RegExp(r'\s+')).first;
    final email = u.email ?? '';
    final local = email.contains('@') ? email.split('@').first : '';
    return local.isEmpty ? 'friend' : '${local[0].toUpperCase()}${local.substring(1)}';
  }

  /// "Welcome," for a brand-new account, "Welcome back," for returning ones.
  bool _isNewAccount(User u) {
    final created = u.metadata.creationTime;
    final last = u.metadata.lastSignInTime;
    return created != null && last != null && last.difference(created).inMinutes.abs() < 2;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.changes,
      initialData: AuthService.instance.currentUser,
      builder: (context, snap) {
        final u = snap.data;
        // Anonymous sessions count as guests.
        return _buildPage(context, (u != null && !u.isAnonymous) ? u : null);
      },
    );
  }

  Widget _buildPage(BuildContext context, User? user) {
    final hasInterests = PreferencesStore.instance.prefs.hasInterests;
    final signedIn = user != null;

    final intro = !signedIn
        ? 'Find civic meetings, volunteer work and local events near you. No account needed to browse.'
        : hasInterests
            ? "Here's what's happening near you."
            : "Let's set your neighborhood so we can find what's happening near you.";

    final primaryLabel = signedIn
        ? (hasInterests ? "See what's happening →" : 'Set my interests →')
        : 'Continue as guest →';

    return Scaffold(
      backgroundColor: AppColors.ground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.forest,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'InVolve',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // Greeting label
              Text(
                _greeting.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.amber,
                ),
              ),
              const SizedBox(height: 8),

              // Welcome heading
              RichText(
                text: TextSpan(
                  style: GoogleFonts.fraunces(
                    fontSize: 36,
                    fontWeight: FontWeight.w300,
                    color: AppColors.ink,
                    height: 1.2,
                  ),
                  children: [
                    TextSpan(
                      text: user == null
                          ? 'Welcome to\n'
                          : (_isNewAccount(user) ? 'Welcome,\n' : 'Welcome back,\n'),
                    ),
                    TextSpan(
                      text: user == null ? 'InVolve.' : '${_firstName(user)}.',
                      style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                intro,
                style: GoogleFonts.outfit(fontSize: 14, color: AppColors.inkMid, height: 1.6),
              ),

              // Guests are offered an account; signed-in users skip this.
              if (!signedIn) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HAVE AN ACCOUNT?',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.inkMuted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in or create one to add events and follow their review. Or continue as a guest below.',
                        style: GoogleFonts.outfit(fontSize: 12, height: 1.5, color: AppColors.inkMid),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.push('/signin'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: BorderSide(color: AppColors.forest),
                            foregroundColor: AppColors.forest,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('Sign in or create account',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Map placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: AppColors.forestLight,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      // Grid background
                      CustomPaint(
                        size: const Size(double.infinity, 240),
                        painter: _MapGridPainter(),
                      ),
                      // Pin + label
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.forest,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.forest.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.location_on, color: Colors.white, size: 28),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _confirmedLocation.isEmpty ? 'Set your neighborhood' : _confirmedLocation,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.forest,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add google_maps_flutter API key to enable live map',
                              style: GoogleFonts.outfit(fontSize: 10, color: AppColors.inkMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Location card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR NEIGHBORHOOD',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _locationController,
                            onSubmitted: (_) => _confirmLocation(),
                            decoration: const InputDecoration(
                              hintText: 'Enter city, ZIP, or neighborhood…',
                            ),
                            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.ink),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _confirmLocation,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                          child: const Text('Set'),
                        ),
                      ],
                    ),
                    if (_locationSet) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.forestLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 14, color: AppColors.forest),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Location set to $_confirmedLocation',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppColors.forest,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Nearby stats
              Text(
                "WHAT'S HAPPENING NEARBY",
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _StatTile(count: '12', label: 'Events\nthis week', color: AppColors.forest),
                  const SizedBox(width: 8),
                  _StatTile(count: '5', label: 'Volunteer\nshifts', color: AppColors.amber),
                  const SizedBox(width: 8),
                  _StatTile(count: '3', label: 'Civic\nmeetings', color: const Color(0xFF5B3A8C)),
                ],
              ),

              const SizedBox(height: 24),

              // Primary action depends on who is here and what is already set up
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go(hasInterests ? '/feed' : '/interests'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    primaryLabel,
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (!hasInterests) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => context.go('/feed'),
                    child: Text(
                      'Skip for now',
                      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.inkMid),
                    ),
                  ),
                ),
              ],
              if (!signedIn) ...[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'You can sign in any time from the You tab.',
                    style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted),
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

class _StatTile extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  const _StatTile({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w600, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(fontSize: 10, color: AppColors.inkMuted, height: 1.3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1B4D3E).withValues(alpha: 0.12)
      ..strokeWidth = 0.8;

    // Horizontal lines
    for (int i = 0; i < 8; i++) {
      final y = i * size.height / 7;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical lines
    for (int i = 0; i < 12; i++) {
      final x = i * size.width / 11;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    final blockPaint = Paint()..color = const Color(0xFF1B4D3E).withValues(alpha: 0.18);
    final rr = const Radius.circular(4);
    canvas.drawRRect(RRect.fromLTRBR(60, 40, 150, 90, rr), blockPaint);
    canvas.drawRRect(RRect.fromLTRBR(170, 35, 270, 65, rr), blockPaint..color = const Color(0xFF1B4D3E).withValues(alpha: 0.12));
    canvas.drawRRect(RRect.fromLTRBR(60, 105, 130, 185, rr), blockPaint..color = const Color(0xFF1B4D3E).withValues(alpha: 0.15));
    canvas.drawRRect(RRect.fromLTRBR(145, 85, 265, 145, rr), blockPaint..color = const Color(0xFF1B4D3E).withValues(alpha: 0.10));
  }

  @override
  bool shouldRepaint(_) => false;
}
