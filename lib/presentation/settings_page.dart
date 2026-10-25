import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../application/clinic_controller.dart';
import '../core/reminders.dart';
import '../services/backup_service.dart';
import 'common.dart';
import 'materials_page.dart';
import 'directory_pages.dart';
import 'luxury.dart';

class SettingsPage extends StatelessWidget {
  final Reminders reminders;
  const SettingsPage({super.key, required this.reminders});
  @override
  Widget build(BuildContext c) {
    final controller = c.watch<ClinicController>();
    final repo = controller.repository;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset('assets/brand_icon.png', height: 112),
          ),
        ),
        const SizedBox(height: 12),
        const Center(child: Text('Dr. Ahmad Tarraf · Plastic Surgeon')),
        PageIntro(
          c.tr('إعدادات العيادة', 'Clinic settings'),
          c.tr('تفاصيل مصممة لطريقتك', 'A workspace tailored to your practice'),
          Icons.tune,
        ),
        for (final e in <(IconData, String, String, Widget)>[
          (
            Icons.currency_exchange,
            'العملات وسعر الصرف',
            'Currencies & rate',
            const CurrencyPage(),
          ),
          (
            Icons.category_outlined,
            'أنواع الإجراءات',
            'Procedure directory',
            const ProceduresPage(),
          ),
          (
            Icons.inventory_2_outlined,
            'السجلات المؤرشفة',
            'Archived records',
            const ArchivesPage(),
          ),
        ])
          Card(
            child: ListTile(
              leading: Icon(e.$1),
              title: Text(c.tr(e.$2, e.$3)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.push(c, MaterialPageRoute(builder: (_) => e.$4)),
            ),
          ),
        ListTile(
          leading: const Icon(Icons.science_outlined),
          title: Text(c.tr('دليل مواد الحقن', 'Injection material catalog')),
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const MaterialsPage()),
          ),
        ),
        SwitchListTile(
          title: Text(c.tr('قفل البصمة / الوجه', 'Biometric lock')),
          value: c.clinic.biometric,
          onChanged: (value) => c.guard(() async {
            final ok = await LocalAuthentication().authenticate(
              localizedReason: c.tr(
                'تأكيد إعداد القفل',
                'Confirm lock setting',
              ),
              biometricOnly: false,
            );
            if (ok) await controller.preferences(biometric: value);
          }),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text(
            c.tr('اختبار إشعار بالشعار', 'Test branded notification'),
          ),
          onTap: () => c.guard(reminders.test),
        ),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: Text(c.tr('تصدير نسخة مشفرة', 'Export encrypted backup')),
          subtitle: Text(
            controller.lastBackup == null
                ? c.tr('لم تؤخذ نسخة بعد', 'No backup yet')
                : c.tr(
                    'آخر نسخة: ${MaterialLocalizations.of(c).formatMediumDate(controller.lastBackup!.toLocal())}',
                    'Last backup: ${MaterialLocalizations.of(c).formatMediumDate(controller.lastBackup!.toLocal())}',
                  ),
          ),
          onTap: () => c.guard(() async {
            final data = await formDialog(
              c,
              c.tr(
                'كلمة مرور النسخة • 12 محرفاً',
                'Backup password • 12 characters',
              ),
              {'password': c.tr('كلمة المرور', 'Password')},
            );
            if (data == null) return;
            final file = await BackupService(repo).export(data['password']!);
            final result = await SharePlus.instance.share(
              ShareParams(files: [XFile(file.path)]),
            );
            if (result.status != ShareResultStatus.dismissed) {
              await controller.markBackup();
            }
          }),
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: Text(
            c.tr(
              'استرجاع نسخة مشفرة واستبدال البيانات',
              'Restore encrypted backup and replace data',
            ),
          ),
          onTap: () => c.guard(() async {
            final selected = await FilePicker.platform.pickFiles();
            if (selected == null ||
                selected.files.single.path == null ||
                !c.mounted) {
              return;
            }
            final data = await formDialog(
              c,
              c.tr(
                'استبدال البيانات • سيُغلق التطبيق بعد النجاح',
                'Replace data • App closes after success',
              ),
              {'password': c.tr('كلمة مرور النسخة', 'Backup password')},
            );
            if (data == null) return;
            await BackupService(
              repo,
            ).restore(File(selected.files.single.path!), data['password']!);
            await reminders.cancelAll();
            await SystemNavigator.pop();
          }),
        ),
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: Text(
            c.tr('التعليمات والموافقات', 'Instructions and consents'),
          ),
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const TemplatesPage()),
          ),
        ),
        const SizedBox(height: 24),
        const Center(child: Text('0.4.0')),
      ],
    );
  }
}

class TemplatesPage extends StatelessWidget {
  const TemplatesPage({super.key});
  Future<void> edit(BuildContext c, [Map<String, dynamic>? old]) async {
    final repo = c.repo;
    final data = await formDialog(
      c,
      c.tr('نموذج', 'Template'),
      {
        'title': c.tr('العنوان', 'Title'),
        'type': c.tr('النوع', 'Type'),
        'body': c.tr('النص المعتمد', 'Approved text'),
      },
      choices: {
        'type': {
          'instructions': c.tr('تعليمات', 'Instructions'),
          'consent': c.tr('موافقة', 'Consent'),
        },
      },
      initial: old == null
          ? {'type': 'instructions'}
          : {
              'title': '${old['title']}',
              'type': '${old['type']}',
              'body': '${old['body']}',
            },
    );
    if (data != null && c.mounted) {
      await c.guard(() async {
        if (!['instructions', 'consent'].contains(data['type'])) {
          throw FormatException('instructions / consent');
        }
        await repo.document(
          'templates',
          data,
          documentId: old?['id'] as String?,
        );
      });
    }
  }

  @override
  Widget build(BuildContext c) {
    final controller = c.watch<ClinicController>();
    final repo = controller.repository;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.tr('التعليمات والموافقات', 'Instructions and consents')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => edit(c),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.documents('templates'),
        builder: (c, s) {
          if (!s.hasData) return loadingError(s);
          return ListView(
            children: [
              for (final r in s.data!)
                ListTile(
                  title: Text('${r['title']}'),
                  subtitle: Text(
                    r['type'] == 'consent'
                        ? c.tr('موافقة', 'Consent')
                        : c.tr('تعليمات', 'Instructions'),
                  ),
                  onTap: () => edit(c, r),
                  trailing: r['type'] != 'instructions'
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (mode) => c.guard(() async {
                            if (mode == 'text') {
                              await SharePlus.instance.share(
                                ShareParams(
                                  text: '${r['title']}\n${r['body']}',
                                ),
                              );
                            } else {
                              final font = pw.Font.ttf(
                                await rootBundle.load('assets/Arabic.ttf'),
                              );
                              final pdf = pw.Document();
                              pdf.addPage(
                                pw.MultiPage(
                                  textDirection: controller.arabic
                                      ? pw.TextDirection.rtl
                                      : pw.TextDirection.ltr,
                                  theme: pw.ThemeData.withFont(base: font),
                                  build: (_) => [
                                    pw.Text('Dr. Ahmad Tarraf'),
                                    pw.Header(text: '${r['title']}'),
                                    pw.Text('${r['body']}'),
                                  ],
                                ),
                              );
                              await Printing.sharePdf(
                                bytes: await pdf.save(),
                                filename: 'Tarraf-Care-Instructions.pdf',
                              );
                            }
                          }),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'text',
                              child: Text(c.tr('مشاركة نص', 'Share text')),
                            ),
                            const PopupMenuItem(
                              value: 'pdf',
                              child: Text('PDF'),
                            ),
                          ],
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}
