import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../application/clinic_controller.dart';
import '../data/report_repository.dart';
import '../domain/models.dart';
import '../domain/fx.dart';
import '../data/workspace_repository.dart';
import 'luxury.dart';
import 'report_charts.dart';
import '../services/report_pdf.dart';
import 'common.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTimeRange? range;
  String status = 'all';
  String? procedure, category, procedureId, procedureLabel;
  Future<List<dynamic>> load() async {
    final repo = context.repo;
    final now = DateTime.now(),
        from = range?.start ?? DateTime(now.year, now.month, 1),
        until = range == null
            ? DateTime(now.year, now.month + 1, 1)
            : DateTime(range!.end.year, range!.end.month, range!.end.day + 1);
    final filter = ReportFilter(
      from: from,
      until: until,
      procedure: procedure,
      procedureId: procedureId,
      procedureLabel: procedureLabel,
      category: category,
      paymentStatus: status,
    );
    return [
      await ReportRepository(repo).run(filter),
      filter,
      await repo.currency,
      await repo.digits,
      await repo.db.rawQuery(
        "SELECT procedure_id,name_ar procedure_name FROM procedures UNION SELECT DISTINCT NULL procedure_id,procedure_name FROM sessions WHERE procedure_id IS NULL AND status IN('final','legacy') ORDER BY procedure_name",
      ),
      await repo.db.rawQuery(
        "SELECT DISTINCT category FROM sessions WHERE status IN('final','legacy') ORDER BY category",
      ),
      await WorkspaceRepository(repo).fx(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ClinicController>();
    return FutureBuilder<List<dynamic>>(
      future: load(),
      builder: (c, s) {
        if (!s.hasData) return loadingError(s);
        final report = s.data![0] as ReportResult,
            filter = s.data![1] as ReportFilter,
            cur = s.data![2] as String,
            digits = s.data![3] as int,
            procedures = s.data![4] as List<DbRow>,
            categories = s.data![5] as List<DbRow>;
        final fx = s.data![6] as Fx;
        String fmt(int n) => fx.dual(n);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageIntro(
              context.tr('مؤشرات العيادة', 'Practice insights'),
              context.tr(
                'رؤية واضحة لأداء عيادتك',
                'A clear view of your practice',
              ),
              Icons.insights_outlined,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('التقارير المالية', 'Financial reports'),
                    style: Theme.of(c).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: () => context.guard(
                    () => ReportPdf.share(
                      report,
                      filter,
                      cur,
                      digits,
                      context.clinic.arabic,
                      fx: fx,
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () async {
                final r = await showDateRangePicker(
                  context: c,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (r != null) setState(() => range = r);
              },
              icon: const Icon(Icons.date_range),
              label: Text(
                '${filter.from.toLocal().toString().substring(0, 10)} — ${filter.until.toLocal().subtract(const Duration(days: 1)).toString().substring(0, 10)}',
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue:
                  procedureId ?? (procedure == null ? '' : 'legacy:$procedure'),
              decoration: InputDecoration(
                labelText: context.tr('الإجراء', 'Procedure'),
              ),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(context.tr('كل الإجراءات', 'All procedures')),
                ),
                for (final p in procedures)
                  DropdownMenuItem(
                    value:
                        p['procedure_id'] as String? ??
                        'legacy:${p['procedure_name']}',
                    child: Text('${p['procedure_name']}'),
                  ),
              ],
              onChanged: (v) => setState(() {
                procedure = null;
                procedureId = null;
                procedureLabel = null;
                if (v != null && v.isNotEmpty) {
                  if (v.startsWith('legacy:')) {
                    procedure = v.substring(7);
                    procedureLabel = procedure;
                  } else {
                    procedureId = v;
                    procedureLabel =
                        procedures.firstWhere(
                              (p) => p['procedure_id'] == v,
                            )['procedure_name']
                            as String;
                  }
                }
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category ?? '',
              decoration: InputDecoration(
                labelText: context.tr('نوع الإجراء', 'Procedure category'),
              ),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(context.tr('كل الأنواع', 'All categories')),
                ),
                for (final v in categories)
                  DropdownMenuItem(
                    value: v['category'] as String,
                    child: Text('${v['category']}'),
                  ),
              ],
              onChanged: (v) => setState(() => category = v == '' ? null : v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: InputDecoration(
                labelText: context.tr('حالة السداد', 'Payment status'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(context.tr('الكل', 'All')),
                ),
                DropdownMenuItem(
                  value: 'paid',
                  child: Text(context.tr('مسدد بالكامل', 'Fully paid')),
                ),
                DropdownMenuItem(
                  value: 'partial',
                  child: Text(context.tr('مسدد جزئياً', 'Partially paid')),
                ),
                DropdownMenuItem(
                  value: 'due',
                  child: Text(context.tr('غير مسدد', 'Unpaid')),
                ),
              ],
              onChanged: (v) => setState(() => status = v!),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('الاستحقاق • تاريخ الجلسة', 'Accrual • Session date'),
              style: Theme.of(c).textTheme.titleLarge,
            ),
            KpiCard(
              context.tr('الأتعاب المستحقة', 'Fees billed'),
              fmt(report.fees),
              Icons.receipt_long_outlined,
            ),
            KpiCard(
              context.tr('تكلفة المواد المعروفة', 'Known material cost'),
              fmt(report.costs),
              Icons.science_outlined,
            ),
            moneyCard(
              context.tr('هامش الأتعاب بعد المواد', 'Fees less materials'),
              report.unknownCosts > 0
                  ? context.tr('غير مكتمل', 'Incomplete')
                  : fmt(report.fees - report.costs),
            ),
            if (report.unknownCosts > 0)
              Text(
                context.tr(
                  'توجد تكاليف تاريخية غير مسجلة؛ لم تُحسب على أنها صفر.',
                  'Historical costs are missing; they were not treated as zero.',
                ),
              ),
            const SizedBox(height: 20),
            Text(
              context.tr(
                'التدفق النقدي • تاريخ الدفعة',
                'Cash flow • Payment date',
              ),
              style: Theme.of(c).textTheme.titleLarge,
            ),
            KpiCard(
              context.tr('المقبوضات المطابقة', 'Matching receipts'),
              fmt(report.received),
              Icons.account_balance_wallet_outlined,
            ),
            KpiCard(
              context.tr(
                'المتبقي عن جلسات الفترة',
                'Due on sessions in period',
              ),
              fmt(
                report.accrual.fold<int>(
                  0,
                  (a, r) => a + (r['due_minor'] as int),
                ),
              ),
              Icons.pending_actions,
            ),
            ProcedureDonut(report.accrual, arabic: context.clinic.arabic),
            CashBars(report, fmt, arabic: context.clinic.arabic),
            moneyCard(
              context.tr(
                'رصيد غير موزع خلال الفترة',
                'Unallocated receipts in period',
              ),
              fmt(report.unallocatedCashMinor),
            ),
            Text(
              context.tr(
                'مرشحات الإجراء والسداد تخص الأجزاء الموزعة من الدفعات. الرصيد غير الموزع يعرض مستقلاً لكل الفترة. حالة السداد حسب الوضع الحالي.',
                'Procedure and payment-status filters select allocated portions. Unallocated receipts are shown separately for the whole period. Payment status is current.',
              ),
            ),
          ],
        );
      },
    );
  }
}
