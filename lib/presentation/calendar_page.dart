import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../application/clinic_controller.dart';
import '../core/reminders.dart';
import 'common.dart';
import 'luxury.dart';
import '../data/workspace_repository.dart';

int notificationId(String id) =>
    id.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x3fffffff);

class CalendarPage extends StatefulWidget {
  final Reminders reminders;
  const CalendarPage({super.key, required this.reminders});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime day = DateUtils.dateOnly(DateTime.now());
  bool grid = true;
  Future<void> add() async {
    final repo = context.repo;
    final patients = await repo.patients();
    if (!mounted) return;
    final patient = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(context.tr('المريض', 'Patient')),
        children: [
          for (final p in patients)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, p),
              child: Text('${p['name']}'),
            ),
        ],
      ),
    );
    if (patient == null || !mounted) return;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    final procedures = await WorkspaceRepository(repo).procedures();
    if (!mounted || procedures.isEmpty) return;
    final data = await formDialog(
      context,
      context.tr('موعد', 'Appointment'),
      {
        'title': context.tr('السبب', 'Reason'),
        'type': context.tr(
          'clinic / hospital / renewal',
          'clinic / hospital / renewal',
        ),
        'months': context.tr(
          'تجديد بعد 4–6 أشهر (اختياري)',
          'Renew in 4–6 months (optional)',
        ),
      },
      optional: {'months'},
      initial: {'type': 'clinic', 'months': '0'},
      choices: {
        'title': {
          for (final p in procedures)
            p['name_ar'] as String:
                p[context.clinic.arabic ? 'name_ar' : 'name_en'] as String,
        },
        'type': {
          'clinic': context.tr('عيادة', 'Clinic'),
          'hospital': context.tr('مشفى', 'Hospital'),
          'renewal': context.tr('إعادة حقن', 'Renewal'),
        },
        'months': {
          '0': context.tr('بدون تأجيل', 'No postponement'),
          '4': context.tr('بعد 4 أشهر', 'After 4 months'),
          '5': context.tr('بعد 5 أشهر', 'After 5 months'),
          '6': context.tr('بعد 6 أشهر', 'After 6 months'),
        },
      },
    );
    if (data == null || !mounted) return;
    await context.guard(() async {
      if (!['clinic', 'hospital', 'renewal'].contains(data['type'])) {
        throw FormatException('clinic / hospital / renewal');
      }
      final months = data['months']!.isEmpty ? 0 : int.parse(data['months']!);
      if (months != 0 && (months < 4 || months > 6)) {
        throw FormatException('4–6');
      }
      var at = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (months > 0) {
        final target = DateTime(date.year, date.month + months, 1),
            last = DateTime(date.year, date.month + months + 1, 0).day;
        at = DateTime(
          target.year,
          target.month,
          date.day > last ? last : date.day,
          time.hour,
          time.minute,
        );
      }
      final id = await repo.document('appointments', {
        'label': '${patient['name']} — ${data['title']}',
        'at': at.toUtc().toIso8601String(),
        'hospital': data['type'] == 'hospital',
        'type': data['type'],
      }, patient: patient['patient_id'] as String);
      await widget.reminders.request();
      await widget.reminders.schedule(
        notificationId(id),
        at.subtract(const Duration(days: 1)),
      );
      await widget.reminders.schedule(
        notificationId(id) + 1,
        at.subtract(const Duration(hours: 1)),
      );
    });
  }

  Future<List<Map<String, dynamic>>> appointments() async {
    final repo = context.repo;
    final patients = await repo.patients();
    final rows = <Map<String, dynamic>>[];
    for (final p in patients) {
      rows.addAll(
        await repo.documents(
          'appointments',
          patient: p['patient_id'] as String,
        ),
      );
    }
    return rows..sort((a, b) => '${a['at']}'.compareTo('${b['at']}'));
  }

  Color color(Map<String, dynamic> r) => r['type'] == 'renewal'
      ? const Color(0xffD97706)
      : r['hospital'] == true
      ? const Color(0xff7C3AED)
      : const Color(0xff0D9488);
  @override
  Widget build(BuildContext c) {
    c.watch<ClinicController>();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: appointments(),
      builder: (c, s) {
        if (!s.hasData) return loadingError(s);
        final rows = s.data!,
            first = DateTime(day.year, day.month, 1),
            count = DateTime(day.year, day.month + 1, 0).day;
        final visible = rows.where((r) {
          final at = DateTime.parse(r['at'] as String).toLocal();
          return grid
              ? DateUtils.isSameDay(at, day)
              : at.year == day.year && at.month == day.month;
        }).toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PageIntro(
              c.tr('مواعيدك', 'Your schedule'),
              c.tr('إيقاع يومك بكل وضوح', 'Your day, beautifully organised'),
              Icons.calendar_month_outlined,
            ),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.calendar_month),
                        label: Text(c.tr('تقويم', 'Calendar')),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.view_agenda_outlined),
                        label: Text(c.tr('قائمة', 'List')),
                      ),
                    ],
                    selected: {grid},
                    onSelectionChanged: (v) {
                      tapFeedback();
                      setState(() => grid = v.first);
                    },
                  ),
                ),
                IconButton(
                  onPressed: add,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => day = DateTime(day.year, day.month - 1, 1),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${day.year} / ${day.month}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(
                    () => day = DateTime(day.year, day.month + 1, 1),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (grid)
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (final d
                            in c.clinic.arabic
                                ? ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح']
                                : ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                          Expanded(
                            child: Text(
                              d,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: silver),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: first.weekday - 1 + count,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 5,
                            crossAxisSpacing: 3,
                          ),
                      itemBuilder: (c, i) {
                        final n = i - first.weekday + 2;
                        if (n < 1) return const SizedBox.shrink();
                        final date = DateTime(day.year, day.month, n),
                            active = n == day.day;
                        final events = rows.where(
                          (r) => DateUtils.isSameDay(
                            DateTime.parse(r['at'] as String).toLocal(),
                            date,
                          ),
                        );
                        return Semantics(
                          label: '$date · ${events.length}',
                          button: true,
                          selected: active,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              tapFeedback();
                              setState(() => day = date);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: active ? navy : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$n',
                                    style: TextStyle(
                                      color: active ? Colors.white : navy,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 2,
                                    children: [
                                      for (final type
                                          in events.map(color).toSet())
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: type,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 12,
              children: [
                for (final item in [
                  (const Color(0xff0D9488), c.tr('عيادة', 'Clinic')),
                  (const Color(0xff7C3AED), c.tr('مشفى', 'Hospital')),
                  (const Color(0xffD97706), c.tr('إعادة حقن', 'Renewal')),
                ])
                  Chip(
                    avatar: Icon(Icons.circle, color: item.$1, size: 10),
                    label: Text(item.$2),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    c.tr(
                      'لا مواعيد في الفترة المحددة',
                      'No appointments in this period',
                    ),
                  ),
                ),
              ),
            for (final r in visible)
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 5,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color(r),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  title: Text(
                    '${r['label']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(clinicalDate(c, r['at'] as String)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => c.guard(() async {
                      final repo = c.repo;
                      await widget.reminders.cancel(
                        notificationId(r['id'] as String),
                      );
                      await widget.reminders.cancel(
                        notificationId(r['id'] as String) + 1,
                      );
                      await repo.removeDocument(r['id'] as String);
                    }),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
