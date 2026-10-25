import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../application/clinic_controller.dart';
import '../domain/models.dart';
import '../data/workspace_repository.dart';
import '../domain/fx.dart';
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
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.patient['name']}'),
          actions: [
            IconButton(
              tooltip: context.tr('أرشفة المريض', 'Archive patient'),
              icon: const Icon(Icons.archive_outlined),
              onPressed: () async {
                await context.guard(
                  () => WorkspaceRepository(
                    context.repo,
                  ).archive('patients', 'patient_id', pid),
                );
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: context.tr('الجلسات', 'Sessions')),
              Tab(text: context.tr('خريطة الحقن', 'Injection map')),
              Tab(text: context.tr('الصور', 'Photos')),
              Tab(text: context.tr('الموافقات', 'Consents')),
              Tab(text: context.tr('الدفعات', 'Payments')),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: MedicalAlert(widget.patient),
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
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: newSession,
            icon: const Icon(Icons.add),
            label: Text(context.tr('جلسة جديدة', 'New session')),
          ),
          const SizedBox(height: 12),
          for (final row in s.data!)
            Card(
              child: ExpansionTile(
                title: Text('${row['procedure_name']}'),
                subtitle: Text(
                  '${clinicalDate(c, row['performed_at'] as String)} · ${statusLabel(c, '${row['status']}')}',
                ),
                children: [
                  FutureBuilder(
                    future: context.repo.box.open(
                      row['notes'] as String,
                      context: 'session:${row['session_id']}',
                    ),
                    builder: (c, n) => Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('${n.data?['notes'] ?? ''}'),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => setState(
                          () => selected = row['session_id'] as String,
                        ),
                        child: Text(context.tr('اختيار للخريطة', 'Select map')),
                      ),
                      if (row['status'] == 'draft') ...[
                        OutlinedButton(
                          onPressed: () => charge(row),
                          child: Text(context.tr('الأتعاب', 'Fees')),
                        ),
                        FilledButton(
                          onPressed: () => context.guard(
                            () => context.repo.finalize(
                              row['session_id'] as String,
                              row['revision'] as int,
                            ),
                          ),
                          child: Text(
                            context.tr('اعتماد وقفل', 'Approve and lock'),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text(
                                  context.tr(
                                    'حذف المسودة ونقاطها؟',
                                    'Delete draft and its points?',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: Text(context.tr('إلغاء', 'Cancel')),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: Text(context.tr('حذف', 'Delete')),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true && mounted) {
                              await context.guard(
                                () => context.repo.deleteDraft(
                                  row['session_id'] as String,
                                ),
                              );
                            }
                          },
                          child: Text(
                            context.tr('حذف المسودة', 'Delete draft'),
                          ),
                        ),
                      ],
                      if (['final', 'legacy'].contains(row['status']))
                        TextButton(
                          onPressed: () => context.guard(
                            () => context.repo.cancelSession(
                              row['session_id'] as String,
                            ),
                          ),
                          child: Text(
                            context.tr(
                              'إلغاء الجلسة مع حفظ سجلها',
                              'Cancel while preserving history',
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
        ],
      );
    },
  );
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
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          moneyCard(
            context.tr('الأتعاب', 'Fees'),
            fmt(charges.fold(0, (a, c) => a + (c['amount_minor'] as int))),
          ),
          moneyCard(
            context.tr('المتبقي على الإجراءات', 'Due on procedures'),
            fmt(charges.fold(0, (a, c) => a + (c['due_minor'] as int))),
          ),
          FilledButton.icon(
            onPressed: pay,
            icon: const Icon(Icons.add_card),
            label: Text(context.tr('تسجيل دفعة', 'Record payment')),
          ),
          for (final p in payments)
            Card(
              child: ListTile(
                title: Text(fmt(p['amount_minor'] as int)),
                subtitle: Text(
                  '${shortDate(c, '${p['paid_at']}')} · ${p['voided_at'] == null ? context.tr('مقبوض', 'Received') : context.tr('ملغى', 'Voided')}',
                ),
                trailing: p['voided_at'] != null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.undo),
                        onPressed: () async {
                          final reason = await formDialog(
                            context,
                            context.tr('إلغاء دفعة', 'Void payment'),
                            {'reason': context.tr('سبب الإلغاء', 'Reason')},
                          );
                          if (reason != null && mounted) {
                            await context.guard(
                              () => context.repo.voidPayment(
                                p['payment_id'] as String,
                                reason['reason']!,
                              ),
                            );
                          }
                        },
                      ),
              ),
            ),
        ],
      );
    },
  );
}
