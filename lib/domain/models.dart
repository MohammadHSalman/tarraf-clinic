typedef DbRow = Map<String, Object?>;

class ReportFilter {
  final DateTime from, until;
  final String? procedure, category, procedureId, procedureLabel;
  final String paymentStatus; // all, paid, due
  ReportFilter({
    required this.from,
    required this.until,
    this.procedure,
    this.procedureId,
    this.procedureLabel,
    this.category,
    this.paymentStatus = 'all',
  }) {
    if (!until.isAfter(from)) throw ArgumentError('End must be after start');
  }
  // UTC ISO bounds, inclusive start, exclusive end.
  List<String> get bounds => [
    from.toUtc().toIso8601String(),
    until.toUtc().toIso8601String(),
  ];
}

class ReportResult {
  final List<DbRow> accrual, cash;
  final int unallocatedCashMinor;
  const ReportResult(this.accrual, this.cash, this.unallocatedCashMinor);
  int sum(List<DbRow> rows, String key) =>
      rows.fold(0, (a, r) => a + ((r[key] as int?) ?? 0));
  int get fees => sum(accrual, 'fees_minor');
  int get costs => sum(accrual, 'cost_minor');
  int get received => sum(cash, 'received_minor');
  int get unknownCosts => sum(accrual, 'unknown_costs');
}
