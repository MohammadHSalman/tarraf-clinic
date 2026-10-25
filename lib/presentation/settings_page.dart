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
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'luxury.dart';

class SettingsPage extends StatelessWidget {
  final Reminders reminders;
  const SettingsPage({super.key, required this.reminders});
  @override
  Widget build(BuildContext c) {
    final controller = c.watch<ClinicController>();
    final repo = controller.repository;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        GlassCard(
          flat: true,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset('assets/brand_icon.png', height: 64),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.tr('د. أحمد طراف', 'Dr. Ahmad Tarraf'),
                      style: tjw(18, FontWeight.w800),
                    ),
                    Text(
                      c.tr('جراحة تجميلية', 'Plastic Surgeon'),
                      style: tjw(13, FontWeight.w600, color: Tk.goldDeep),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionTitle(c.tr('العيادة', 'Clinic')),
        GlassCard(
          flat: true,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
            ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: Text(c.tr('العملات وسعر الصرف', 'Currencies & rate')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const CurrencyPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: Text(c.tr('أنواع الإجراءات', 'Procedure directory')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const ProceduresPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: Text(c.tr('دليل مواد الحقن', 'Injection material catalog')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const MaterialsPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: Text(
                c.tr('التعليمات والموافقات', 'Instructions and consents'),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const TemplatesPage()),
              ),
            ),
            ],
          ),
        ),
        SectionTitle(c.tr('الأمان والتنبيهات', 'Security & alerts')),
        GlassCard(
          flat: true,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
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
            ],
          ),
        ),
        SectionTitle(c.tr('البيانات والنسخ الاحتياطي', 'Data & backup')),
        GlassCard(
          flat: true,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
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
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(c.tr('السجلات المؤرشفة', 'Archived records')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const ArchivesPage()),
              ),
            ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(child: Text('0.5.0', style: tjw(12, FontWeight.w500, color: Tk.inkFaint))),
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
          if (s.data!.isEmpty) {
            return EmptyState(
              icon: Icons.article_outlined,
              title: c.tr('لا نماذج بعد', 'No templates yet'),
              message: c.tr(
                'أضف تعليمات ما بعد الإجراء أو نماذج الموافقة.',
                'Add post-procedure instructions or consent forms.',
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              for (final r in s.data!)
                GlassCard(
                  flat: true,
                  padding: EdgeInsets.zero,
                  child: ListTile(
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
                ),
            ],
          );
        },
      ),
    );
  }
}
