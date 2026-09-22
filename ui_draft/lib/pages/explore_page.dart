import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.canvas,
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BROOKLYN, NY',
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: AppColors.amber)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w300, color: AppColors.ink),
                    children: const [
                      TextSpan(text: 'Explore the '),
                      TextSpan(text: 'map', style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
                Divider(height: 20, color: AppColors.border),
              ],
            ),
          ),

          // Map area
          Expanded(
            child: Stack(
              children: [
                // Map placeholder
                Container(
                  color: AppColors.forestLight,
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size.infinite,
                        painter: _ExploreMapPainter(),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: AppColors.forest,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [BoxShadow(color: AppColors.forest.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                              ),
                              child: const Icon(Icons.location_on, color: Colors.white, size: 32),
                            ),
                            const SizedBox(height: 14),
                            Text('Live map coming soon',
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.forest)),
                            const SizedBox(height: 6),
                            Text(
                              'Add google_maps_flutter to pubspec\nand configure your API key',
                              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted, height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating chip
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.canvas,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.amber, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text('12 events in this area',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.ink)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1B4D3E).withOpacity(0.1)
      ..strokeWidth = 1;

    for (int i = 0; i < 12; i++) {
      final y = i * size.height / 11;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (int i = 0; i < 16; i++) {
      final x = i * size.width / 15;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final blockPaint = Paint()..color = const Color(0xFF1B4D3E).withOpacity(0.15);
    final rr = const Radius.circular(6);
    canvas.drawRRect(RRect.fromLTRBR(30, 40, 140, 110, rr), blockPaint);
    canvas.drawRRect(RRect.fromLTRBR(160, 30, 280, 80, rr), blockPaint..color = const Color(0xFF1B4D3E).withOpacity(0.10));
    canvas.drawRRect(RRect.fromLTRBR(300, 50, 420, 130, rr), blockPaint..color = const Color(0xFF1B4D3E).withOpacity(0.13));
    canvas.drawRRect(RRect.fromLTRBR(30, 130, 100, 240, rr), blockPaint..color = const Color(0xFF1B4D3E).withOpacity(0.11));
    canvas.drawRRect(RRect.fromLTRBR(120, 100, 270, 180, rr), blockPaint..color = const Color(0xFF1B4D3E).withOpacity(0.08));
    canvas.drawRRect(RRect.fromLTRBR(290, 150, 390, 210, rr), blockPaint..color = const Color(0xFF1B4D3E).withOpacity(0.12));

    final roadPaint = Paint()
      ..color = const Color(0xFF2D6A55).withOpacity(0.3)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height * 0.55), Offset(size.width, size.height * 0.55), roadPaint);
    canvas.drawLine(Offset(size.width * 0.45, 0), Offset(size.width * 0.45, size.height), roadPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}