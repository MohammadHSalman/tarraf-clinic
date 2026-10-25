import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:provider/provider.dart';
import '../application/clinic_controller.dart';
import '../ui/clinical_widgets.dart' show CompareImages;
import 'common.dart';

class PatientAssets extends StatelessWidget {
  final String patientId;
  final bool consents;
  const PatientAssets({
    super.key,
    required this.patientId,
    required this.consents,
  });
  Future<void> photograph(
    BuildContext c,
    String role,
    ImageSource source,
  ) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 90,
    );
    if (file == null || !c.mounted) return;
    final bytes = await file.readAsBytes();
    if (!c.mounted) return;
    await c.clinic.mutate(
      () => c.repo.document('media', {
        'bytes': base64Encode(bytes),
        'role': role,
        'at': DateTime.now().toUtc().toIso8601String(),
      }, patient: patientId),
    );
    if (source == ImageSource.camera && await File(file.path).exists()) {
      await File(file.path).delete();
    }
  }

  Future<void> consent(BuildContext c) async {
    final templates = (await c.repo.documents(
      'templates',
    )).where((e) => e['type'] == 'consent').toList();
    if (!c.mounted) return;
    if (templates.isEmpty) throw StateError('أضف نموذج موافقة من الإعدادات');
    final chosen = await showDialog<Map<String, dynamic>>(
      context: c,
      builder: (d) => SimpleDialog(
        children: [
          for (final t in templates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(d, t),
              child: Text('${t['title']}'),
            ),
        ],
      ),
    );
    if (chosen == null || !c.mounted) return;
    final pen = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    final ok = await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        title: Text('${chosen['title']}'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${chosen['body']}'),
                Signature(
                  controller: pen,
                  height: 200,
                  backgroundColor: Colors.white,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: pen.clear, child: Text(c.tr('مسح', 'Clear'))),
          FilledButton(
            onPressed: () {
              if (pen.isNotEmpty) Navigator.pop(d, true);
            },
            child: Text(c.tr('حفظ', 'Save')),
          ),
        ],
      ),
    );
    if (ok == true) {
      final bytes = await pen.toPngBytes();
      if (bytes != null && c.mounted) {
        await c.clinic.mutate(
          () => c.repo.document('consents', {
            'title': chosen['title'],
            'text': chosen['body'],
            'signature': base64Encode(bytes),
            'at': DateTime.now().toUtc().toIso8601String(),
          }, patient: patientId),
        );
      }
    }
    pen.dispose();
  }

  @override
  Widget build(BuildContext c) {
    c.watch<ClinicController>();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: c.repo.documents(
        consents ? 'consents' : 'media',
        patient: patientId,
      ),
      builder: (c, s) {
        if (!s.hasData) return loadingError(s);
        final rows = s.data!,
            before = rows.where((r) => r['role'] == 'before').toList(),
            after = rows.where((r) => r['role'] == 'after').toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (consents)
              FilledButton(
                onPressed: () => c.guard(() => consent(c)),
                child: Text(c.tr('توقيع موافقة', 'Sign consent')),
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  for (final role in ['before', 'after'])
                    PopupMenuButton<ImageSource>(
                      onSelected: (source) =>
                          c.guard(() => photograph(c, role, source)),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: ImageSource.camera,
                          child: Text(c.tr('الكاميرا', 'Camera')),
                        ),
                        PopupMenuItem(
                          value: ImageSource.gallery,
                          child: Text(c.tr('الاستوديو', 'Gallery')),
                        ),
                      ],
                      child: Chip(
                        label: Text(
                          role == 'before'
                              ? c.tr('قبل', 'Before')
                              : c.tr('بعد', 'After'),
                        ),
                      ),
                    ),
                ],
              ),
            if (!consents && before.isNotEmpty && after.isNotEmpty)
              CompareImages(
                before: base64Decode(before.last['bytes'] as String),
                after: base64Decode(after.last['bytes'] as String),
              ),
            for (final r in rows)
              Card(
                child: ExpansionTile(
                  title: Text('${r['title'] ?? r['role']}'),
                  subtitle: Text('${r['at']}'),
                  children: [
                    if (consents)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('${r['text']}'),
                      ),
                    Image.memory(
                      base64Decode(
                        r[consents ? 'signature' : 'bytes'] as String,
                      ),
                      height: 240,
                      fit: BoxFit.contain,
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
