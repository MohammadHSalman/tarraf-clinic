import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../application/clinic_controller.dart';
import '../data/clinic_repository.dart';

extension ClinicContext on BuildContext {
  ClinicController get clinic => read<ClinicController>();
  ClinicRepository get repo => clinic.repository;
  String tr(String ar, String en) => clinic.tr(ar, en);
  Future<T?> guard<T>(Future<T> Function() work) async {
    try {
      return await clinic.mutate(work);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(this).showSnackBar(SnackBar(content: Text('$e')));
      }
      return null;
    }
  }
}

Future<Map<String, String>?> formDialog(
  BuildContext context,
  String title,
  Map<String, String> fields, {
  Map<String, String> initial = const {},
  Set<String> optional = const {},
  Map<String, Map<String, String>> choices = const {},
  Map<String, String Function(String)> previews = const {},
}) async {
  final cs = {
    for (final k in fields.keys)
      k: TextEditingController(text: initial[k] ?? ''),
  };
  for (final e in choices.entries) {
    if (!e.value.containsKey(cs[e.key]?.text) &&
        !optional.contains(e.key) &&
        e.value.isNotEmpty) {
      cs[e.key]?.text = e.value.keys.first;
    }
  }
  final form = GlobalKey<FormState>();
  final result = await showDialog<Map<String, String>>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setDialog) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in fields.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: choices.containsKey(e.key)
                          ? DropdownButtonFormField<String>(
                              initialValue:
                                  choices[e.key]!.containsKey(initial[e.key])
                                  ? initial[e.key]
                                  : (optional.contains(e.key)
                                        ? null
                                        : choices[e.key]!.keys.first),
                              isExpanded: true,
                              decoration: InputDecoration(labelText: e.value),
                              items: [
                                for (final o in choices[e.key]!.entries)
                                  DropdownMenuItem(
                                    value: o.key,
                                    child: Text(
                                      o.value,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) {
                                cs[e.key]!.text = v ?? '';
                                HapticFeedback.selectionClick();
                              },
                              validator: (v) =>
                                  !optional.contains(e.key) && v == null
                                  ? 'مطلوب / Required'
                                  : null,
                            )
                          : TextFormField(
                              controller: cs[e.key],
                              onChanged: previews.containsKey(e.key)
                                  ? (_) => setDialog(() {})
                                  : null,
                              keyboardType:
                                  previews.containsKey(e.key) ||
                                      ["stock", "rate", "age"].contains(e.key)
                                  ? const TextInputType.numberWithOptions(
                                      decimal: true,
                                    )
                                  : TextInputType.text,
                              obscureText: e.key == 'password',
                              maxLines: e.key == 'notes' || e.key == 'body'
                                  ? 4
                                  : 1,
                              decoration: InputDecoration(
                                labelText: e.value,
                                helperMaxLines: 3,
                                helperText: _preview(
                                  previews[e.key],
                                  cs[e.key]!.text,
                                ),
                              ),
                              validator: (v) =>
                                  !optional.contains(e.key) &&
                                      (v ?? '').trim().isEmpty
                                  ? 'مطلوب / Required'
                                  : null,
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(context.tr('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(c, {
                  for (final e in cs.entries) e.key: e.value.text.trim(),
                });
              }
            },
            child: Text(context.tr('حفظ', 'Save')),
          ),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  for (final c in cs.values) {
    c.dispose();
  }
  return result;
}

Widget moneyCard(String title, String value, {Color? color}) => Card(
  child: Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  ),
);
Widget loadingError(AsyncSnapshot<dynamic> s) {
  if (s.hasError) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('${s.error}'),
      ),
    );
  }
  return const Center(child: CircularProgressIndicator());
}

String? _preview(String Function(String)? fn, String text) {
  try {
    return fn?.call(text);
  } catch (_) {
    return null;
  }
}

String clinicalDate(BuildContext c, String iso) {
  final at = DateTime.parse(iso).toLocal();
  return "${MaterialLocalizations.of(c).formatMediumDate(at)} · ${TimeOfDay.fromDateTime(at).format(c)}";
}
