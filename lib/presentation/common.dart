import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../application/clinic_controller.dart';
import '../data/clinic_repository.dart';
import '../ui/tokens.dart';

extension ClinicContext on BuildContext {
  ClinicController get clinic => read<ClinicController>();
  ClinicRepository get repo => clinic.repository;
  String tr(String ar, String en) => clinic.tr(ar, en);
  Future<T?> guard<T>(Future<T> Function() work) async {
    try {
      return await clinic.mutate(work);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          this,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
  TextInputType keyboardFor(String key) {
    if (previews.containsKey(key) || ['stock', 'rate'].contains(key)) {
      return const TextInputType.numberWithOptions(decimal: true);
    }
    if (key == 'age') return TextInputType.number;
    if (key == 'phone') return TextInputType.phone;
    return TextInputType.text;
  }

  final result = await showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          0,
          22,
          MediaQuery.viewInsetsOf(c).bottom + 22,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(c).textTheme.titleLarge),
                const SizedBox(height: 18),
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
                                ? context.tr('مطلوب', 'Required')
                                : null,
                          )
                        : TextFormField(
                            controller: cs[e.key],
                            onChanged: previews.containsKey(e.key)
                                ? (_) => setSheet(() {})
                                : null,
                            keyboardType: keyboardFor(e.key),
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
                                ? context.tr('مطلوب', 'Required')
                                : null,
                          ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(c),
                        child: Text(context.tr('إلغاء', 'Cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {
                          if (form.currentState!.validate()) {
                            Navigator.pop(c, {
                              for (final e in cs.entries)
                                e.key: e.value.text.trim(),
                            });
                          }
                        },
                        child: Text(context.tr('حفظ', 'Save')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  for (final c in cs.values) {
    c.dispose();
  }
  return result;
}

Widget moneyCard(String title, String value, {Color? color}) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: Tk.surface,
    borderRadius: BorderRadius.circular(Tk.r),
    border: Border.all(color: Tk.line),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: tjw(13.5, FontWeight.w500, color: Tk.inkSoft)),
      const SizedBox(height: 8),
      Text(value, style: tjw(22, FontWeight.w800, color: color ?? Tk.ink)),
    ],
  ),
);
Widget loadingError(AsyncSnapshot<dynamic> s) {
  if (s.hasError) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(friendlyError(s.error!), textAlign: TextAlign.center),
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

/// Strips Dart exception prefixes so the doctor sees only the message.
String friendlyError(Object e) => '$e'.replaceFirst(
  RegExp(
    r'^(Exception|Bad state|Invalid argument\(s\)|FormatException|StateError|ArgumentError)\s*:?\s*',
  ),
  '',
);

/// Date only, localized; falls back to the raw text when unparsable.
String shortDate(BuildContext c, String raw) {
  try {
    return MaterialLocalizations.of(
      c,
    ).formatMediumDate(DateTime.parse(raw).toLocal());
  } catch (_) {
    return raw;
  }
}

/// Date and time, localized; falls back to the raw text when unparsable.
String safeDate(BuildContext c, String raw) {
  try {
    return clinicalDate(c, raw);
  } catch (_) {
    return raw;
  }
}

String statusLabel(BuildContext c, String status) => switch (status) {
  'draft' => c.tr('مسودة', 'Draft'),
  'final' => c.tr('معتمدة', 'Approved'),
  'legacy' => c.tr('قديمة', 'Legacy'),
  'cancelled' => c.tr('ملغاة', 'Cancelled'),
  _ => status,
};

String initialOf(String name) {
  final t = name.trim();
  return t.isEmpty ? '?' : String.fromCharCode(t.runes.first);
}

Future<bool> confirmDialog(BuildContext c, String title) async =>
    (await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(c.tr('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(c.tr('حذف', 'Delete')),
          ),
        ],
      ),
    )) ??
    false;
