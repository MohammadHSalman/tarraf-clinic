import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../application/clinic_controller.dart';
import '../domain/models.dart';
import '../data/workspace_repository.dart';
import '../domain/fx.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'luxury.dart';
import 'common.dart';
import 'injection_map.dart';
import 'patient_assets.dart';

class PatientPage extends StatefulWidget {
  final Map<String, dynamic> patient;
  const PatientPage({super.key, required this.patient});
  @override
  State<PatientPage> createState() => _PatientPageState();
}

class _PatientPageState extends State<PatientPage> {
  String? selected;
  String get pid => widget.patient['patient_id'] as String;
  Future<void> newSession() async {
    final procedures = await WorkspaceRepository(context.repo).procedures();
    if (!mounted) return;
    if (procedures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف إجراء من الإعدادات أولاً')),
      );
      return;
    }
    final data = await formDialog(
      context,
      context.tr('جلسة جديدة', 'New session'),
      {
        'procedure': context.tr('الإجراء', 'Procedure'),
        'notes': context.tr('ملاحظات سريرية', 'Clinical notes'),
      },
      optional: {'notes'},
      choices: {
        'procedure': {
          for (final p in procedures)
            p['procedure_id'] as String:
                '${p[context.clinic.arabic ? 'name_ar' : 'name_en']} · ${p['category']}',
        },
      },
    );
    if (data == null || !mounted) return;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    final diagram = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(context.tr('نوع الخريطة', 'Map type')),
        children: [
          for (final value in ['face', 'body'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, value),
              child: Text(
                value == 'face'
                    ? context.tr('الوجه', 'Face')
                    : context.tr('الجسم', 'Body'),
              ),
            ),
        ],
      ),
    );
    if (diagram == null || !mounted) return;
    final sid = await context.guard(
      () => context.repo.createSession(
        pid,
        procedure:
            procedures.firstWhere(
                  (p) => p['procedure_id'] == data['procedure'],
                )['name_ar']
                as String,
        category:
            procedures.firstWhere(
                  (p) => p['procedure_id'] == data['procedure'],
                )['category']
                as String,
        procedureId: data['procedure'],
        performedAt: DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
        notes: data['notes'] ?? '',
        diagram: diagram,
      ),
    );
    if (sid != null && mounted) setState(() => selected = sid);
  }

  Future<void> charge(DbRow session) async {
    final repo = context.repo;
    final fx = await WorkspaceRepository(repo).fx(),
        rows = await repo.db.query(
          'charges',
          where: 'session_id=?',
          whereArgs: [session['session_id']],
        );
    if (!mounted) return;
    final data = await formDialog(
      context,
      context.tr('أتعاب الجلسة', 'Session fees'),
      {'amount': '${context.tr('المبلغ', 'Amount')} (${fx.base})'},
      previews: {'amount': (v) => fx.dual(fx.parseInput(v))},
      initial: {
        'amount': rows.isEmpty
            ? ''
            : fx.input(rows.first['amount_minor'] as int),
      },
    );
    if (data == null || !mounted) return;
    await context.guard(
      () => context.repo.setCharge(
        session['session_id'] as String,
        session['revision'] as int,
        fx.parseInput(data['amount']!),
        '${session['procedure_name']}',
      ),
    );
  }

  Future<void> pay() async {
    final repo = context.repo;
    final outstanding = await repo.outstanding(pid),
        fx = await WorkspaceRepository(repo).fx();
    if (!mounted) return;
    final fields = <String, String>{
      'total':
          '${context.tr('المبلغ المقبوض كاملاً', 'Total received')} (${fx.base})',
      'notes': context.tr('ملاحظة', 'Notes'),
      for (final c in outstanding.where((c) => (c['due_minor'] as int) > 0))
        c['charge_id'] as String:
            '${c['procedure_name']} · ${context.tr('المتبقي', 'Due')}: ${fx.input(c['due_minor'] as int)}',
    };
    final data = await formDialog(
      context,
      context.tr('دفعة وتوزيعها', 'Receipt and allocation'),
      fields,
      optional: fields.keys.where((k) => k != 'total').toSet(),
      previews: {
        for (final k in fields.keys.where((k) => k != 'notes'))
          k: (v) => fx.dual(fx.parseInput(v)),
      },
    );
    if (data == null || !mounted) return;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    await context.guard(
      () => context.repo.recordPayment(
        pid,
        fx.parseInput(data['total']!),
        DateTime(date.year, date.month, date.day, 12),
        data['notes'] ?? '',
        {
          for (final c in outstanding)
            if ((data[c['charge_id']] ?? '').isNotEmpty)
              c['charge_id'] as String: fx.parseInput(data[c['charge_id']]!),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ClinicController>();
    final p = widget.patient;
    final details = [
      if ('${p['age'] ?? ''}'.isNotEmpty)
        context.tr('${p['age']} سنة', 'Age ${p['age']}'),
      if ('${p['phone'] ?? ''}'.isNotEmpty) '${p['phone']}',
    ].join(' · ');
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${p['name']}', style: tjw(19, FontWeight.w800)),
          actions: [
            IconButton(
              tooltip: context.tr('أرشفة المريض', 'Archive patient'),
              icon: const Icon(Icons.archive_outlined),
              onPressed: () async {
                if (!await confirmDialog(
                  context,
                  context.tr('أرشفة هذا المريض؟', 'Archive this patient?'),
                )) {
                  return;
                }
                if (!context.mounted) return;
                await context.guard(
                  () => WorkspaceRepository(
                    context.repo,
                  ).archive('patients', 'patient_id', pid),
                );
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  PersonAvatar('${p['name']}', size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p['name']}',
                          style: tjw(19, FontWeight.w800),
                        ),
                        if (details.isNotEmpty)
                          Text(
                            details,
                            style: tjw(13.5, FontWeight.w400, color: Tk.inkSoft),
                          ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: newSession,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(context.tr('جلسة', 'Session')),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: MedicalAlert(p),
            ),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: context.tr('الجلسات', 'Sessions')),
                Tab(text: context.tr('خريطة الحقن', 'Injection map')),
                Tab(text: context.tr('الصور', 'Photos')),
                Tab(text: context.tr('الموافقات', 'Consents')),
                Tab(text: context.tr('الدفعات', 'Payments')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  sessions(),
                  map(),
                  PatientAssets(patientId: pid, consents: false),
                  PatientAssets(patientId: pid, consents: true),
                  payments(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget sessions() => FutureBuilder<List<DbRow>>(
    future: context.repo.sessions(pid),
    builder: (c, s) {
      if (!s.hasData) return loadingError(s);
      if (s.data!.isEmpty) {
        return EmptyState(
          icon: Icons.medical_services_outlined,
          title: c.tr('لا جلسات بعد', 'No sessions yet'),
          message: c.tr(
            'ابدأ بجلسة جديدة لتسجيل الإجراء وخريطة الحقن والأتعاب.',
            'Start a session to record the procedure, injection map and fees.',
          ),
          action: FilledButton.icon(
            onPressed: newSession,
            icon: const Icon(Icons.add_rounded),
            label: Text(c.tr('جلسة جديدة', 'New session')),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [for (final row in s.data!) sessionCard(c, row)],
      );
    },
  );

  Widget sessionCard(BuildContext c, DbRow row) {
    final status = '${row['status']}';
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(c).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(
            '${row['procedure_name']}',
            style: tjw(16, FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusPill(status),
                Text(
                  clinicalDate(c, row['performed_at'] as String),
                  style: tjw(12.5, FontWeight.w400, color: Tk.inkSoft),
                ),
              ],
            ),
          ),
          children: [
            FutureBuilder(
              future: c.repo.box.open(
                row['notes'] as String,
                context: 'session:${row['session_id']}',
              ),
              builder: (c, n) {
                final text = '${n.data?['notes'] ?? ''}'.trim();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Tk.surfaceAlt,
                    borderRadius: BorderRadius.circular(Tk.rSm),
                  ),
                  child: Text(
                    text.isEmpty
                        ? c.tr('لا توجد ملاحظات', 'No notes')
                        : text,
                    style: tjw(
                      14,
                      FontWeight.w400,
                      color: text.isEmpty ? Tk.inkFaint : Tk.ink,
                      height: 1.5,
                    ),
                  ),
                );
              },
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => selected = row['session_id'] as String);
                    DefaultTabController.of(c).animateTo(1);
                  },
                  icon: const Icon(Icons.gesture_rounded, size: 18),
                  label: Text(c.tr('خريطة الحقن', 'Injection map')),
                ),
                if (status == 'draft') ...[
                  OutlinedButton.icon(
                    onPressed: () => charge(row),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: Text(c.tr('الأتعاب', 'Fees')),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => c.guard(
                      () => c.repo.finalize(
                        row['session_id'] as String,
                        row['revision'] as int,
                      ),
                    ),
                    icon: const Icon(Icons.lock_outline_rounded, size: 18),
                    label: Text(c.tr('اعتماد وقفل', 'Approve and lock')),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Tk.rose),
                    onPressed: () async {
                      final ok = await confirmDialog(
                        c,
                        c.tr(
                          'حذف المسودة ونقاطها؟',
                          'Delete draft and its points?',
                        ),
                      );
                      if (ok && c.mounted) {
                        await c.guard(
                          () => c.repo.deleteDraft(row['session_id'] as String),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(c.tr('حذف المسودة', 'Delete draft')),
                  ),
                ],
                if (['final', 'legacy'].contains(status))
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Tk.rose),
                    onPressed: () async {
                      final ok = await confirmDialog(
                        c,
                        c.tr(
                          'إلغاء الجلسة مع حفظ سجلها؟',
                          'Cancel session and keep its history?',
                        ),
                      );
                      if (ok && c.mounted) {
                        await c.guard(
                          () => c.repo.cancelSession(
                            row['session_id'] as String,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.block_rounded, size: 18),
                    label: Text(c.tr('إلغاء الجلسة', 'Cancel session')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget map() => FutureBuilder<List<DbRow>>(
    future: context.repo.sessions(pid),
    builder: (c, s) {
      if (!s.hasData) return loadingError(s);
      if (s.data!.isEmpty) {
        return Center(
          child: Text(context.tr('أنشئ جلسة أولاً', 'Create a session first')),
        );
      }
      final sid = s.data!.any((s) => s['session_id'] == selected)
          ? selected!
          : s.data!.first['session_id'] as String;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              initialValue: sid,
              isExpanded: true,
              items: s.data!
                  .map(
                    (s) => DropdownMenuItem(
                      value: s['session_id'] as String,
                      child: Text(
                        '${s['procedure_name']} · ${safeDate(c, '${s['performed_at']}')}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => selected = v),
            ),
          ),
          Expanded(
            child: InjectionMapPage(key: ValueKey(sid), sessionId: sid),
          ),
        ],
      );
    },
  );
  Widget payments() => FutureBuilder<List<dynamic>>(
    future: Future.wait([
      context.repo.payments(pid),
      context.repo.outstanding(pid),
      WorkspaceRepository(context.repo).fx(),
    ]),
    builder: (c, s) {
      if (!s.hasData) return loadingError(s);
      final payments = s.data![0] as List<DbRow>,
          charges = s.data![1] as List<DbRow>,
          fx = s.data![2] as Fx;
      String fmt(int v) => fx.dual(v);
      final due = charges.fold(0, (a, c) => a + (c['due_minor'] as int));
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          moneyCard(
            c.tr('الأتعاب', 'Fees'),
            fmt(charges.fold(0, (a, c) => a + (c['amount_minor'] as int))),
          ),
          moneyCard(
            c.tr('المتبقي على الإجراءات', 'Due on procedures'),
            fmt(due),
            color: due > 0 ? Tk.rose : Tk.sage,
          ),
          FilledButton.icon(
            onPressed: pay,
            icon: const Icon(Icons.add_card_rounded),
            label: Text(c.tr('تسجيل دفعة', 'Record payment')),
          ),
          SectionTitle(c.tr('سجل الدفعات', 'Payment history')),
          if (payments.isEmpty)
            GlassCard(
              flat: true,
              child: Text(
                c.tr('لا دفعات مسجلة.', 'No payments recorded.'),
                style: tjw(14, FontWeight.w400, color: Tk.inkSoft),
              ),
            ),
          for (final p in payments)
            GlassCard(
              flat: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fmt(p['amount_minor'] as int),
                          style: tjw(
                            15.5,
                            FontWeight.w800,
                            color: p['voided_at'] == null
                                ? Tk.ink
                                : Tk.inkFaint,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shortDate(c, '${p['paid_at']}'),
                          style: tjw(12.5, FontWeight.w400, color: Tk.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  p['voided_at'] != null
                      ? Pill(
                          c.tr('ملغاة', 'Voided'),
                          fg: Tk.rose,
                          bg: Tk.roseSoft,
                        )
                      : Pill(
                          c.tr('مقبوضة', 'Received'),
                          fg: Tk.sage,
                          bg: Tk.sageSoft,
                        ),
                  if (p['voided_at'] == null)
                    IconButton(
                      tooltip: c.tr('إلغاء الدفعة', 'Void payment'),
                      icon: const Icon(Icons.undo_rounded),
                      onPressed: () async {
                        final reason = await formDialog(
                          c,
                          c.tr('إلغاء دفعة', 'Void payment'),
                          {'reason': c.tr('سبب الإلغاء', 'Reason')},
                        );
                        if (reason != null && c.mounted) {
                          await c.guard(
                            () => c.repo.voidPayment(
                              p['payment_id'] as String,
                              reason['reason']!,
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
