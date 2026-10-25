import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const navy = Color(0xff1E293B),
    silver = Color(0xff94A3B8),
    coral = Color(0xffEF4444);
void tapFeedback() => HapticFeedback.selectionClick();

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });
  @override
  Widget build(BuildContext c) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x091E293B),
          blurRadius: 28,
          offset: Offset(0, 12),
        ),
        BoxShadow(
          color: Color(0x061E293B),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xf5FFFFFF), Color(0xcceef2f6)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: .9)),
          ),
          child: child,
        ),
      ),
    ),
  );
}

class MedicalAlert extends StatelessWidget {
  final Map<String, dynamic> patient;
  const MedicalAlert(this.patient, {super.key});
  @override
  Widget build(BuildContext c) {
    final text = '${patient['allergies'] ?? ''} ${patient['critical'] ?? ''}'
        .trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      label: 'تنبيه طبي: $text',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: coral.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: coral.withValues(alpha: .3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.health_and_safety_outlined, color: coral),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xffB91C1C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PageIntro extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  const PageIntro(this.title, this.subtitle, this.icon, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xff64748B), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
