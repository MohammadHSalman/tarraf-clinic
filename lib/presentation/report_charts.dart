import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/models.dart';
import 'luxury.dart';

class ProcedureDonut extends StatefulWidget {
  final List<DbRow> rows;
  final bool arabic;
  const ProcedureDonut(this.rows, {super.key, required this.arabic});
  @override
  State<ProcedureDonut> createState() => _ProcedureDonutState();
}

class _ProcedureDonutState extends State<ProcedureDonut> {
  String? selected;
  @override
  Widget build(BuildContext c) {
    final groups = <String, int>{};
    for (final r in widget.rows) {
      final k = '${r['category']}';
      groups[k] = (groups[k] ?? 0) + 1;
    }
    final colors = [
      navy,
      const Color(0xff0D9488),
      silver,
      const Color(0xffD97706),
    ];
    String label(String k) => switch (k) {
      'surgery' => widget.arabic ? 'جراحة' : 'Surgery',
      'injection' => widget.arabic ? 'حقن' : 'Injection',
      'consultation' => widget.arabic ? 'استشارة' : 'Consultation',
      _ => k,
    };
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in groups.entries)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              tapFeedback();
              setState(() => selected = e.key);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color:
                        colors[groups.keys.toList().indexOf(e.key) %
                            colors.length],
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(label(e.key))),
                  Text(
                    '${e.value} · ${(100 * e.value / widget.rows.length).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    final ring = Semantics(
      label: widget.arabic
          ? 'مخطط توزيع الإجراءات'
          : 'Procedure distribution chart',
      child: GestureDetector(
        onTapUp: (e) {
          final p = e.localPosition - const Offset(80, 80);
          if (p.distance < 43 || p.distance > 80) return;
          var a = math.atan2(p.dy, p.dx) + math.pi / 2;
          if (a < 0) a += 2 * math.pi;
          var end = 0.0;
          for (final g in groups.entries) {
            end += g.value / widget.rows.length * 2 * math.pi;
            if (a <= end) {
              tapFeedback();
              setState(() => selected = g.key);
              break;
            }
          }
        },
        child: SizedBox(
          width: 160,
          height: 160,
          child: CustomPaint(
            painter: _Donut(
              groups.values.toList(),
              colors,
              groups.keys.toList().indexOf(selected ?? ''),
            ),
            child: Center(
              child: Text(
                selected != null && groups.containsKey(selected)
                    ? '${(100 * groups[selected]! / widget.rows.length).round()}%'
                    : '${widget.rows.length}',
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.arabic ? 'توزيع الإجراءات' : 'Procedure distribution',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                widget.arabic
                    ? 'لا جلسات معتمدة ضمن الفترة'
                    : 'No approved sessions in this period',
              ),
            )
          else
            LayoutBuilder(
              builder: (c, b) => Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 20,
                runSpacing: 20,
                children: [
                  ring,
                  SizedBox(width: math.min(190, b.maxWidth), child: legend),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Donut extends CustomPainter {
  final List<int> values;
  final List<Color> colors;
  final int selected;
  _Donut(this.values, this.colors, this.selected);
  @override
  void paint(Canvas c, Size s) {
    var a = -math.pi / 2;
    final total = values.fold(0, (a, b) => a + b);
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      final p = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = (i == selected ? 27 : 20);
      c.drawArc(
        Rect.fromCircle(center: s.center(Offset.zero), radius: 62),
        a + .025,
        math.max(0, sweep - .05),
        false,
        p,
      );
      a += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _Donut old) => true;
}

class CashBars extends StatefulWidget {
  final ReportResult report;
  final String Function(int) format;
  final bool arabic;
  const CashBars(this.report, this.format, {super.key, required this.arabic});
  @override
  State<CashBars> createState() => _CashBarsState();
}

class _CashBarsState extends State<CashBars> {
  String? selected;
  @override
  Widget build(BuildContext c) {
    final months = <String, List<int>>{};
    for (final r in widget.report.cash) {
      final k = DateTime.parse(
        r['paid_at'] as String,
      ).toLocal().toString().substring(0, 7);
      (months[k] ??= [0, 0])[0] += r['received_minor'] as int;
    }
    for (final r in widget.report.accrual) {
      final k = DateTime.parse(
        r['performed_at'] as String,
      ).toLocal().toString().substring(0, 7);
      (months[k] ??= [0, 0])[1] += r['due_minor'] as int;
    }
    final keys = months.keys.toList()..sort();
    final max = months.values.expand((x) => x).fold<int>(1, math.max);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.arabic
                ? 'المقبوض والمتبقي حسب الشهر'
                : 'Monthly receipts & outstanding',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            widget.arabic
                ? 'المقبوض بتاريخ الدفعة • المتبقي بتاريخ الجلسة'
                : 'Receipts by payment date • Due by session date',
            style: const TextStyle(fontSize: 11, color: Color(0xff64748B)),
          ),
          const SizedBox(height: 18),
          if (keys.isEmpty)
            Padding(
              padding: const EdgeInsets.all(22),
              child: Text(
                widget.arabic
                    ? 'لا بيانات ضمن الفترة'
                    : 'No data in this period',
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final k in keys)
                    Semantics(
                      button: true,
                      label:
                          '$k: ${widget.format(months[k]![0])} / ${widget.format(months[k]![1])}',
                      child: InkWell(
                        onTap: () {
                          tapFeedback();
                          setState(() => selected = k);
                        },
                        child: Container(
                          width: 76,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selected == k
                                ? const Color(0xffE2E8F0)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 130,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    for (var i = 0; i < 2; i++)
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 350,
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        height: months[k]![i] == 0
                                            ? 2
                                            : 120 * months[k]![i] / max,
                                        width: 18,
                                        decoration: BoxDecoration(
                                          color: i == 0 ? navy : silver,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(k, style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            children: [
              Text(
                '● ${widget.arabic ? 'مقبوض' : 'Received'}',
                style: const TextStyle(color: navy),
              ),
              Text(
                '● ${widget.arabic ? 'متبقي' : 'Outstanding'}',
                style: const TextStyle(color: silver),
              ),
            ],
          ),
          if (selected != null && months.containsKey(selected))
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                '$selected\n${widget.arabic ? 'مقبوض' : 'Received'}: ${widget.format(months[selected]![0])}\n${widget.arabic ? 'متبقي' : 'Due'}: ${widget.format(months[selected]![1])}',
              ),
            ),
        ],
      ),
    );
  }
}

class KpiCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  const KpiCard(this.title, this.value, this.icon, {super.key});
  @override
  Widget build(BuildContext c) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 22, color: navy),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Color(0xff64748B)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
        ),
      ],
    ),
  );
}
