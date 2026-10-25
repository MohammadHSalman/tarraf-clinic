import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../application/clinic_controller.dart';
import '../data/workspace_repository.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'luxury.dart';

Color appointmentColor(Map<String, dynamic> r) => r['type'] == 'renewal'
    ? Tk.amber
    : r['hospital'] == true
    ? Tk.plum
    : Tk.sage;

Color appointmentTint(Map<String, dynamic> r) => r['type'] == 'renewal'
    ? Tk.amberSoft
    : r['hospital'] == true
    ? Tk.plumSoft
    : Tk.sageSoft;

String appointmentKind(BuildContext c, Map<String, dynamic> r) =>
    r['type'] == 'renewal'
    ? c.tr('إعادة حقن', 'Renewal')
    : r['hospital'] == true
    ? c.tr('مشفى', 'Hospital')
    : c.tr('عيادة', 'Clinic');

/// Appointment label is stored as "patient — reason".
(String, String) splitLabel(Map<String, dynamic> r) {
  final text = '${r['label'] ?? ''}';
  final i = text.indexOf(' — ');
  return i < 0 ? (text, '') : (text.substring(0, i), text.substring(i + 3));
}

class TodayPage extends StatefulWidget {
  final void Function(int tab) onGo;
  final VoidCallback onAddPatient;
  const TodayPage({super.key, required this.onGo, required this.onAddPatient});
  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  Future<List<dynamic>>? future;
  int generation = -1;

  Future<List<dynamic>> load(ClinicController clinic) async {
    final w = WorkspaceRepository(clinic.repository);
    return [
      await clinic.patients(),
      await clinic.appointments(),
      await clinic.repository.draftCount(),
      await w.inventory(),
    ];
  }

