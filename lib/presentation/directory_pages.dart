import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../application/clinic_controller.dart';
import '../data/workspace_repository.dart';
import '../domain/models.dart';
import '../domain/money.dart';
import 'common.dart';
import 'luxury.dart';

class CurrencyPage extends StatefulWidget {
  const CurrencyPage({super.key});
  @override
  State<CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<CurrencyPage> {
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(c.tr('العملات وسعر الصرف', 'Currency & exchange rate')),
    ),
    body: FutureBuilder(
      future: WorkspaceRepository(c.repo).fx(),
      builder: (c, s) {
        if (!s.hasData) return loadingError(s);
        final fx = s.data!;
        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            PageIntro(
              c.tr('إعداد مالي مركزي', 'Central finance'),
              c.tr(
                'كل المبالغ بالليرة والدولار',
                'USD & SYP across your workspace',
              ),
              Icons.currency_exchange,
            ),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c.tr('العملة الأساسية', 'Base currency')}: ${fx.base}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fx.rateMicros == 0
                        ? c.tr(
                            'حدد سعر الصرف للبدء بالتحويل',
                            'Set exchange rate to enable conversion',
                          )
                        : '1 USD = ${Money.format(fx.rateMicros, 6)} SYP',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    c.tr(
                      'المبالغ التاريخية محفوظة بعملة دفتر الحسابات. المقابل بالعملة الأخرى تقديري بالسعر الحالي.',
                      'Historical amounts retain their ledger currency. Dual values are indicative at the current rate.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    icon: const Icon(Icons.tune),
                    label: Text(c.tr('ضبط العملات', 'Configure currencies')),
                    onPressed: () async {
                      final d = await formDialog(
                        c,
                        c.tr('الإعدادات المالية', 'Financial settings'),
                        {
                          'base': c.tr('العملة الأساسية', 'Base currency'),
                          'rate': c.tr('ليرات سورية لكل دولار', 'SYP per USD'),
                        },
                        initial: {
                          'base': fx.base,
                          'rate': fx.rateMicros == 0
                              ? ''
                              : Money.format(fx.rateMicros, 6),
                        },
                        choices: {
                          'base': {
                            'USD': 'دولار أمريكي · USD',
                            'SYP': 'ليرة سورية · SYP',
                          },
                        },
                      );
                      if (d != null && c.mounted) {
                        await c.guard(
                          () => WorkspaceRepository(c.repo).financialSettings(
                            d['base']!,
                            Money.parse(d['rate']!, 6),
                          ),
                        );
                        if (mounted) setState(() {});
                      }
                    },
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

class ProceduresPage extends StatelessWidget {
  const ProceduresPage({super.key});
  Future<void> edit(BuildContext c, [DbRow? old]) async {
    final d = await formDialog(
      c,
      c.tr('دليل الإجراءات', 'Procedure directory'),
      {
        'ar': 'الاسم بالعربية',
        'en': 'English name',
        'category': c.tr('التصنيف', 'Category'),
      },
      initial: {
        'ar': '${old?['name_ar'] ?? ''}',
        'en': '${old?['name_en'] ?? ''}',
        'category': '${old?['category'] ?? 'injection'}',
      },
      choices: {
        'category': {
          'surgery': c.tr('جراحة', 'Surgery'),
          'consultation': c.tr('استشارة', 'Consultation'),
          'injection': c.tr('حقن', 'Injection'),
        },
      },
    );
    if (d != null && c.mounted) {
      await c.guard(
        () => WorkspaceRepository(c.repo).saveProcedure(
          d['ar']!,
          d['en']!,
          d['category']!,
          id: old?['procedure_id'] as String?,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext c) {
    c.watch<ClinicController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(c.tr('أنواع الإجراءات', 'Procedure directory')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => edit(c),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: WorkspaceRepository(c.repo).procedures(),
        builder: (c, s) {
          if (!s.hasData) return loadingError(s);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final p in s.data!)
                GlassCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${p[c.clinic.arabic ? 'name_ar' : 'name_en']}',
                    ),
                    subtitle: Text('${p['category']}'),
                    onTap: () => edit(c, p),
                    trailing: IconButton(
                      tooltip: c.tr('أرشفة', 'Archive'),
                      icon: const Icon(Icons.archive_outlined),
                      onPressed: () => c.guard(
                        () => WorkspaceRepository(c.repo).archive(
                          'procedures',
                          'procedure_id',
                          p['procedure_id'] as String,
                        ),
                      ),
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

class ArchivesPage extends StatelessWidget {
  const ArchivesPage({super.key});
  Future<List<DbRow>> rows(BuildContext c) async {
    final repo = c.repo, w = WorkspaceRepository(c.repo);
    return [
      for (final p in await repo.patients(archived: true))
        {...p, 'table': 'patients', 'key': 'patient_id', 'label': p['name']},
      for (final m in await repo.db.query(
        'materials',
        where: 'is_archived=1 AND is_hidden=0',
      ))
        {
          ...m,
          'table': 'materials',
          'key': 'material_id',
          'label': m['current_name'],
        },
      for (final p in await w.procedures(archived: true))
        {
          ...p,
          'table': 'procedures',
          'key': 'procedure_id',
          'label': p['name_ar'],
        },
    ];
  }

  @override
  Widget build(BuildContext c) {
    c.watch<ClinicController>();
    return Scaffold(
      appBar: AppBar(title: Text(c.tr('السجلات المؤرشفة', 'Archived records'))),
      body: FutureBuilder(
        future: rows(c),
        builder: (c, s) {
          if (!s.hasData) return loadingError(s);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                c.tr(
                  'الإخفاء النهائي يزيل السجل من هذه القائمة ويحفظ كل الروابط الطبية والمالية.',
                  'Permanent hiding removes the record from this list and preserves clinical and financial links.',
                ),
              ),
              const SizedBox(height: 16),
              if (s.data!.isEmpty)
                Center(
                  child: Text(c.tr('لا سجلات مؤرشفة', 'No archived records')),
                ),
              for (final r in s.data!)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r['label']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.unarchive_outlined),
                            label: Text(c.tr('استعادة', 'Restore')),
                            onPressed: () => c.guard(
                              () => WorkspaceRepository(c.repo).archive(
                                r['table'] as String,
                                r['key'] as String,
                                r[r['key']] as String,
                                restore: true,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.visibility_off_outlined),
                            label: Text(
                              c.tr('إخفاء نهائي', 'Permanently hide'),
                            ),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: c,
                                builder: (d) => AlertDialog(
                                  title: Text(
                                    c.tr(
                                      'إخفاء نهائي من القوائم؟',
                                      'Permanently hide from lists?',
                                    ),
                                  ),
                                  content: Text(
                                    c.tr(
                                      'سيبقى التاريخ الطبي والمالي محفوظاً.',
                                      'Clinical and financial history will be preserved.',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(d, false),
                                      child: Text(c.tr('إلغاء', 'Cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(d, true),
                                      child: Text(c.tr('إخفاء', 'Hide')),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true && c.mounted) {
                                await c.guard(
                                  () => WorkspaceRepository(c.repo).archive(
                                    r['table'] as String,
                                    r['key'] as String,
                                    r[r['key']] as String,
                                    hide: true,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
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
