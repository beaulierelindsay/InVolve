import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../models/category.dart';
import '../services/auth_service.dart';
import '../services/submission_service.dart';

const _errorColor = Color(0xFFB3261E);

/// Public entry point for the Add tab. Only signed-in users see the form.
class CreateEventPage extends StatelessWidget {
  const CreateEventPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.changes,
      initialData: AuthService.instance.currentUser,
      builder: (context, snap) {
        final user = snap.data;
        final signedIn = user != null && !user.isAnonymous;
        return signedIn ? const _CreateEventForm() : const _SignedOutView();
      },
    );
  }
}

/// Shown instead of the form when nobody is signed in.
class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SHARE WITH YOUR COMMUNITY',
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: AppColors.amber)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w300, color: AppColors.ink),
                    children: const [
                      TextSpan(text: 'Add an '),
                      TextSpan(text: 'event', style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: AppColors.forestLight, borderRadius: BorderRadius.circular(18)),
                      child: Icon(Icons.person_outline, size: 26, color: AppColors.forest),
                    ),
                    const SizedBox(height: 16),
                    Text('Sign in to add events',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    Text(
                      'An account lets us review your submissions and show you when they are approved. You can keep browsing the feed without one.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 12, height: 1.5, color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => context.push('/signin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Sign in or create account',
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateEventForm extends StatefulWidget {
  const _CreateEventForm();

  @override
  State<_CreateEventForm> createState() => _CreateEventFormState();
}

class _CreateEventFormState extends State<_CreateEventForm> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _title = TextEditingController();
  final _org = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _link = TextEditingController();

  SubmissionType _type = SubmissionType.hosted;
  String? _categoryId;
  DateTime? _date;
  TimeOfDay? _time;
  bool _categoryError = false;
  bool _dateError = false;
  bool _submitting = false;

  bool get _isFound => _type == SubmissionType.found;

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [_title, _org, _location, _description, _link]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() { _date = picked; _dateError = false; });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final fieldsOk = _formKey.currentState!.validate();
    setState(() {
      _categoryError = _categoryId == null;
      _dateError = _date == null;
    });
    if (!fieldsOk || _categoryId == null || _date == null) return;

    setState(() => _submitting = true);
    try {
      final d = _date!;
      final startsAt = DateTime(d.year, d.month, d.day, _time?.hour ?? 0, _time?.minute ?? 0);
      await SubmissionService.instance.submit(EventSubmission(
        type: _type,
        title: _title.text.trim(),
        categoryId: _categoryId!,
        org: _org.text.trim(),
        location: _location.text.trim(),
        description: _description.text.trim(),
        url: SubmissionService.normalizeUrl(_link.text) ?? '',
        startsAt: startsAt,
        hasTime: _time != null,
      ));
      if (!mounted) return;
      _resetForm();
      _toast('Thanks! Your event was sent for review.');
    } on StateError {
      if (mounted) _toast('Please sign in to add an event.');
    } catch (_) {
      if (mounted) _toast("Couldn't send your event. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    for (final c in [_title, _org, _location, _description, _link]) {
      c.clear();
    }
    setState(() {
      _type = SubmissionType.hosted;
      _categoryId = null;
      _date = null;
      _time = null;
      _categoryError = false;
      _dateError = false;
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _toast(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  // ── UI helpers ────────────────────────────────────────────────────────────

  InputDecoration _decoration(String hint) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppColors.inkMuted),
      counterText: '',
      filled: true,
      fillColor: AppColors.canvas,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.forest),
      errorBorder: border(_errorColor),
      focusedErrorBorder: border(_errorColor),
      errorStyle: GoogleFonts.outfit(fontSize: 11, color: _errorColor),
    );
  }

  Widget _block(String label, Widget child, {String? optionalNote}) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label.isNotEmpty) ...[
              Row(
                children: [
                  Text(label,
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkMid)),
                  if (optionalNote != null) ...[
                    const SizedBox(width: 6),
                    Text(optionalNote, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
                  ],
                ],
              ),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      );

  Widget _textField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    int maxLength = 150,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textCapitalization: maxLines > 1 ? TextCapitalization.sentences : TextCapitalization.words,
      validator: validator,
      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.ink),
      decoration: _decoration(hint),
    );
  }

  Widget _typeToggle() {
    Widget segment(SubmissionType type, String label) {
      final on = _type == type;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _type = type),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: on ? AppColors.forest : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w600, color: on ? Colors.white : AppColors.inkMid)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            segment(SubmissionType.hosted, "I'm organizing it"),
            segment(SubmissionType.found, 'I found it'),
          ]),
        ),
        const SizedBox(height: 8),
        Text(
          _isFound
              ? "Know about an event that's missing? Add it with a link so we can verify it."
              : "You're hosting or running this event.",
          style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted, height: 1.4),
        ),
      ],
    );
  }

  Widget _categoryPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in allCategories)
              GestureDetector(
                onTap: () => setState(() { _categoryId = c.id; _categoryError = false; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _categoryId == c.id ? c.color : AppColors.canvas,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _categoryId == c.id ? c.color : AppColors.border),
                  ),
                  child: Text(c.shortLabel,
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _categoryId == c.id ? Colors.white : AppColors.inkMid)),
                ),
              ),
          ],
        ),
        if (_categoryError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Pick a category', style: GoogleFonts.outfit(fontSize: 11, color: _errorColor)),
          ),
      ],
    );
  }

  Widget _pickerBox({required IconData icon, required String text, required bool filled, required VoidCallback onTap, bool error = false, VoidCallback? onClear}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: error ? _errorColor : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.inkMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontSize: 14, color: filled ? AppColors.ink : AppColors.inkMuted)),
            ),
            if (filled && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.cancel, size: 16, color: AppColors.inkMuted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateTimeRow() {
    final loc = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _pickerBox(
                icon: Icons.calendar_today_outlined,
                text: _date == null ? 'Pick a date' : loc.formatMediumDate(_date!),
                filled: _date != null,
                error: _dateError,
                onTap: _pickDate,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _pickerBox(
                icon: Icons.schedule,
                text: _time == null ? 'Add time' : _time!.format(context),
                filled: _time != null,
                onTap: _pickTime,
                onClear: () => setState(() => _time = null),
              ),
            ),
          ],
        ),
        if (_dateError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Pick a date', style: GoogleFonts.outfit(fontSize: 11, color: _errorColor)),
          ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SHARE WITH YOUR COMMUNITY',
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: AppColors.amber)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w300, color: AppColors.ink),
                    children: const [
                      TextSpan(text: 'Add an '),
                      TextSpan(text: 'event', style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _block('', _typeToggle()),
                    _block(
                      'Event name',
                      _textField(_title, 'e.g. Neighborhood cleanup', maxLength: 100, validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.length < 3) return 'Enter at least 3 characters';
                        return null;
                      }),
                    ),
                    _block('Category', _categoryPicker()),
                    _block('When', _dateTimeRow()),
                    _block('Where', _textField(_location, 'Address or place name'), optionalNote: 'optional'),
                    _block(_isFound ? 'Who is running it?' : 'Your group or organization',
                        _textField(_org, 'e.g. Park Alliance'), optionalNote: 'optional'),
                    _block('Details',
                        _textField(_description, 'What should people know?', maxLines: 4, maxLength: 1000),
                        optionalNote: 'optional'),
                    _block(
                      'Link',
                      _textField(_link, 'https://…', maxLength: 300, keyboardType: TextInputType.url, validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return _isFound ? 'Add a link so we can verify it' : null;
                        return SubmissionService.normalizeUrl(t) == null ? 'Enter a valid web link' : null;
                      }),
                      optionalNote: _isFound ? null : 'optional',
                    ),
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Submit for review', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Events are reviewed before they appear in the feed. Please don't include personal phone numbers or home addresses. Links are only opened from the app once their site has been approved.",
                      style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted, height: 1.5),
                    ),
                    const _MySubmissions(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MySubmissions extends StatefulWidget {
  const _MySubmissions();

  @override
  State<_MySubmissions> createState() => _MySubmissionsState();
}

class _MySubmissionsState extends State<_MySubmissions> {
  // Created once so rebuilds don't restart the Firestore listener.
  late final Stream<List<MySubmission>> _stream = SubmissionService.instance.watchMine();

  /// Label, background and text color for each review status.
  (String, Color, Color) _pill(SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.pending:
        return ('Under review', AppColors.forestLight, AppColors.forest);
      case SubmissionStatus.approved:
        return ('Approved', AppColors.forest, Colors.white);
      case SubmissionStatus.rejected:
        return ('Not accepted', AppColors.ground, AppColors.inkMuted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MySubmission>>(
      stream: _stream,
      builder: (context, snap) {
        final items = snap.data ?? const <MySubmission>[];
        if (items.isEmpty) return const SizedBox.shrink();
        final loc = MaterialLocalizations.of(context);
        return Padding(
          padding: const EdgeInsets.only(top: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YOUR SUBMISSIONS',
                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.inkMuted)),
              const SizedBox(height: 10),
              for (final s in items)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                            const SizedBox(height: 3),
                            Text('Sent ${loc.formatMediumDate(s.submittedAt)}',
                                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
                          ],
                        ),
                      ),
                      Builder(builder: (context) {
                        final (label, bg, fg) = _pill(s.status);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(20),
                            border: s.status == SubmissionStatus.rejected ? Border.all(color: AppColors.border) : null,
                          ),
                          child: Text(label,
                              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