  @override
  Widget build(BuildContext c) {
    final clinic = c.watch<ClinicController>();
    if (future == null || generation != clinic.generation) {
      generation = clinic.generation;
      future = load(clinic);
    }
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (c, s) {
        if (!s.hasData) return loadingError(s);
        final patients = s.data![0] as List<Map<String, dynamic>>,
            appointments = s.data![1] as List<Map<String, dynamic>>,
            drafts = s.data![2] as int,
            inventory = s.data![3] as List<Map<String, dynamic>>;
        final now = DateTime.now(),
            today = DateUtils.dateOnly(now),
            weekEnd = today.add(const Duration(days: 8));
        DateTime at(Map<String, dynamic> r) =>
            DateTime.parse(r['at'] as String).toLocal();
        final todays = appointments
            .where((r) => DateUtils.isSameDay(at(r), today))
            .toList();
        final upcoming = appointments
            .where((r) => at(r).isAfter(today.add(const Duration(days: 1))) &&
                at(r).isBefore(weekEnd))
            .take(5)
            .toList();
        final empty = inventory.where((m) => m['stock_milli'] == 0).length;
        final hour = now.hour;
        final greeting = hour < 12
            ? c.tr('صباح الخير', 'Good morning')
            : hour < 18
            ? c.tr('طاب يومك', 'Good afternoon')
            : c.tr('مساء الخير', 'Good evening');
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            PageIntro(
              '$greeting ${c.tr('دكتور', 'Doctor')}',
              MaterialLocalizations.of(c).formatFullDate(now),
              Icons.wb_sunny_outlined,
            ),
            if (c.clinic.needsBackup && patients.isNotEmpty)
              _BackupNotice(onTap: () => widget.onGo(4)),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                StatTile(
                  label: c.tr('مواعيد اليوم', "Today's appointments"),
                  value: '${todays.length}',
                  icon: Icons.event_available_outlined,
                  fg: Tk.sage,
                  bg: Tk.sageSoft,
                  onTap: () => widget.onGo(2),
                ),
                StatTile(
                  label: c.tr('إجمالي المرضى', 'Patients'),
                  value: '${patients.length}',
                  icon: Icons.people_alt_outlined,
                  onTap: () => widget.onGo(1),
                ),
                StatTile(
                  label: c.tr('جلسات بانتظار الاعتماد', 'Drafts to approve'),
                  value: '$drafts',
                  icon: Icons.edit_note_rounded,
                  fg: Tk.amber,
                  bg: Tk.amberSoft,
                  onTap: () => widget.onGo(1),
                ),
                StatTile(
                  label: c.tr('مواد نفد مخزونها', 'Out of stock'),
                  value: '$empty',
                  icon: Icons.inventory_2_outlined,
                  fg: empty > 0 ? Tk.rose : Tk.sage,
                  bg: empty > 0 ? Tk.roseSoft : Tk.sageSoft,
                  onTap: () => widget.onGo(4),
                ),
              ],
            ),
            SectionTitle(
              c.tr('جدول اليوم', "Today's schedule"),
              trailing: TextButton(
                onPressed: () => widget.onGo(2),
                child: Text(c.tr('التقويم', 'Calendar')),
              ),
            ),
            if (todays.isEmpty)
              GlassCard(
                flat: true,
                child: EmptyState(
                  icon: Icons.free_breakfast_outlined,
                  title: c.tr('لا مواعيد اليوم', 'No appointments today'),
                  message: c.tr(
                    'يوم هادئ. يمكنك إضافة موعد من التقويم.',
                    'A quiet day. You can add one from the calendar.',
                  ),
                ),
              )
            else
              for (final r in todays) _AppointmentRow(r, showDay: false),
            if (upcoming.isNotEmpty) ...[
              SectionTitle(c.tr('القادم هذا الأسبوع', 'Coming up this week')),
              for (final r in upcoming) _AppointmentRow(r, showDay: true),
            ],
            SectionTitle(c.tr('إجراءات سريعة', 'Quick actions')),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onAddPatient,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(c.tr('مريض جديد', 'New patient')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onGo(3),
                    icon: const Icon(Icons.insights_outlined),
                    label: Text(c.tr('التقارير', 'Reports')),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  final Map<String, dynamic> r;
  final bool showDay;
  const _AppointmentRow(this.r, {required this.showDay});
  @override
  Widget build(BuildContext c) {
    final at = DateTime.parse(r['at'] as String).toLocal();
    final (name, reason) = splitLabel(r);
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: appointmentTint(r),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  TimeOfDay.fromDateTime(at).format(c),
                  style: tjw(13.5, FontWeight.w800, color: appointmentColor(r)),
                ),
                if (showDay)
                  Text(
                    '${at.day}/${at.month}',
                    style: tjw(11.5, FontWeight.w600, color: Tk.inkSoft),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: tjw(15.5, FontWeight.w800)),
                if (reason.isNotEmpty)
                  Text(
                    reason,
                    style: tjw(13, FontWeight.w400, color: Tk.inkSoft),
                  ),
              ],
            ),
          ),
          Pill(
            appointmentKind(c, r),
            fg: appointmentColor(r),
            bg: appointmentTint(r),
          ),
        ],
      ),
    );
  }
}

class _BackupNotice extends StatelessWidget {
  final VoidCallback onTap;
  const _BackupNotice({required this.onTap});
  @override
  Widget build(BuildContext c) {
    final last = c.clinic.lastBackup;
    final days = last == null ? 0 : DateTime.now().difference(last).inDays;
    return GlassCard(
      onTap: onTap,
      color: Tk.amberSoft,
      flat: true,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Tk.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  last == null
                      ? c.tr('لا توجد نسخة احتياطية بعد', 'No backup yet')
                      : c.tr(
                          'مرّ $days يوماً على آخر نسخة احتياطية',
                          '$days days since your last backup',
                        ),
                  style: tjw(14.5, FontWeight.w800, color: const Color(0xff7A4F0F)),
                ),
                Text(
                  c.tr(
                    'البيانات على هذا الهاتف فقط. اضغط للتصدير.',
                    'Data lives only on this phone. Tap to export.',
                  ),
                  style: tjw(12.5, FontWeight.w400, color: const Color(0xff7A4F0F)),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Tk.amber),
        ],
      ),
    );
  }
}
