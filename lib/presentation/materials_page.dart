import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../application/clinic_controller.dart';
import '../data/workspace_repository.dart';
import '../domain/models.dart';
import '../domain/fx.dart';
import '../domain/money.dart';
import 'common.dart';
import 'luxury.dart';

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({super.key});
  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  Future<void> edit([DbRow? m]) async {
    final w = WorkspaceRepository(context.repo);
    final fx = await w.fx();
    if (!mounted) return;
    final d = await formDialog(
      context,
      context.tr('إدارة المادة والمخزون', 'Material & inventory'),
      {
        'ar': context.tr('الاسم بالعربي', 'Arabic name'),
        'en': 'English name',
        'unit': context.tr('الوحدة القياسية', 'Standard unit'),
        'stock': context.tr(
          'المتوفر الفعلي بالمخزون',
          'Physical stock available',
        ),
        'cost': '${context.tr('كلفة الوحدة', 'Unit cost')} (${fx.base})',
      },
      initial: {
        'ar': '${m?['name_ar'] ?? ''}',
        'en': '${m?['name_en'] ?? ''}',
        'unit': '${m?['unit'] ?? 'CC'}',
        'stock': Money.format(m?['stock_milli'] as int? ?? 0, 3),
        'cost': m == null || m['cost_known'] == 0
            ? ''
            : fx.input(m['unit_cost_minor'] as int),
      },
      previews: {'cost': (v) => fx.dual(fx.parseInput(v))},
      choices: {
        'unit': {
          'Unit': 'Unit',
          'CC': 'CC',
          'Syringe': 'Syringe',
          'Vial': 'Vial',
          'Box': 'Box',
        },
      },
    );
    if (d != null && mounted) {
      await context.guard(
        () => w.saveMaterial(
          old: m,
          ar: d['ar']!,
          en: d['en']!,
          unit: d['unit']!,
          cost: fx.parseInput(d['cost']!),
          stock: Money.parse(d['stock']!, 3),
          fx: fx,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext c) {
    c.watch<ClinicController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(c.tr('المواد والمخزون', 'Materials & inventory')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: edit,
        icon: const Icon(Icons.add),
        label: Text(c.tr('مادة جديدة', 'New material')),
      ),
      body: FutureBuilder(
        future: Future.wait([
          WorkspaceRepository(c.repo).inventory(),
          WorkspaceRepository(c.repo).fx(),
        ]),
        builder: (c, s) {
          if (!s.hasData) return loadingError(s);
          final rows = s.data![0] as List<DbRow>, fx = s.data![1] as Fx;
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 100),
            children: [
              PageIntro(
                c.tr('دليل العناية', 'Care inventory'),
                c.tr(
                  'مواد دقيقة · تكلفة واضحة',
                  'Precise materials · Clear costs',
                ),
                Icons.science_outlined,
              ),
              for (final m in rows)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.science_outlined, color: navy),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${m[c.clinic.arabic && '${m['name_ar']}'.isNotEmpty ? 'name_ar' : 'name_en']}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: c.tr('تعديل', 'Edit'),
                            onPressed: () => edit(m),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: Icon(
                              Icons.inventory_2_outlined,
                              color: m['stock_milli'] == 0 ? coral : navy,
                              size: 18,
                            ),
                            label: Text(
                              '${Money.format(m['stock_milli'] as int, 3)} ${m['unit']}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              m['cost_known'] == 0
                                  ? c.tr('أدخل التكلفة', 'Set cost')
                                  : fx.dual(m['unit_cost_minor'] as int),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed: () => c.guard(
                            () => WorkspaceRepository(c.repo).archive(
                              'materials',
                              'material_id',
                              m['material_id'] as String,
                            ),
                          ),
                          icon: const Icon(Icons.archive_outlined, size: 18),
                          label: Text(c.tr('أرشفة المادة', 'Archive material')),
                        ),
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
