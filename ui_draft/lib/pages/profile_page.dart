import 'dart:async';

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

  /// The signed-in user, if their email hasn't been verified yet.
  User? get _unverified {
    final u = user;
    return (u != null && u.email != null && !u.emailVerified) ? u : null;
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
                          Text(_subtitle(prefs.displayLocation),
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
                // Unverified accounts are asked to confirm their email.
                if (_unverified != null) ...[
                  _VerifyEmailBanner(key: ValueKey(_unverified!.uid), user: _unverified!),
                  const SizedBox(height: 14),
                ],

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
                            Text(prefs.displayLocation,
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
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: () => _deleteAccount(context),
                      child: Text('Delete account', style: GoogleFonts.outfit(fontSize: 12, color: _errorColor)),
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
    final u = user;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionLabel('SIGNED IN AS'),
              const Spacer(),
              if (u != null)
                GestureDetector(
                  onTap: () => _editName(context, u),
                  child: Text('Edit name',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.forest)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(user?.email ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 12),
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

/// Guests see saved events and interests. Signed-in users see saved,
/// submitted, and approved events.
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
    final saved = ListenableBuilder(
      listenable: SavedEventsStore.instance,
      builder: (context, _) => _tile('${SavedEventsStore.instance.count}', 'Saved\nevents'),
    );

    // Guests: a smaller set. Signing in unlocks the account stats.
    final submissions = _submissions;
    if (submissions == null) {
      return Row(
        children: [
          saved,
          const SizedBox(width: 8),
          _tile('${widget.interestCount}', 'Interests\nchosen'),
        ],
      );
    }

    return StreamBuilder<List<MySubmission>>(
      stream: submissions,
      builder: (context, snap) {
        final items = snap.data ?? const <MySubmission>[];
        final approved = items.where((s) => s.status == SubmissionStatus.approved).length;
        return Row(
          children: [
            saved,
            const SizedBox(width: 8),
            _tile('${items.length}', 'Events\nsubmitted'),
            const SizedBox(width: 8),
            _tile('$approved', 'Events\napproved'),
          ],
        );
      },
    );
  }
}

const _errorColor = Color(0xFFB3261E);

/// Shown on the profile until the user confirms their email address.
/// - "Resend email" has a 60 second cooldown (Firebase limits repeat sends).
/// - "I've verified" checks again. The app also checks quietly when the user
///   comes back from their mail app.
class _VerifyEmailBanner extends StatefulWidget {
  final User user;
  const _VerifyEmailBanner({super.key, required this.user});

  @override
  State<_VerifyEmailBanner> createState() => _VerifyEmailBannerState();
}

class _VerifyEmailBannerState extends State<_VerifyEmailBanner> with WidgetsBindingObserver {
  static const _cooldownSeconds = 60;

  Timer? _timer;
  int _cooldown = 0;
  bool _busy = false;
  bool _verified = false;
  bool _dismissed = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // Back from the mail app: check without bothering the user.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(silent: true);
  }

  Future<void> _check({bool silent = false}) async {
    if (_busy || _verified) return;
    if (!silent) setState(() { _busy = true; _message = null; });
    try {
      final verified = await AuthService.instance.refreshVerification();
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (verified) {
          _verified = true;
        } else if (!silent) {
          _message = 'Not verified yet. Open the link in the email, then tap again.';
          _messageIsError = true;
        }
      });
      if (verified) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _dismissed = true);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (!silent) {
          _message = "Couldn't check right now. Check your connection.";
          _messageIsError = true;
        }
      });
    }
  }

  Future<void> _resend() async {
    if (_busy || _cooldown > 0) return;
    setState(() { _busy = true; _message = null; });
    try {
      await AuthService.instance.sendVerificationEmail();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Sent! Check your inbox and your spam folder.';
        _messageIsError = false;
      });
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = AuthService.messageFor(e);
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Something went wrong. Please try again.';
        _messageIsError = true;
      });
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    if (_verified) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.forestLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.forest.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: AppColors.forest),
            const SizedBox(width: 10),
            Text('Email verified. Thank you!',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.forest)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mark_email_unread_outlined, size: 18, color: AppColors.amber),
              const SizedBox(width: 8),
              Text('Verify your email',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a link to ${widget.user.email}. Tap it to confirm your address. If you don\u2019t see it, check your spam folder.',
            style: GoogleFonts.outfit(fontSize: 12, height: 1.5, color: AppColors.inkMid),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (_busy || _cooldown > 0) ? null : _resend,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.inkMid,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend email',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : _check,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text("I\u2019ve verified", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(_message!,
                style: GoogleFonts.outfit(
                    fontSize: 11, height: 1.4, color: _messageIsError ? _errorColor : AppColors.forest)),
          ],
        ],
      ),
    );
  }
}

