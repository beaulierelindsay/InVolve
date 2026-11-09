import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../models/rsvp.dart';
import '../services/rsvp_service.dart';

/// The host's guest list for an event they host through InVolve.
/// Reached from "Your submissions" on the Add tab once the event is approved.
/// The security rules only let the host read these RSVPs.
class AttendeesPage extends StatefulWidget {
  final String eventId;
  final String title;
  const AttendeesPage({super.key, required this.eventId, required this.title});

  @override
  State<AttendeesPage> createState() => _AttendeesPageState();
}

class _AttendeesPageState extends State<AttendeesPage> {
  // Created once so rebuilds don't restart the Firestore listener.
  late final Stream<List<Attendee>> _stream = RsvpService.instance.watchAttendees(widget.eventId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        title: Text('Attendees', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w400)),
      ),
      body: StreamBuilder<List<Attendee>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Message("Couldn't load your guest list. Check your connection and try again.");
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final people = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              Text(widget.title,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(
                people.length == 1 ? '1 person is going' : '${people.length} people are going',
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 6),
              Text(
                'Use these details only for this event.',
                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 16),
              if (people.isEmpty)
                const _Message('No RSVPs yet.')
              else
                for (final p in people) _AttendeeCard(person: p),
            ],
          );
        },
      ),
    );
  }
}

class _AttendeeCard extends StatelessWidget {
  final Attendee person;
  const _AttendeeCard({required this.person});

  @override
  Widget build(BuildContext context) {
    final small = GoogleFonts.outfit(fontSize: 12, height: 1.5, color: AppColors.inkMid);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(person.name,
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 4),
          if (person.email.isNotEmpty) SelectableText(person.email, style: small),
          if (person.phone.isNotEmpty) SelectableText(person.phone, style: small),
          for (final a in person.answers) ...[
            const SizedBox(height: 8),
            Text(a.question,
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
            Text(a.answer.isEmpty ? '—' : a.answer, style: small),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  const _Message(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Text(text,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.inkMuted)),
      );
}
