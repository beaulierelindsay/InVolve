import 'package:flutter/material.dart';
import '../models/category.dart';

// Low-fidelity wireframe sketches for every screen in the app.
// Ported from the React/SVG version: same 220x440 canvas and shape helpers.

const double _frameW = 220;
const double _frameH = 440;

const _stroke = Color(0xFF94A3B8);
const _strokeLight = Color(0xFFCBD5E1);
const _fill = Color(0xFFE2E8F0);
const _fillDark = Color(0xFFCBD5E1);
const _fillMid = Color(0xFFEFF3F8);
const _text = Color(0xFF475569);
const _textLight = Color(0xFF94A3B8);
const _accent = Color(0xFF1E3A5F);
const _accentLight = Color(0xFFDBEAFE);

// ─── Drawing helpers (Dart equivalents of Box, TextLine, XBox, ...) ─────────

class _Wire {
  final Canvas c;
  _Wire(this.c);

  void rect(double x, double y, double w, double h,
      {Color fill = _fill, double rx = 3, Color? stroke, double sw = 0.8}) {
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rx));
    c.drawRRect(r, Paint()..color = fill);
    if (stroke != null) {
      c.drawRRect(r, Paint()..color = stroke..style = PaintingStyle.stroke..strokeWidth = sw);
    }
  }

  void box(double x, double y, double w, double h, {Color fill = _fill, double rx = 3}) =>
      rect(x, y, w, h, fill: fill, rx: rx, stroke: _stroke);

  void line(double x1, double y1, double x2, double y2, {Color color = _stroke, double sw = 0.7}) =>
      c.drawLine(Offset(x1, y1), Offset(x2, y2), Paint()..color = color..strokeWidth = sw);

  void bar(double x, double y, double w, {double h = 5, Color fill = _fillDark}) =>
      rect(x, y, w, h, fill: fill, rx: 2);

  void xbox(double x, double y, double w, double h, {double rx = 3}) {
    box(x, y, w, h, rx: rx);
    line(x, y, x + w, y + h);
    line(x + w, y, x, y + h);
  }

  void circle(double cx, double cy, double r, {Color fill = _fill, Color? stroke, double opacity = 1}) {
    c.drawCircle(Offset(cx, cy), r, Paint()..color = fill.withValues(alpha: opacity));
    if (stroke != null) {
      c.drawCircle(Offset(cx, cy), r, Paint()..color = stroke..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }
  }

  /// [y] is the text baseline, matching SVG <text> behavior.
  void text(String t, double x, double y,
      {double size = 7, Color color = _text, FontWeight weight = FontWeight.normal,
      TextAlign align = TextAlign.center, double spacing = 0}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: size, color: color, fontWeight: weight, letterSpacing: spacing)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == TextAlign.center ? x - tp.width / 2 : (align == TextAlign.end ? x - tp.width : x);
    tp.paint(c, Offset(dx, y - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
  }

  void header(String label, {String? sub, double y = 20}) {
    final h = sub != null ? 46.0 : 36.0;
    rect(0, y, _frameW, h, fill: Colors.white, rx: 0);
    line(0, y + h, _frameW, y + h, color: _strokeLight, sw: 0.8);
    if (sub != null) {
      text(sub.toUpperCase(), 16, y + 14, size: 6, color: _textLight, align: TextAlign.start, spacing: 1);
    }
    text(label, 16, y + (sub != null ? 29 : 22),
        size: sub != null ? 11 : 10, color: _accent, weight: FontWeight.w600, align: TextAlign.start);
  }

  void bottomNav([double y = 390]) {
    const tabs = ['Feed', 'Explore', 'Vol.', 'Saved', 'You'];
    final tw = _frameW / tabs.length;
    rect(0, y, _frameW, _frameH - y, fill: Colors.white, rx: 0, stroke: _stroke, sw: 0.5);
    line(0, y, _frameW, y, color: _strokeLight, sw: 1);
    for (var i = 0; i < tabs.length; i++) {
      rect(i * tw + tw / 2 - 7, y + 6, 14, 14, fill: _fillMid, rx: 3);
      text(tabs[i], i * tw + tw / 2, y + 30, size: 5.5, color: _textLight);
    }
  }
}

class _ScreenPainter extends CustomPainter {
  final void Function(_Wire w) draw;
  const _ScreenPainter(this.draw);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF0F4F8));
    draw(_Wire(canvas));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Screens ────────────────────────────────────────────────────────────────

