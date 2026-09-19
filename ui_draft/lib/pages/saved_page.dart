import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

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
      body: Center(
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
      ),
    );
  }
}
