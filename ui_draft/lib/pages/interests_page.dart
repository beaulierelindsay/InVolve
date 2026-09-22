import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../models/category.dart';

class InterestsPage extends StatefulWidget {
  const InterestsPage({super.key});

  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage> {
  final Set<String> _selected = {};
  String? _commitment;
  int _step = 1;

  static const _commitmentLevels = [
    (id: 'drop-in', label: 'Drop-in', sub: 'One-time, when I can'),
    (id: 'occasional', label: 'Occasional', sub: 'A few times a month'),
    (id: 'regular', label: 'Regular', sub: 'Weekly or ongoing'),
  ];

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        leading: _step == 2
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: AppColors.inkMid,
                onPressed: () => setState(() => _step = 1),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: AppColors.inkMid,
                onPressed: () => context.pop(),
              ),
        title: _StepIndicator(step: _step),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: _step == 1 ? _buildStep1() : _buildStep2(),
      bottomNavigationBar: _buildBottomCTA(context),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GETTING INVOLVED STARTS HERE',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: AppColors.amber,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: GoogleFonts.fraunces(fontSize: 34, fontWeight: FontWeight.w300, color: AppColors.ink, height: 1.2),
              children: const [
                TextSpan(text: 'What kind of work '),
                TextSpan(
                  text: 'calls to you?',
                  style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Pick the types of civic action you're open to. We'll surface opportunities in your area that match.",
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.inkMid, height: 1.6),
          ),
          const SizedBox(height: 24),
          ...allCategories.map((cat) => _CategoryCard(
                category: cat,
                isSelected: _selected.contains(cat.id),
                onTap: () => _toggle(cat.id),
              )),
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.forestLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppColors.forest),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selected.length} ${_selected.length == 1 ? 'type' : 'types'} selected — we\'ll find matching opportunities near you',
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.forest, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final selectedCats = allCategories.where((c) => _selected.contains(c.id)).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ONE MORE THING',
            style: GoogleFonts.outfit(
              fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: AppColors.amber,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: GoogleFonts.fraunces(fontSize: 34, fontWeight: FontWeight.w300, color: AppColors.ink, height: 1.2),
              children: const [
                TextSpan(text: 'How often can you '),
                TextSpan(
                  text: 'show up?',
                  style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "We'll match you with opportunities that fit your schedule.",
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.inkMid, height: 1.6),
          ),
          const SizedBox(height: 24),
          ..._commitmentLevels.map((level) {
            final isActive = _commitment == level.id;
            return GestureDetector(
              onTap: () => setState(() => _commitment = level.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.forestLight : AppColors.canvas,
                  border: Border.all(
                    color: isActive ? AppColors.forest : AppColors.border,
                    width: isActive ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            level.label,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isActive ? AppColors.forest : AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            level.sub,
                            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? AppColors.forest : Colors.transparent,
                        border: isActive ? null : Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: isActive
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),

          // Selected interests recap
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR SELECTED INTERESTS',
                  style: GoogleFonts.outfit(
                    fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedCats.map((cat) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: cat.lightColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat.label,
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: cat.color),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCTA(BuildContext context) {
    final canContinue = _selected.isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_step == 2) ...[
            TextButton(
              onPressed: () => setState(() => _step = 1),
              child: Text('← Back', style: GoogleFonts.outfit(color: AppColors.inkMid)),
            ),
            const SizedBox(width: 8),
          ],
          ElevatedButton(
            onPressed: _step == 1
                ? (canContinue ? () => setState(() => _step = 2) : null)
                : (_commitment != null ? () => context.go('/feed') : null),
            style: ElevatedButton.styleFrom(
              backgroundColor: _step == 1
                  ? (canContinue ? AppColors.forest : AppColors.border)
                  : (_commitment != null ? AppColors.forest : AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _step == 1
                  ? (canContinue ? 'Continue with ${_selected.length} ${_selected.length == 1 ? 'interest' : 'interests'} →' : 'Select at least one')
                  : 'Find events near me →',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: (_step == 1 ? canContinue : _commitment != null) ? Colors.white : AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final EngagementCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? category.lightColor : AppColors.canvas,
          border: Border.all(
            color: isSelected ? category.color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? []
              : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(category.icon, color: category.color, size: 22),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? category.color : Colors.transparent,
                    border: isSelected ? null : Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              category.label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? category.color : AppColors.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              category.tagline,
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 8),
            Text(
              category.description,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.inkMid, height: 1.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: category.examples.map((ex) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? category.color.withOpacity(0.1) : AppColors.ground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ex,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: isSelected ? category.color : AppColors.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(3, (i) {
          final isActive = i + 1 <= step;
          final isCurrent = i + 1 == step;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isCurrent ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: isActive ? AppColors.forest : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
        const SizedBox(width: 8),
        Text(
          'Step $step of 3',
          style: GoogleFonts.outfit(fontSize: 11, color: AppColors.inkMuted),
        ),
      ],
    );
  }
}
