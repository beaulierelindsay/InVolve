import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/events.dart';
import '../services/saved_events_store.dart';

/// Bookmark icon for an event. Reads and updates [SavedEventsStore] itself,
/// so it can be dropped into any card or page with no extra state.
class SaveButton extends StatelessWidget {
  final Event event;
  final double size;
  const SaveButton({super.key, required this.event, this.size = 20});

  @override
  Widget build(BuildContext context) {
    final store = SavedEventsStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final saved = store.isSaved(event.id);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => store.toggle(event),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              saved ? Icons.bookmark : Icons.bookmark_outline,
              size: size,
              color: saved ? event.category.color : AppColors.inkMuted,
            ),
          ),
        );
      },
    );
  }
}
