import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarraf_clinic/main.dart';
import 'package:tarraf_clinic/domain/models.dart';
import 'package:tarraf_clinic/domain/fx.dart';
import 'package:tarraf_clinic/presentation/common.dart';
import 'package:tarraf_clinic/presentation/luxury.dart';
import 'package:tarraf_clinic/presentation/report_charts.dart';

void main() {
  testWidgets(
    'narrow Arabic handset fits charts dual amounts and long medical alerts',
    (tester) async {
      final font = FontLoader('Tajawal')
        ..addFont(rootBundle.load('assets/Tajawal.ttf'));
      await font.load();
      final imageKey = GlobalKey();
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const fx = Fx('USD', 2, 'SYP', 12500000000);
      final report = ReportResult(
        [
          {
            'category': 'surgery',
            'performed_at': '2026-10-01T12:00:00Z',
            'due_minor': 100000,
          },
          {
            'category': 'injection',
            'performed_at': '2026-10-02T12:00:00Z',
            'due_minor': 50000,
          },
        ],
        [
          {'paid_at': '2026-10-03T12:00:00Z', 'received_minor': 100000},
        ],
        0,
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: imageKey,
          child: MaterialApp(
            theme: clinicTheme(),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const MedicalAlert({
                        'allergies': 'حساسية شديدة من اللاتكس والبنسلين',
                        'critical': 'يرجى مراجعة الأدوية السابقة',
                      }),
                      KpiCard(
                        'الأتعاب المستحقة',
                        fx.dual(12345678),
                        Icons.receipt_long,
                      ),
                      ProcedureDonut(report.accrual, arabic: true),
                      CashBars(report, fx.dual, arabic: true),
                      moneyCard('المتبقي', fx.dual(12345678)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('جراحة'));
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
      await tester.runAsync(() async {
        final boundary =
            imageKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/qa').create(recursive: true);
        await File(
          'build/qa/layout.png',
        ).writeAsBytes(data!.buffer.asUint8List());
      });
      expect(tester.takeException(), isNull);
    },
  );
}
