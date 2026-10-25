import '../domain/models.dart';
import 'clinic_repository.dart';

class ReportRepository {
  final ClinicRepository repository;
  ReportRepository(this.repository);

  /// Snapshot isolation: both reports and their allocation totals see one DB state.
  Future<ReportResult> run(ReportFilter f) => repository.db.transaction((
    t,
  ) async {
    const base = '''WITH charge_totals AS (
      SELECT session_id,SUM(amount_minor) fees_minor FROM charges GROUP BY session_id),
    allocated AS (SELECT c.session_id,SUM(a.allocated_amount_minor) paid_minor FROM payment_allocations a
      JOIN payments p ON p.payment_id=a.payment_id AND p.voided_at IS NULL JOIN charges c ON c.charge_id=a.charge_id GROUP BY c.session_id),
    material_totals AS (SELECT session_id,SUM(COALESCE(approved_cost_minor,0)) cost_minor,
      SUM(CASE WHEN approved_cost_minor IS NULL AND quantity>0 THEN 1 ELSE 0 END) unknown_costs FROM session_materials GROUP BY session_id),
    totals AS (SELECT s.*,COALESCE(c.fees_minor,0) fees_minor,COALESCE(a.paid_minor,0) paid_minor,
      COALESCE(m.cost_minor,0) cost_minor,COALESCE(m.unknown_costs,0)+s.cost_unresolved unknown_costs FROM sessions s
      LEFT JOIN charge_totals c ON c.session_id=s.session_id LEFT JOIN allocated a ON a.session_id=s.session_id
      LEFT JOIN material_totals m ON m.session_id=s.session_id WHERE s.status IN('final','legacy'))''';
    final status = f.paymentStatus == 'paid'
        ? 'AND paid_minor>=fees_minor'
        : f.paymentStatus == 'partial'
        ? 'AND paid_minor>0 AND paid_minor<fees_minor'
        : f.paymentStatus == 'due'
        ? 'AND paid_minor=0 AND fees_minor>0'
        : '';
    final proc =
        '${f.procedure == null ? '' : 'AND procedure_name=?'} ${f.category == null ? '' : 'AND category=?'} ${f.procedureId == null ? '' : 'AND procedure_id=?'}';
    final parameters = <Object?>[
      ...f.bounds,
      if (f.procedure != null) f.procedure,
      if (f.category != null) f.category,
      if (f.procedureId != null) f.procedureId,
    ];
    final accrual = await t.rawQuery(
      '''$base SELECT *,fees_minor-paid_minor due_minor FROM totals
      WHERE performed_at>=? AND performed_at<? $proc $status ORDER BY performed_at''',
      parameters,
    );
    // Filtered cash is ALLOCATED cash attributable to matching sessions, counted once
    // per allocation and grouped by payment. Session date does not restrict cash.
    final filtered =
        f.procedure != null ||
        f.procedureId != null ||
        f.category != null ||
        f.paymentStatus != 'all';
    final List<DbRow> cash;
    if (filtered) {
      cash = await t.rawQuery(
        '''$base SELECT p.payment_id,p.paid_at,p.patient_id,SUM(a.allocated_amount_minor) received_minor
        FROM payments p JOIN payment_allocations a ON a.payment_id=p.payment_id JOIN charges c ON c.charge_id=a.charge_id
        JOIN totals ON totals.session_id=c.session_id WHERE p.voided_at IS NULL AND p.paid_at>=? AND p.paid_at<? $proc $status
        GROUP BY p.payment_id,p.paid_at,p.patient_id ORDER BY p.paid_at''',
        parameters,
      );
    } else {
      cash = await t.rawQuery(
        'SELECT payment_id,patient_id,paid_at,amount_minor received_minor FROM payments WHERE voided_at IS NULL AND paid_at>=? AND paid_at<? ORDER BY paid_at',
        f.bounds,
      );
    }
    final unallocated =
        (await t.rawQuery(
              '''SELECT COALESCE(SUM(p.amount_minor-COALESCE((SELECT SUM(a.allocated_amount_minor)
      FROM payment_allocations a WHERE a.payment_id=p.payment_id),0)),0) total FROM payments p
      WHERE p.voided_at IS NULL AND p.paid_at>=? AND p.paid_at<?''',
              f.bounds,
            )).single['total']
            as int;
    return ReportResult(accrual, cash, unallocated);
  });
}