void _welcome(_Wire w) {
  w.rect(72, 56, 76, 24, fill: _accent, rx: 4);
  w.text('InVolve', 110, 72, size: 8, color: Colors.white, weight: FontWeight.w700);
  w.bar(28, 96, 164, h: 9);
  w.bar(48, 109, 124, h: 7);
  w.bar(60, 120, 100, h: 7);
  w.text('Your neighborhood', 16, 152, color: _textLight, align: TextAlign.start);
  w.box(16, 156, 188, 28, fill: Colors.white, rx: 6);
  w.bar(28, 166, 80, fill: _strokeLight);
  w.rect(184, 164, 12, 12, fill: _fillDark, rx: 2);
  w.xbox(16, 196, 188, 110, rx: 6);
  w.text('Map preview', 110, 256, size: 8, color: _textLight);
  w.rect(16, 316, 188, 32, fill: _accent, rx: 8);
  w.text('Set my interests →', 110, 336, size: 9, color: Colors.white, weight: FontWeight.w600);
  w.text('Skip for now', 110, 366, color: _textLight);
}

void _interestsStep1(_Wire w) {
  w.rect(16, 30, 188, 3, fill: _fill, rx: 2);
  w.rect(16, 30, 94, 3, fill: _accent, rx: 2);
  w.text('STEP 1 OF 2', 16, 48, size: 6, color: _textLight, align: TextAlign.start, spacing: 1);
  w.bar(16, 54, 150, h: 9);
  w.bar(16, 68, 120, h: 5);
  for (var i = 0; i < allCategories.length; i++) {
    final c = allCategories[i];
    final y = 84.0 + i * 46;
    final on = i < 3; // sample: first three selected
    w.rect(16, y, 188, 40, fill: on ? c.lightColor : Colors.white, rx: 8, stroke: on ? c.color : _stroke, sw: on ? 1.2 : 0.8);
    w.rect(24, y + 8, 24, 24, fill: c.color.withValues(alpha: 0.2), rx: 6);
    w.text(c.shortLabel, 56, y + 19, size: 7.5, weight: FontWeight.w600, align: TextAlign.start);
    w.bar(56, y + 25, 100, h: 4, fill: _strokeLight);
    if (on) {
      w.circle(190, y + 20, 6, fill: c.color);
      w.text('✓', 190, y + 23, size: 7, color: Colors.white);
    } else {
      w.circle(190, y + 20, 6, fill: Colors.white, stroke: _stroke);
    }
  }
  w.rect(16, 368, 188, 30, fill: _accent, rx: 8);
  w.text('Continue with 3 selected', 110, 387, size: 8, color: Colors.white, weight: FontWeight.w600);
}

void _interestsStep2(_Wire w) {
  w.rect(16, 30, 188, 3, fill: _accent, rx: 2);
  w.text('STEP 2 OF 2', 16, 48, size: 6, color: _textLight, align: TextAlign.start, spacing: 1);
  w.bar(16, 54, 150, h: 9);
  w.bar(16, 68, 130, h: 5);
  const options = [
    ('Drop-in', 'One-time, when I can'),
    ('Occasional', 'A few times a month'),
    ('Regular', 'Weekly or ongoing'),
  ];
  for (var i = 0; i < options.length; i++) {
    final y = 92.0 + i * 52;
    final on = i == 1; // sample selection
    w.rect(16, y, 188, 44, fill: on ? _accentLight : Colors.white, rx: 8, stroke: on ? _accent : _stroke, sw: on ? 1.2 : 0.8);
    w.text(options[i].$1, 28, y + 18, size: 8, weight: FontWeight.w600, align: TextAlign.start);
    w.text(options[i].$2, 28, y + 31, size: 6, color: _textLight, align: TextAlign.start);
    w.circle(188, y + 22, 6, fill: on ? _accent : Colors.white, stroke: on ? _accent : _stroke);
  }
  w.rect(16, 256, 188, 56, fill: Colors.white, rx: 8, stroke: _strokeLight);
  w.text('YOUR SELECTED INTERESTS', 24, 270, size: 5.5, color: _textLight, align: TextAlign.start, weight: FontWeight.w600);
  for (var i = 0; i < 3; i++) {
    final c = allCategories[i];
    w.rect(24 + i * 58.0, 280, 52, 14, fill: c.lightColor, rx: 7);
    w.text(c.shortLabel, 24 + i * 58.0 + 26, 290, size: 5.5, color: c.color, weight: FontWeight.w600);
  }
  w.text('← Back', 16, 388, size: 7, color: _textLight, align: TextAlign.start);
  w.rect(96, 372, 108, 28, fill: _accent, rx: 8);
  w.text('Find events near me →', 150, 389, size: 7, color: Colors.white, weight: FontWeight.w600);
}

