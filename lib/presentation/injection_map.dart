import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../application/clinic_controller.dart';
import '../domain/models.dart';
import '../domain/money.dart';
import 'common.dart';

class InjectionMapPage extends StatefulWidget {
  final String sessionId;
  const InjectionMapPage({super.key, required this.sessionId});
  @override
  State<InjectionMapPage> createState() => _InjectionMapPageState();
}

class _InjectionMapPageState extends State<InjectionMapPage> {
  final transform = TransformationController();
  bool ghosts = false, busy = false;
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  Future<List<dynamic>> load() async => Future.wait([
    context.repo.session(widget.sessionId),
    context.repo.points(widget.sessionId),
    context.repo.history(widget.sessionId),
  ]);
  Future<void> editPoint(DbRow session, Offset p, {DbRow? existing}) async {
    if (session['status'] != 'draft' || busy) return;
    final all = await context.repo.materials();
    if (!mounted) return;
    if (existing != null &&
        !all.any((v) => v['version_id'] == existing['version_id'])) {
      all.add({
        'version_id': existing['version_id'],
        'name': existing['name'],
        'unit': existing['unit'],
        'material_id': existing['material_id'],
        'cost_known': 1,
      });
    }
    if (all.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('أضف مادة من الإعدادات', 'Add a material in Settings'),
          ),
        ),
      );
      return;
    }
    String selected =
        existing?['version_id'] as String? ?? all.first['version_id'] as String;
    final qty = TextEditingController(
      text: existing == null
          ? ''
          : Money.format(existing['units_or_cc'] as int, 3),
    );
    final lot = TextEditingController(
      text: existing?['lot_number'] as String? ?? '',
    );
    final form = GlobalKey<FormState>();
    String? error;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.viewInsetsOf(c).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('نقطة حقن', 'Injection point'),
                    style: Theme.of(c).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.tr(
                        'المادة • الإصدار',
                        'Material • Version',
                      ),
                    ),
                    items: all
                        .map(
                          (v) => DropdownMenuItem(
                            value: v['version_id'] as String,
                            child: Text(
                              '${context.clinic.arabic && (v['name_ar'] as String? ?? '').isNotEmpty ? v['name_ar'] : v['name']} · ${v['unit']} · ${v['stock_milli'] == null ? '' : Money.format(v['stock_milli'] as int, 3)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => set(() {
                      selected = v!;
                      lot.clear();
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: qty,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          '${context.tr('الكمية', 'Quantity')} (${all.firstWhere((v) => v['version_id'] == selected)['unit']})',
                    ),
                    validator: (v) {
                      try {
                        if (Money.parse(v ?? '', 3) <= 0) {
                          return 'أدخل كمية موجبة';
                        }
                        return null;
                      } catch (e) {
                        return '$e';
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: lot,
                    decoration: const InputDecoration(labelText: 'Batch / Lot'),
                  ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      if (form.currentState!.validate()) Navigator.pop(c, true);
                    },
                    child: Text(context.tr('حفظ النقطة', 'Save point')),
                  ),
                  if (existing != null)
                    TextButton(
                      onPressed: () async {
                        try {
                          await context.clinic.mutate(
                            () => context.repo.deletePoint(
                              existing['point_id'] as String,
                              widget.sessionId,
                              session['revision'] as int,
                            ),
                          );
                          if (c.mounted) Navigator.pop(c, false);
                        } catch (e) {
                          set(() => error = '$e');
                        }
                      },
                      child: Text(context.tr('حذف النقطة', 'Delete point')),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (accepted == true && mounted) {
      setState(() => busy = true);
      await context.guard(
        () => context.repo.savePoint(
          sessionId: widget.sessionId,
          revision: session['revision'] as int,
          pointId: existing?['point_id'] as String?,
          versionId: selected,
          batchId:
              existing != null &&
                  existing['version_id'] == selected &&
                  (existing['lot_number'] ?? '') == lot.text.trim()
              ? existing['batch_id'] as String?
              : null,
          lot: lot.text,
          milliQuantity: Money.parse(qty.text, 3),
          x: p.dx,
          y: p.dy,
        ),
      );
      if (mounted) setState(() => busy = false);
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    qty.dispose();
    lot.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ClinicController>();
    return FutureBuilder<List<dynamic>>(
      future: load(),
      builder: (c, s) {
        if (!s.hasData) return loadingError(s);
        final session = s.data![0] as DbRow,
            points = s.data![1] as List<DbRow>,
            history = s.data![2] as List<DbRow>;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('خريطة الجلسة', 'Session map'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => transform.value = Matrix4.identity(),
                  icon: const Icon(Icons.center_focus_strong),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.tr('إظهار الجلسات السابقة', 'Historical layer'),
              ),
              subtitle: Text(
                context.tr(
                  'نقاط باهتة • للعرض فقط',
                  'Ghosted points • Read only',
                ),
              ),
              value: ghosts,
              onChanged: (v) => setState(() => ghosts = v),
            ),
            if (session['status'] != 'draft')
              Text(
                context.tr(
                  'جلسة معتمدة — عرض تاريخي',
                  'Approved session — Historical view',
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 400 / 560,
                child: LayoutBuilder(
                  builder: (c, b) => InteractiveViewer(
                    transformationController: transform,
                    minScale: 1,
                    maxScale: 6,
                    child: GestureDetector(
                      onTapUp: (d) {
                        final p = Offset(
                          (d.localPosition.dx / b.maxWidth).clamp(0, 1),
                          (d.localPosition.dy / b.maxHeight).clamp(0, 1),
                        );
                        DbRow? hit;
                        var distance = .04;
                        for (final point in points) {
                          final current = sqrt(
                            pow(
                                  p.dx - (point['x_coord'] as num).toDouble(),
                                  2,
                                ) +
                                pow(
                                  p.dy - (point['y_coord'] as num).toDouble(),
                                  2,
                                ),
                          );
                          if (current < distance) {
                            distance = current;
                            hit = point;
                          }
                        }
                        editPoint(
                          session,
                          hit == null
                              ? p
                              : Offset(
                                  (hit['x_coord'] as num).toDouble(),
                                  (hit['y_coord'] as num).toDouble(),
                                ),
                          existing: hit,
                        );
                      },
                      child: SizedBox(
                        width: b.maxWidth,
                        height: b.maxHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            SvgPicture.asset(
                              'assets/anatomy/${session['diagram']}.svg',
                              fit: BoxFit.fill,
                            ),
                            CustomPaint(
                              painter: PointsPainter(
                                points,
                                ghosts ? history : [],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(
                'قرّب بإصبعين؛ اضغط لإضافة نقطة أو تعديلها',
                'Pinch to zoom; tap to add or edit',
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  for (final title in [
                    '#',
                    context.tr('المادة', 'Material'),
                    context.tr('الكمية', 'Quantity'),
                    'Batch / Lot',
                  ])
                    DataColumn(label: Text(title)),
                ],
                rows: [
                  for (var i = 0; i < points.length; i++)
                    DataRow(
                      cells: [
                        DataCell(Text('${i + 1}')),
                        DataCell(Text('${points[i]['name']}')),
                        DataCell(
                          Text(
                            '${Money.format(points[i]['units_or_cc'] as int, 3)} ${points[i]['unit']}',
                          ),
                        ),
                        DataCell(Text('${points[i]['lot_number'] ?? '—'}')),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class PointsPainter extends CustomPainter {
  final List<DbRow> points, ghosts;
  PointsPainter(this.points, this.ghosts);
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in ghosts) {
      final xy = Offset(
        (p['x_coord'] as num).toDouble() * size.width,
        (p['y_coord'] as num).toDouble() * size.height,
      );
      canvas.drawCircle(xy, 9, Paint()..color = const Color(0x2294A3B8));
      canvas.drawCircle(
        xy,
        9,
        Paint()
          ..color = const Color(0x7794A3B8)
          ..style = PaintingStyle.stroke,
      );
    }
    for (var i = 0; i < points.length; i++) {
      final p = points[i],
          xy = Offset(
            (p['x_coord'] as num).toDouble() * size.width,
            (p['y_coord'] as num).toDouble() * size.height,
          );
      canvas.drawCircle(xy, 12, Paint()..color = const Color(0xff1E293B));
      final text = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, xy - Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant PointsPainter old) => true;
}
