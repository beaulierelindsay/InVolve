import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../models/events.dart';
import '../services/saved_events_store.dart';
import '../widgets/save_button.dart';

class SavedPage extends StatelessWidget {
  const SavedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('YOUR LIST', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: AppColors.amber)),
            RichText(
              text: TextSpan(
                style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w300, color: AppColors.ink),
                children: const [
                  TextSpan(text: 'Saved '),
                  TextSpan(text: 'events', style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Divider(height: 1, color: AppColors.border)),
      ),
      body: ListenableBuilder(
        listenable: SavedEventsStore.instance,
        builder: (context, _) {
          final events = SavedEventsStore.instance.events;
          if (events.isEmpty) return const _EmptyState();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _SavedCard(event: events[i]),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: AppColors.forestLight, borderRadius: BorderRadius.circular(18)),
            child: Icon(Icons.bookmark_outline, size: 26, color: AppColors.forest),
          ),
          const SizedBox(height: 16),
          Text('Nothing saved yet', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 6),
          Text(
            'Bookmark events from your feed to find them here.',
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.inkMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  final Event event;
  const _SavedCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final category = event.category;
    final where = event.distance ?? event.location ?? '';

    return GestureDetector(
      onTap: () => context.push('/feed/event', extra: event),
      behavior: HitTestBehavior.opaque,
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: category.lightColor, borderRadius: BorderRadius.circular(20)),
                  child: Text(category.shortLabel,
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: category.color)),
                ),
                const Spacer(),
                SaveButton(event: event), // tap again to remove from Saved
              ],
            ),
            const SizedBox(height: 10),
            Text(event.title,
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 3),
            Text(event.org, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.inkMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(event.date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
                ),
                if (where.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.location_on_outlined, size: 12, color: AppColors.inkMuted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(where,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