void _feed(_Wire w) {
  w.header("What's happening near you", sub: 'Brooklyn, NY');
  w.box(172, 30, 26, 26, fill: _fillMid, rx: 8);
  w.rect(180, 38, 10, 10, fill: _fillDark, rx: 5);
  // filter chips (last one is clipped to suggest horizontal scrolling)
  const chips = [('For you', 54.0), ('All', 36.0), ('Civic', 44.0), ('Volunteer', 54.0)];
  var cx = 16.0;
  for (var i = 0; i < chips.length; i++) {
    final on = i == 0;
    w.rect(cx, 74, chips[i].$2, 16, fill: on ? _accent : Colors.white, rx: 8, stroke: on ? _accent : _stroke, sw: 0.7);
    w.text(chips[i].$1, cx + chips[i].$2 / 2, 85, size: 6.5, color: on ? Colors.white : _text);
    cx += chips[i].$2 + 8;
  }
  for (var i = 0; i < 3; i++) {
    final c = allCategories[i];
    final y = 100.0 + i * 95;
    w.rect(16, y, 188, 88, fill: Colors.white, rx: 10, stroke: _strokeLight);
    final bw = 16 + c.shortLabel.length * 3.8;
    w.rect(24, y + 8, bw, 11, fill: c.lightColor, rx: 6);
    w.text(c.shortLabel, 24 + bw / 2, y + 16, size: 6, color: c.color, weight: FontWeight.w600);
    w.rect(184, y + 8, 10, 12, fill: _fillDark, rx: 2);
    w.bar(24, y + 26, 130, h: 7);
    w.bar(24, y + 38, 80, h: 4, fill: _strokeLight);
    w.bar(24, y + 47, 150, h: 4, fill: _strokeLight);
    w.bar(24, y + 54, 120, h: 4, fill: _strokeLight);
    w.rect(24, y + 70, 8, 8, fill: _fillDark, rx: 2);
    w.bar(36, y + 71, 56, fill: _strokeLight);
    w.rect(100, y + 70, 8, 8, fill: _fillDark, rx: 2);
    w.bar(112, y + 71, 24, fill: _strokeLight);
    w.rect(150, y + 66, 46, 16, fill: c.color, rx: 5);
    w.text('RSVP', 173, y + 77, size: 6, color: Colors.white, weight: FontWeight.w600);
  }
  w.bottomNav();
}

void _explore(_Wire w) {
  w.header('Explore the map', sub: 'Brooklyn, NY');
  w.xbox(0, 66, _frameW, 220, rx: 0);
  for (final p in const [(60.0, 130.0), (110.0, 150.0), (150.0, 120.0), (80.0, 210.0)]) {
    w.circle(p.$1, p.$2, 6, fill: _accent, opacity: 0.85);
    w.circle(p.$1, p.$2, 3, fill: Colors.white);
  }
  w.text('Interactive map', 110, 180, size: 9, color: _textLight);
  w.rect(50, 76, 120, 18, fill: Colors.white, rx: 9, stroke: _strokeLight);
  w.circle(62, 85, 3, fill: const Color(0xFFC9631A));
  w.text('12 events in this area', 70, 88, size: 6.5, color: _text, align: TextAlign.start);
  w.rect(0, 286, _frameW, 104, fill: Colors.white, rx: 0, stroke: _strokeLight, sw: 0.5);
  w.rect(88, 290, 44, 3, fill: _fillDark, rx: 2);
  w.text('3 events nearby', 16, 305, color: _text, align: TextAlign.start, weight: FontWeight.w600);
  for (var i = 0; i < 2; i++) {
    w.bar(16, 312.0 + i * 34, 130, h: 7);
    w.bar(16, 323.0 + i * 34, 80);
    w.xbox(176, 311.0 + i * 34, 24, 24);
  }
  w.bottomNav();
}

void _volunteer(_Wire w) {
  w.header('Volunteer shifts', sub: 'Open near you');
  const spots = ['4', '2', '18'];
  for (var i = 0; i < 3; i++) {
    final c = allCategories[[1, 4, 2][i]]; // sample colors from the category model
    final y = 74.0 + i * 100;
    w.rect(16, y, 188, 92, fill: Colors.white, rx: 8, stroke: _strokeLight);
    w.rect(24, y + 8, 46, 13, fill: c.lightColor, rx: 7);
    w.text('${spots[i]} spots left', 47, y + 17, size: 6, color: c.color, weight: FontWeight.w600);
    w.bar(24, y + 26, 130, h: 7);
    w.bar(24, y + 38, 90);
    w.bar(24, y + 48, 110);
    w.rect(24, y + 62, 50, 16, fill: c.color, rx: 5);
    w.text('Sign up', 49, y + 73, size: 6.5, color: Colors.white, weight: FontWeight.w600);
  }
  w.bottomNav();
}

