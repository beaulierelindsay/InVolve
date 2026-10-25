import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../models/events.dart';

/// Full-screen details for one event. Reached from the feed with:
///   context.push('/feed/event', extra: event);
class EventDetailsPage extends StatelessWidget {
  final Event? event;
  const EventDetailsPage({super.key, required this.event});

  static void _goBack(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/feed');

  static Future<void> _openOfficialSite(BuildContext context, String url) async {
    var opened = false;
    try {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the official site.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = event;
    if (e == null) return const _NotFound();

    final color = e.category.color;
    final url = e.url;

    return Scaffold(
      backgroundColor: AppColors.ground,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(event: e),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _InfoCard(label: 'When', value: e.date, sub: e.duration)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoCard(
                              label: 'Where',
                              value: e.location ?? 'Location to be announced',
                              sub: e.distance == null ? null : '${e.distance} away',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SummaryCard(text: e.description),
                    const SizedBox(height: 20),
                    if (e.agenda.isNotEmpty)
                      _AgendaCard(items: e.agenda, color: color)
                    else if (url != null)
                      const _Note('The full agenda, including items up for discussion, is available on the official site.'),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Details may change. Confirm the latest time, location, eligibility, and registration with the organizer.',
                        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (url != null)
                      ElevatedButton(
                        onPressed: () => _openOfficialSite(context, url),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Continue on official site',
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            const Icon(Icons.open_in_new, size: 16),
                          ],
                        ),
                      )
                    else
                      const _Note('No official page is available for this event yet.'),
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

// ─── Pieces ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Event event;
  const _Header({required this.event});

  @override
  Widget build(BuildContext context) {
    final category = event.category;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => EventDetailsPage._goBack(context),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_left, size: 22, color: AppColors.inkMid),
                  const SizedBox(width: 2),
                  Text('Back',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.inkMid)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: category.lightColor, borderRadius: BorderRadius.circular(20)),
                child: Text(category.shortLabel,
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: category.color)),
              ),
              const Spacer(),
              if (event.spots != null)
                Text('${event.spots} spots left',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.inkMuted)),
            ],
          ),
          const SizedBox(height: 16),
          Text(event.title,
              style: GoogleFonts.fraunces(fontSize: 30, fontWeight: FontWeight.w400, height: 1.2, color: AppColors.ink)),
          const SizedBox(height: 8),
          Text(event.org, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    );

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  const _InfoCard({required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 1.2, color: AppColors.inkMuted)),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, height: 1.35, color: AppColors.ink)),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.inkMuted)),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String text;
  const _SummaryCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.amber, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('SUMMARY',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.amber)),
            ],
          ),
          const SizedBox(height: 12),
          Text(text, style: GoogleFonts.outfit(fontSize: 14, height: 1.6, color: AppColors.inkMid)),
        ],
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  final List<AgendaItem> items;
  final Color color;
  const _AgendaCard({required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Text('What to expect',
                style: GoogleFonts.fraunces(fontSize: 21, fontWeight: FontWeight.w400, color: AppColors.ink)),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  _AgendaRow(item: items[i], color: color, isLast: i == items.length - 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  final AgendaItem item;
  final Color color;
  final bool isLast;
  const _AgendaRow({required this.item, required this.color, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 72,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(item.time,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
            ),
          ),
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                if (!isLast) Expanded(child: Container(width: 1, color: AppColors.border)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 6, bottom: isLast ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 4),
                  Text(item.detail,
                      style: GoogleFonts.outfit(fontSize: 12, height: 1.5, color: AppColors.inkMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Text(text, style: GoogleFonts.outfit(fontSize: 12, height: 1.5, color: AppColors.inkMuted)),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("We couldn't find that event.",
                  style: GoogleFonts.outfit(fontSize: 14, color: AppColors.inkMid)),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => context.go('/feed'),
                child: Text('Return to your feed',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.forest)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
