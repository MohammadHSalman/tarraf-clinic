import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/models.dart';
import '../domain/money.dart';
import '../domain/fx.dart';

class ReportPdf {
  static Future<Uint8List> build(
    ReportResult report,
    ReportFilter filter,
    String currency,
    int digits,
    bool arabic, {
    Fx? fx,
  }) async {
    final font = pw.Font.ttf(await rootBundle.load('assets/Arabic.ttf'));
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/brand_icon.png')).buffer.asUint8List(),
    );
    final pdf = pw.Document();
    String tr(String ar, String en) => arabic ? ar : en;
    String money(int v) =>
        fx?.dual(v) ?? '${Money.format(v, digits)} $currency';
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header: (_) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(logo, width: 52, height: 52),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      tr(
                        'د. أحمد طراف — جراح تجميل',
                        'Dr. Ahmad Tarraf — Plastic Surgeon',
                      ),
                      style: pw.TextStyle(fontSize: 18),
                    ),
                    pw.Text(tr('التقرير المالي', 'Financial report')),
                  ],
                ),
              ],
            ),
            pw.Divider(),
          ],
        ),
        footer: (c) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${c.pageNumber} / ${c.pagesCount}'),
            pw.Text(
              tr(
                'توقيع الطبيب: __________________',
                'Doctor signature: __________________',
              ),
            ),
          ],
        ),
        build: (_) => [
          pw.Text('${filter.from.toLocal()} — ${filter.until.toLocal()}'),
          if (fx != null && fx.rateMicros > 0)
            pw.Text(
              '1 USD = ${Money.format(fx.rateMicros, 6)} SYP · ${tr('تحويل تقديري بالسعر الحالي', 'Indicative conversion at current rate')}',
            ),
          pw.Text(
            '${tr('بداية شاملة، نهاية غير شاملة', 'Inclusive start, exclusive end')} · ${filter.procedureLabel ?? filter.procedure ?? tr('كل الإجراءات', 'All procedures')} · ${filter.category ?? tr('كل الأنواع', 'All categories')} · ${filter.paymentStatus == 'paid'
                ? tr('مسدد', 'Paid')
                : filter.paymentStatus == 'partial'
                ? tr('جزئي', 'Partial')
                : filter.paymentStatus == 'due'
                ? tr('متبقي', 'Due')
                : tr('الكل', 'All')}',
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            tr('الاستحقاق حسب تاريخ الجلسة', 'Accrual by session date'),
            style: pw.TextStyle(fontSize: 16),
          ),
          pw.Text('${tr('الأتعاب', 'Fees')}: ${money(report.fees)}'),
          pw.Text(
            '${tr('التكاليف المعروفة', 'Known costs')}: ${money(report.costs)}',
          ),
          pw.Text(
            report.unknownCosts > 0
                ? tr(
                    'الربح غير مكتمل: توجد تكاليف غير معروفة',
                    'Margin incomplete: unknown historical costs',
                  )
                : '${tr('هامش الأتعاب بعد المواد', 'Fees less material costs')}: ${money(report.fees - report.costs)}',
          ),
          pw.TableHelper.fromTextArray(
            headers: [
              tr('التاريخ', 'Date'),
              tr('الإجراء', 'Procedure'),
              tr('الأتعاب', 'Fees'),
              tr('المواد', 'Materials'),
              tr('المتبقي', 'Due'),
            ],
            data: [
              for (final r in report.accrual)
                [
                  '${r['performed_at']}'.substring(0, 10),
                  '${r['procedure_name']}',
                  money(r['fees_minor'] as int),
                  (r['unknown_costs'] as int) > 0
                      ? tr('غير مكتمل', 'Incomplete')
                      : money(r['cost_minor'] as int),
                  money(r['due_minor'] as int),
                ],
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            tr('التدفق النقدي حسب تاريخ الدفعة', 'Cash flow by payment date'),
            style: pw.TextStyle(fontSize: 16),
          ),
          pw.Text(
            '${tr('المقبوض ضمن المرشحات', 'Receipts within filters')}: ${money(report.received)}',
          ),
          pw.Text(
            '${tr('رصيد غير موزع خلال الفترة، خارج مرشحات الإجراء والسداد', 'Unallocated receipts in period, independent of procedure/payment-status filters')}: ${money(report.unallocatedCashMinor)}',
          ),
          pw.Text(
            tr(
              'مع مرشح إجراء أو حالة سداد، يعرض التدفق المبالغ الموزعة المطابقة فقط؛ العرض العام يحتسب الدفعة مرة واحدة كاملة.',
              'With procedure or payment-status filters, cash includes matching allocations only; unfiltered cash counts each full payment once.',
            ),
          ),
          pw.TableHelper.fromTextArray(
            headers: [
              tr('التاريخ', 'Date'),
              tr('الدفعة', 'Payment'),
              tr('المقبوض', 'Received'),
            ],
            data: [
              for (final r in report.cash)
                [
                  '${r['paid_at']}'.substring(0, 10),
                  '${r['payment_id']}'.substring(0, 8),
                  money(r['received_minor'] as int),
                ],
            ],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<void> share(
    ReportResult report,
    ReportFilter filter,
    String currency,
    int digits,
    bool arabic, {
    Fx? fx,
  }) async {
    await Printing.sharePdf(
      bytes: await build(report, filter, currency, digits, arabic, fx: fx),
      filename: 'Tarraf-Financial-Report.pdf',
    );
  }
}