void _saved(_Wire w) {
  w.header('Saved events', sub: 'Your list');
  w.rect(86, 168, 48, 48, fill: _fill, rx: 10, stroke: _strokeLight);
  w.line(104, 178, 104, 206, sw: 1.5);
  w.line(96, 186, 124, 198, sw: 1.5);
  w.text('Nothing saved yet', 110, 234, size: 9, weight: FontWeight.w600);
  w.bar(56, 242, 108, fill: _strokeLight);
  w.bar(68, 251, 84, fill: _strokeLight);
  w.rect(56, 268, 108, 26, fill: _accent, rx: 8);
  w.text('Browse events', 110, 285, size: 8, color: Colors.white, weight: FontWeight.w600);
  w.bottomNav();
}

void _profile(_Wire w) {
  w.rect(0, 20, _frameW, 66, fill: Colors.white, rx: 0);
  w.line(0, 86, _frameW, 86, color: _strokeLight, sw: 0.8);
  w.circle(42, 53, 20, fill: _accent);
  w.text('J', 42, 57, size: 12, color: Colors.white, weight: FontWeight.w700);
  w.bar(72, 40, 80, h: 8);
  w.bar(72, 53, 110);
  w.bar(72, 62, 80);
  const stats = [('3', 'Events'), ('1', 'Shifts'), ('2', 'Actions')];
  for (var i = 0; i < 3; i++) {
    final bx = 16.0 + i * 66;
    w.rect(bx, 96, 56, 40, fill: Colors.white, rx: 6, stroke: _strokeLight);
    w.text(stats[i].$1, bx + 28, 117, size: 14, color: _accent, weight: FontWeight.w700);
    w.text(stats[i].$2, bx + 28, 129, size: 5.5, color: _textLight);
  }
  w.rect(16, 146, 188, 72, fill: Colors.white, rx: 8, stroke: _strokeLight);
  w.text('MY INTERESTS', 24, 160, size: 5.5, color: _textLight, align: TextAlign.start, weight: FontWeight.w600);
  w.text('Edit', 196, 160, size: 6.5, color: _accent, align: TextAlign.end);
  for (var i = 0; i < 3; i++) {
    final c = allCategories[i];
    w.rect(24 + i * 58.0, 168, 52, 14, fill: c.lightColor, rx: 7);
    w.text(c.shortLabel, 24 + i * 58.0 + 26, 178, size: 5.5, color: c.color, weight: FontWeight.w600);
  }
  w.rect(16, 228, 188, 36, fill: Colors.white, rx: 8, stroke: _strokeLight);
  w.text('LOCATION', 24, 242, size: 5.5, color: _textLight, align: TextAlign.start, weight: FontWeight.w600);
  w.bar(24, 248, 100, h: 7);
  w.text('Change', 196, 252, size: 6.5, color: _accent, align: TextAlign.end);
  w.rect(16, 276, 188, 28, fill: Colors.white, rx: 8, stroke: _strokeLight);
  w.text('Sign out', 110, 294, size: 8, color: _textLight);
  w.bottomNav();
}

// ─── Page layout ────────────────────────────────────────────────────────────

class _Screen {
  final String label;
  final String route;
  final void Function(_Wire) draw;
  const _Screen(this.label, this.route, this.draw);
}

final _screens = <_Screen>[
  _Screen('Welcome', '/welcome', _welcome),
  _Screen('Interests · Step 1', '/interests', _interestsStep1),
  _Screen('Interests · Step 2', '/interests', _interestsStep2),
  _Screen('Feed', '/feed', _feed),
  _Screen('Explore', '/explore', _explore),
  _Screen('Volunteer', '/volunteer', _volunteer),
  _Screen('Saved', '/saved', _saved),
  _Screen('Profile', '/profile', _profile),
];

class WireframesPage extends StatelessWidget {
  const WireframesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(40, 56, 40, 24),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E293B)))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text('App Wireframes',
                          style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 16),
                      Text('${_screens.length} screens',
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Low-fidelity structural overview · not linked to live routes',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 52, 48, 80),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 48,
                  runSpacing: 48,
                  children: [for (final s in _screens) _PhoneFrame(screen: s)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  final _Screen screen;
  const _PhoneFrame({required this.screen});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _frameW,
          height: _frameH,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF334155), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 32, offset: const Offset(0, 8)),
            ],
          ),
          child: Stack(
            children: [
              CustomPaint(size: const Size(_frameW, _frameH), painter: _ScreenPainter(screen.draw)),
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 52,
                    height: 6,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(screen.label,
            style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(screen.route,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontFamily: 'monospace')),
      ],
    );
  }
}