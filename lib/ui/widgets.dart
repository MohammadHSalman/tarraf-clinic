import 'package:flutter/material.dart';
import '../presentation/common.dart';
import 'tokens.dart';

/// Small rounded label (status, category, count).
class Pill extends StatelessWidget {
  final String label;
  final Color fg, bg;
  final IconData? icon;
  const Pill(
    this.label, {
    super.key,
    this.fg = Tk.ink,
    this.bg = Tk.surfaceAlt,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: tjw(12, FontWeight.w700, color: fg),
          ),
        ),
      ],
    ),
  );
}

/// Session status → localized, color-coded pill.
class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext c) {
    final (fg, bg, icon) = switch (status) {
      'draft' => (Tk.amber, Tk.amberSoft, Icons.edit_note_rounded),
      'final' => (Tk.sage, Tk.sageSoft, Icons.verified_outlined),
      'cancelled' => (Tk.rose, Tk.roseSoft, Icons.block_rounded),
      _ => (Tk.inkSoft, Tk.surfaceAlt, Icons.history_rounded),
    };
    return Pill(statusLabel(c, status), fg: fg, bg: bg, icon: icon);
  }
}

class PersonAvatar extends StatelessWidget {
  final String name;
  final double size;
  const PersonAvatar(this.name, {super.key, this.size = 48});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Tk.ink, Color(0xff31406A)],
      ),
    ),
    child: Text(
      initialOf(name),
      style: tjw(size * .42, FontWeight.w800, color: const Color(0xffEBDDBE)),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message = '',
    this.action,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: Tk.goldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: Tk.goldDeep),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: tjw(18, FontWeight.w800),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tjw(14, FontWeight.w400, color: Tk.inkSoft, height: 1.5),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
    child: Row(
      children: [
        Expanded(child: Text(text, style: tjw(17, FontWeight.w800))),
        ?trailing,
      ],
    ),
  );
}

/// Compact metric tile: tinted icon, big value, small caption.
class StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color fg, bg;
  final VoidCallback? onTap;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.fg = Tk.goldDeep,
    this.bg = Tk.goldSoft,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Tk.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Tk.r),
      side: const BorderSide(color: Tk.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: fg),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value, style: tjw(22, FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tjw(12.5, FontWeight.w500, color: Tk.inkSoft),
            ),
          ],
        ),
      ),
    ),
  );
}