// ─── Edit name ──────────────────────────────────────────────────────────────

Future<void> _editName(BuildContext context, User user) async {
  final messenger = ScaffoldMessenger.of(context);
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _EditNameSheet(initialName: user.displayName ?? ''),
  );
  if (saved == true) messenger.showSnackBar(const SnackBar(content: Text('Name updated.')));
}

class _EditNameSheet extends StatefulWidget {
  final String initialName;
  const _EditNameSheet({required this.initialName});

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialName);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await AuthService.instance.updateDisplayName(_controller.text);
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { _busy = false; _error = AuthService.messageFor(e); });
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = "Couldn't save your name. Please try again."; });
    }
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c));

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit your name',
                style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w400, color: AppColors.ink)),
            const SizedBox(height: 6),
            Text('This is the name we use to greet you.',
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.inkMuted)),
            const SizedBox(height: 18),
            TextFormField(
              controller: _controller,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'First name',
                hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppColors.inkMuted),
                counterText: '',
                filled: true,
                fillColor: AppColors.ground,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: border(AppColors.border),
                enabledBorder: border(AppColors.border),
                focusedBorder: border(AppColors.forest),
                errorBorder: border(_errorColor),
                focusedErrorBorder: border(_errorColor),
                errorStyle: GoogleFonts.outfit(fontSize: 11, color: _errorColor),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 2) return 'Enter at least 2 characters';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: GoogleFonts.outfit(fontSize: 12, color: _errorColor)),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.inkMid,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Save', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
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

// ─── Delete account ─────────────────────────────────────────────────────────

Future<void> _deleteAccount(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DeleteAccountDialog(),
  );
  if (deleted == true) messenger.showSnackBar(const SnackBar(content: Text('Your account has been deleted.')));
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final password = _password.text;
    if (password.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      // 1. Prove it's really them (Firebase requires a recent sign-in).
      await AuthService.instance.reauthenticate(password);
      // 2. Remove their data while they're still signed in.
      await SubmissionService.instance.deleteAllMine();
      // 3. Delete the account itself. This also signs them out.
      await AuthService.instance.deleteAccount();
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final wrongPassword = e.code == 'wrong-password' || e.code == 'invalid-credential';
      setState(() {
        _busy = false;
        _error = wrongPassword ? 'That password is incorrect.' : AuthService.messageFor(e);
      });
    } on FirebaseException catch (e) {
      // A database problem: stop BEFORE deleting the account.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "Couldn't remove your data (${e.code}), so your account was not deleted. Please try again.";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "Couldn't finish. Check your connection and try again. Your account was not deleted.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c));
    final bodyStyle = GoogleFonts.outfit(fontSize: 12, height: 1.5, color: AppColors.inkMid);

    return AlertDialog(
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Delete your account?',
          style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w400, color: AppColors.ink)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This is permanent and can\'t be undone. It will delete:', style: bodyStyle),
            const SizedBox(height: 8),
            Text('\u2022  Your account and sign-in', style: bodyStyle),
            Text('\u2022  Every event submission you sent', style: bodyStyle),
            const SizedBox(height: 8),
            Text(
              'Events you added that were already approved stay in the feed, and they don\'t include your personal details. Saved events and interests live on this device only and are not affected.',
              style: GoogleFonts.outfit(fontSize: 11, height: 1.5, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              onSubmitted: (_) => _delete(),
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Enter your password to confirm',
                hintStyle: GoogleFonts.outfit(fontSize: 13, color: AppColors.inkMuted),
                filled: true,
                fillColor: AppColors.ground,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: border(AppColors.border),
                enabledBorder: border(AppColors.border),
                focusedBorder: border(_errorColor),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: GoogleFonts.outfit(fontSize: 12, height: 1.4, color: _errorColor)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.inkMuted)),
        ),
        TextButton(
          onPressed: _busy ? null : _delete,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _errorColor))
              : Text('Delete account', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: _errorColor)),
        ),
      ],
    );
  }
}
