import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../models/events.dart';
import '../models/rsvp.dart';
import '../services/auth_service.dart';
import '../services/rsvp_service.dart';

/// The RSVP control on the event details page.
///
/// - Guests see "Sign in to RSVP" (an RSVP belongs to an account).
/// - Internal events (all of them while kOrganizerForwardingEnabled is false):
///   one tap, nothing personal collected, with a plain note saying so.
/// - Organizer events: opens a short form with an explicit consent checkbox.
class RsvpButton extends StatefulWidget {
  final Event event;
  final Color color;
  const RsvpButton({super.key, required this.event, required this.color});

  @override
  State<RsvpButton> createState() => _RsvpButtonState();
}

class _RsvpButtonState extends State<RsvpButton> {
  bool _busy = false;
  Stream<Rsvp?>? _stream;
  String? _streamUid;

  /// Rebuilds the Firestore listener only when the signed-in user changes.
  Stream<Rsvp?> _streamFor(User user) {
    if (_streamUid != user.uid || _stream == null) {
      _streamUid = user.uid;
      _stream = RsvpService.instance.watch(widget.event);
    }
    return _stream!;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _rsvp() async {
    final event = widget.event;
    OrganizerDetails? details;
    if (rsvpModeFor(event) == RsvpMode.organizer) {
      details = await showModalBottomSheet<OrganizerDetails>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.canvas,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _DetailsSheet(event: event),
      );
      if (details == null) return; // dismissed
    }
    setState(() => _busy = true);
    try {
      await RsvpService.instance.rsvp(event, details: details);
      _toast(details == null ? 'Added to your plans.' : 'Saved. We\'ll pass your details to the organizer.');
    } catch (_) {
      _toast("Couldn't save your RSVP. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Rsvp rsvp) async {
    final shared = rsvp.shareWithOrganizer && rsvp.forwardStatus == 'sent';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text('Cancel your RSVP?',
            style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w400, color: AppColors.ink)),
        content: Text(
          shared
              ? 'This removes it from InVolve. Your details were already sent to the organizer, so contact them to cancel there too.'
              : 'This removes the event from your plans.',
          style: GoogleFonts.outfit(fontSize: 13, height: 1.5, color: AppColors.inkMid),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel RSVP')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await RsvpService.instance.cancel(widget.event);
    } catch (_) {
      _toast("Couldn't cancel. Please try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ButtonStyle get _filled => ElevatedButton.styleFrom(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );

  Widget _label(String text) =>
      Text(text, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600));

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final note = rsvpNoteFor(event);

    return StreamBuilder<User?>(
      stream: AuthService.instance.changes,
      initialData: AuthService.instance.currentUser,
      builder: (context, authSnap) {
        final user = authSnap.data;
        final signedIn = user != null && !user.isAnonymous;

        if (!signedIn) {
          return _wrap(
            ElevatedButton(
              onPressed: () => context.push('/signin'),
              style: _filled,
              child: _label('Sign in to ${rsvpLabelFor(event).toLowerCase()}'),
            ),
            note,
          );
        }

        return StreamBuilder<Rsvp?>(
          stream: _streamFor(user),
          builder: (context, snap) {
            final rsvp = snap.data;
            if (rsvp != null) {
              return _wrap(
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _cancel(rsvp),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.color,
                    side: BorderSide(color: widget.color),
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: _label(
                      eventSource(event) == 'legistar' ? "You're planning to attend" : "You're going"),
                ),
                'Tap to cancel.',
              );
            }
            return _wrap(
              ElevatedButton(
                onPressed: (_busy || snap.connectionState == ConnectionState.waiting) ? null : _rsvp,
                style: _filled,
                child: _busy
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : _label(rsvpLabelFor(event)),
              ),
              note,
            );
          },
        );
      },
    );
  }

  Widget _wrap(Widget button, String? note) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          button,
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(note,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 11, height: 1.5, color: AppColors.inkMuted)),
            ),
        ],
      );
}

/// Contact form for organizer-forwarded RSVPs. Only reachable when
/// kOrganizerForwardingEnabled is true. Phone is optional, and text messages
/// are never opted into by default.
class _DetailsSheet extends StatefulWidget {
  final Event event;
  const _DetailsSheet({required this.event});

  @override
  State<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends State<_DetailsSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _email;
  final _phone = TextEditingController();
  final _zip = TextEditingController();
  bool _consent = false;
  bool _showConsentError = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    final parts = (user?.displayName ?? '').trim().split(RegExp(r'\s+'));
    _first = TextEditingController(text: parts.first);
    _last = TextEditingController(text: parts.length > 1 ? parts.sublist(1).join(' ') : '');
    _email = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _zip]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _org => widget.event.org.isEmpty ? 'the organizer' : widget.event.org;
  String get _consentText =>
      'I agree to share my name, email, ZIP code and phone number (if provided) with $_org so they can register me for this event.';

  void _submit() {
    final valid = _form.currentState!.validate();
    setState(() => _showConsentError = !_consent);
    if (!valid || !_consent) return;
    Navigator.pop(
      context,
      OrganizerDetails(
        givenName: _first.text,
        familyName: _last.text,
        email: _email.text,
        phone: _phone.text,
        postalCode: _zip.text,
        consentText: _consentText,
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        labelText: hint,
        filled: true,
        fillColor: AppColors.ground,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
      );

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Your details',
                  style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w400, color: AppColors.ink)),
              const SizedBox(height: 6),
              Text('$_org needs these to register you.',
                  style: GoogleFonts.outfit(fontSize: 13, color: AppColors.inkMuted)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: TextFormField(controller: _first, decoration: _dec('First name'), validator: _required)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _last, decoration: _dec('Last name'), validator: _required)),
              ]),
              const SizedBox(height: 10),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('Email'),
                validator: (v) => (v == null || !v.contains('@') || !v.contains('.')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _zip,
                keyboardType: TextInputType.number,
                decoration: _dec('ZIP code'),
                validator: (v) => RegExp(r'^\d{5}$').hasMatch((v ?? '').trim()) ? null : 'Enter a 5-digit ZIP',
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: _dec('Phone (optional)'),
              ),
              const SizedBox(height: 4),
              Text("We won't sign you up for text messages.",
                  style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
              const SizedBox(height: 14),
              CheckboxListTile(
                value: _consent,
                onChanged: (v) => setState(() => _consent = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(_consentText, style: GoogleFonts.outfit(fontSize: 12, height: 1.5, color: AppColors.inkMid)),
              ),
              if (_showConsentError && !_consent)
                Text('Please agree to continue.',
                    style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFFB3261E))),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Confirm RSVP', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
