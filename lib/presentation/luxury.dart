import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ui/tokens.dart';

// Legacy names kept so existing screens pick up the new palette.
const navy = Tk.ink, silver = Tk.inkFaint, coral = Tk.rose;
void tapFeedback() => HapticFeedback.selectionClick();

/// Surface card. (Name kept for compatibility; no blur, clean surface.)
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool flat;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.flat = false,
  });
  @override
  Widget build(BuildContext c) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: color ?? Tk.surface,
      borderRadius: BorderRadius.circular(Tk.r),
      border: Border.all(color: Tk.line),
      boxShadow: flat ? null : Tk.shadow,
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Tk.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
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
    final arabic = Localizations.localeOf(c).languageCode == 'ar';
    return Semantics(
      liveRegion: true,
      label: '${arabic ? 'تنبيه طبي' : 'Medical alert'}: $text',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Tk.roseSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Tk.rose.withValues(alpha: .25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Tk.rose.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.health_and_safety_outlined,
                color: Tk.rose,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    arabic ? 'تنبيه طبي' : 'Medical alert',
                    style: tjw(12, FontWeight.w800, color: Tk.rose),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: tjw(
                      14.5,
                      FontWeight.w700,
                      color: const Color(0xff8E2F28),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page heading with a soft gold icon medallion.
class PageIntro extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  const PageIntro(this.title, this.subtitle, this.icon, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: tjw(26, FontWeight.w800, height: 1.2)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: tjw(13.5, FontWeight.w400, color: Tk.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Tk.goldSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Tk.goldDeep, size: 24),
        ),
      ],
    ),
  );
}
