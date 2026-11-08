import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';

/// Websites InVolve is willing to send users to. A link is allowed only if its
/// host is one of these domains or a subdomain of one (e.g. nyc.legistar.com).
///
/// Add a domain here when a new event source is added. Event links from any
/// other site are treated as unsafe and are not shown.
const _trustedDomains = <String>{
  'legistar.com', // NYC Council meetings (seen as nyc.legistar.com)
  'mobilize.us', // cause-action events
  // TODO(team): add the real domains for the remaining sources, for example
  // the ticketing source and the NYC open-data / parks sources.
};

class LinkSafety {
  const LinkSafety._();

  /// Returns a link that is safe to open, or null if it should be rejected.
  static Uri? parse(String? raw) {
    if (raw == null) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;

    // https only: blocks http, javascript:, intent:, file:, tel:, sms:, and
    // custom app schemes.
    if (uri.scheme != 'https') return null;

    if (uri.host.isEmpty) return null;

    // Blocks tricks like https://nyc.legistar.com@evil.example/
    if (uri.userInfo.isNotEmpty) return null;

    // Allowlist: also defeats lookalike domains such as legistar.com.evil.example
    if (!_isTrusted(uri.host)) return null;

    return uri;
  }

  static bool _isTrusted(String host) {
    final h = host.toLowerCase();
    return _trustedDomains.any((d) => h == d || h.endsWith('.$d'));
  }

  /// Validates the link, tells the user which site they're about to visit,
  /// and opens it in the system browser only if they agree.
  static Future<void> open(BuildContext context, String? raw) async {
    final uri = parse(raw);
    if (uri == null) {
      _toast(context, "This link can't be opened safely.");
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Leave InVolve?',
            style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w400, color: AppColors.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "You're about to open an external website. InVolve doesn't control its content.",
              style: GoogleFonts.outfit(fontSize: 13, height: 1.5, color: AppColors.inkMid),
            ),
            const SizedBox(height: 14),
            Text(uri.host,
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.inkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Continue',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.forest)),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;

    var opened = false;
    try {
      // The system browser shows the full address bar and its own phishing
      // protection. The app never runs scripts from the site.
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) _toast(context, "Couldn't open the website.");
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
