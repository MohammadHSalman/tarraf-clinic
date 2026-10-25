import 'package:flutter/material.dart';
import 'presentation/luxury.dart';
import 'ui/theme.dart';
import 'ui/tokens.dart';
import 'ui/widgets.dart';
import 'presentation/lock_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'application/clinic_controller.dart';
import 'core/reminders.dart';
import 'data/app_database.dart';
import 'data/legacy_migration.dart';
import 'presentation/calendar_page.dart';
import 'presentation/common.dart';
import 'presentation/patient_page.dart';
import 'presentation/reports_page.dart';
import 'presentation/settings_page.dart';
import 'presentation/today_page.dart';
import 'services/appointment_scheduler.dart';

export 'ui/theme.dart' show clinicTheme;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

class AppBundle {
  final ClinicController controller;
  final Reminders reminders;
  AppBundle(this.controller, this.reminders);
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<AppBundle> pending;
  final currency = TextEditingController(text: 'USD');
  String digits = '2';
  @override
  void initState() {
    super.initState();
    pending = open();
  }

  @override
  void dispose() {
    currency.dispose();
    super.dispose();
  }

  Future<AppBundle> open([MigrationOptions? options]) async {
    final repo = await AppDatabase.open(options: options),
        controller = ClinicController(repo),
        reminders = Reminders();
    await controller.loadPreferences();
    try {
      await reminders.init();
      await AppointmentScheduler.reconcile(repo, reminders);
    } catch (_) {
      /* Settings test can retry initialization. */
    }
    return AppBundle(controller, reminders);
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<AppBundle>(
    future: pending,
    builder: (c, s) {
      if (s.hasData) {
        return ChangeNotifierProvider.value(
          value: s.data!.controller,
          child: ClinicApp(reminders: s.data!.reminders),
        );
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: clinicTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/brand_icon.png',
                          height: 120,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!s.hasError)
                        const CircularProgressIndicator()
                      else if (s.error is NeedsConfiguration) ...[
                        const Text(
                          'إعداد العملة ودقة المبالغ',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          (s.error as NeedsConfiguration).hasLegacy
                              ? 'تم العثور على بيانات 0.1.1. اختر العملة التي استُخدمت فعلياً. سيبقى الملف السابق محفوظاً دون تغيير.'
                              : 'حدد عملة الحسابات وعدد المنازل العشرية قبل البدء.',
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          initialValue: currency.text,
                          decoration: const InputDecoration(
                            labelText: 'عملة البيانات الحالية',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'USD',
                              child: Text('دولار أمريكي · USD'),
                            ),
                            DropdownMenuItem(
                              value: 'SYP',
                              child: Text('ليرة سورية · SYP'),
                            ),
                          ],
                          onChanged: (v) => currency.text = v!,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: digits,
                          decoration: const InputDecoration(
                            labelText: 'عدد المنازل العشرية',
                          ),
                          items: [
                            for (var i = 0; i <= 6; i++)
                              DropdownMenuItem(value: '$i', child: Text('$i')),
                          ],
                          onChanged: (v) => digits = v!,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => setState(
                            () => pending = open(
                              MigrationOptions(
                                currency.text.trim().toUpperCase(),
                                int.parse(digits),
                              ),
                            ),
                          ),
                          child: const Text('تهيئة / ترحيل آمن'),
                        ),
                      ] else ...[
                        const Text(
                          'تعذر فتح البيانات. لم تُحذف الملفات السابقة.',
                        ),
                        const SizedBox(height: 12),
                        SelectableText('${s.error}'),
                        TextButton(
                          onPressed: () => setState(() => pending = open()),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ClinicApp extends StatefulWidget {
  final Reminders reminders;
  const ClinicApp({super.key, required this.reminders});
  @override
  State<ClinicApp> createState() => _ClinicAppState();
}

class _ClinicAppState extends State<ClinicApp> with WidgetsBindingObserver {
  bool locked = false, authenticating = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    locked = context.read<ClinicController>().biometric;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        !authenticating &&
        context.read<ClinicController>().biometric) {
      setState(() => locked = true);
    }
  }

  @override
  Widget build(BuildContext c) {
    final controller = c.watch<ClinicController>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(controller.arabic ? 'ar' : 'en'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: clinicTheme(),
      home: locked
          ? LockScreen(
              arabic: controller.arabic,
              onUnlocked: () {
                if (mounted) setState(() => locked = false);
              },
              onAuthStart: () => authenticating = true,
              onAuthEnd: () => authenticating = false,
            )
          : Home(reminders: widget.reminders),
    );
  }
}

class Home extends StatefulWidget {
  final Reminders reminders;
  const Home({super.key, required this.reminders});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  String search = '';
  bool critical = false;
  final visited = <int>{0};

  void go(int v) => setState(() {
    tab = v;
    visited.add(v);
  });

  static const _patientFields = {
    'name': ('الاسم', 'Name'),
    'age': ('العمر', 'Age'),
    'phone': ('الهاتف', 'Phone'),
    'allergies': ('الحساسية', 'Allergies'),
    'critical': ('ملاحظات حرجة', 'Critical notes'),
  };
  Map<String, String> fieldLabels() => {
    for (final e in _patientFields.entries)
      e.key: context.tr(e.value.$1, e.value.$2),
  };

  Future<void> addPatient() async {
    final data = await formDialog(
      context,
      context.tr('ملف مريض جديد', 'New patient'),
      fieldLabels(),
      optional: {'age', 'phone', 'allergies', 'critical'},
    );
    if (data != null && mounted) {
      await context.guard(() => context.repo.addPatient(data));
    }
  }

  Future<void> editPatient(Map<String, dynamic> patient) async {
    final fields = fieldLabels();
    final data = await formDialog(
      context,
      context.tr('تعديل ملف المريض', 'Edit patient'),
      fields,
      initial: {for (final key in fields.keys) key: '${patient[key] ?? ''}'},
      optional: {'age', 'phone', 'allergies', 'critical'},
    );
    if (data != null && mounted) {
      await context.guard(
        () => context.repo.editPatient(
          patient['patient_id'] as String,
          data,
          patient['revision'] as int,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext c) {
    final controller = c.watch<ClinicController>();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 16,
            top: 10,
            bottom: 10,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset('assets/brand_icon.png'),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              c.tr('د. أحمد طراف', 'Dr. Ahmad Tarraf'),
              style: tjw(19, FontWeight.w800),
            ),
            Text(
              c.tr('جراحة تجميلية', 'Plastic Surgery'),
              style: tjw(12.5, FontWeight.w600, color: Tk.goldDeep),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 14),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(52, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
              ),
              onPressed: () => c.guard(
                () => controller.preferences(arabic: !controller.arabic),
              ),
              child: Text(controller.arabic ? 'EN' : 'عربي'),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: [
          for (var i = 0; i < 5; i++)
            if (!visited.contains(i))
              const SizedBox.shrink()
            else
              switch (i) {
                0 => TodayPage(onGo: go, onAddPatient: addPatient),
                1 => patients(),
                2 => CalendarPage(reminders: widget.reminders),
                3 => const ReportsPage(),
                _ => SettingsPage(reminders: widget.reminders),
              },
        ],
      ),
      floatingActionButton: tab == 1
          ? FloatingActionButton.extended(
              onPressed: addPatient,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(c.tr('مريض جديد', 'New patient')),
            )
          : null,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Tk.line)),
        ),
        child: NavigationBar(
          selectedIndex: tab,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (v) {
            tapFeedback();
            go(v);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: c.tr('اليوم', 'Today'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline_rounded),
              selectedIcon: const Icon(Icons.people_alt_rounded),
              label: c.tr('المرضى', 'Patients'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month_rounded),
              label: c.tr('المواعيد', 'Calendar'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights_rounded),
              label: c.tr('التقارير', 'Reports'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune_outlined),
              selectedIcon: const Icon(Icons.tune_rounded),
              label: c.tr('الإعدادات', 'Settings'),
            ),
          ],
        ),
      ),
    );
  }

  bool hasAlert(Map<String, dynamic> p) =>
      '${p['allergies'] ?? ''}${p['critical'] ?? ''}'.trim().isNotEmpty;

  Widget patients() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: TextField(
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: context.tr('ابحث بالاسم أو الهاتف', 'Search name or phone'),
          ),
          onChanged: (v) => setState(() => search = v),
        ),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, top: 10),
          child: FilterChip(
            avatar: Icon(
              Icons.health_and_safety_outlined,
              size: 18,
              color: critical ? Tk.goldDeep : Tk.inkSoft,
            ),
            label: Text(context.tr('تنبيهات طبية فقط', 'Medical alerts only')),
            selected: critical,
            onSelected: (v) => setState(() => critical = v),
          ),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: context.clinic.patients(),
          builder: (c, s) {
            if (!s.hasData) return loadingError(s);
            final q = search.trim().toLowerCase();
            final rows =
                s.data!
                    .where(
                      (p) =>
                          '${p['name']} ${p['phone']}'.toLowerCase().contains(
                            q,
                          ) &&
                          (!critical || hasAlert(p)),
                    )
                    .toList()
                  ..sort((a, b) {
                    final x = '${b['last_visit'] ?? ''}',
                        y = '${a['last_visit'] ?? ''}';
                    final byVisit = x.compareTo(y);
                    return byVisit != 0
                        ? byVisit
                        : '${a['name']}'.compareTo('${b['name']}');
                  });
            if (s.data!.isEmpty) {
              return EmptyState(
                icon: Icons.person_add_alt_1_outlined,
                title: c.tr('ابدأ بإضافة أول مريض', 'Add your first patient'),
                message: c.tr(
                  'ستظهر هنا ملفاتهم وجلساتهم ودفعاتهم.',
                  'Their files, sessions and payments will appear here.',
                ),
                action: FilledButton.icon(
                  onPressed: addPatient,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(c.tr('مريض جديد', 'New patient')),
                ),
              );
            }
            if (rows.isEmpty) {
              return EmptyState(
                icon: Icons.search_off_rounded,
                title: c.tr('لا نتائج', 'No matches'),
                message: c.tr(
                  'جرّب اسماً أو رقماً آخر.',
                  'Try a different name or number.',
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Text(
                    c.tr('${rows.length} مريض', '${rows.length} patients'),
                    style: tjw(13, FontWeight.w600, color: Tk.inkSoft),
                  ),
                ),
                for (final p in rows) _patientCard(c, p),
              ],
            );
          },
        ),
      ),
    ],
  );

  Widget _patientCard(BuildContext c, Map<String, dynamic> p) {
    final details = [
      if ('${p['age'] ?? ''}'.isNotEmpty) '${p['age']}',
      if ('${p['phone'] ?? ''}'.isNotEmpty) '${p['phone']}',
    ].join(' · ');
    final visits = (p['visit_count'] as int?) ?? 0;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(
        c,
        MaterialPageRoute(builder: (_) => PatientPage(patient: p)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonAvatar('${p['name']}', size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p['name']}', style: tjw(16.5, FontWeight.w800)),
                if (details.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      details,
                      style: tjw(13, FontWeight.w400, color: Tk.inkSoft),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill(
                      visits == 0
                          ? c.tr('ملف جديد', 'New file')
                          : c.tr('$visits زيارات', '$visits visits'),
                      icon: Icons.event_available_outlined,
                    ),
                    if (p['last_procedure'] != null)
                      Pill(
                        '${p['last_procedure']}',
                        fg: Tk.goldDeep,
                        bg: Tk.goldSoft,
                      ),
                    if (hasAlert(p))
                      Pill(
                        c.tr('تنبيه طبي', 'Medical alert'),
                        fg: Tk.rose,
                        bg: Tk.roseSoft,
                        icon: Icons.health_and_safety_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: c.tr('تعديل الملف', 'Edit patient'),
            onPressed: () => editPatient(p),
            icon: const Icon(Icons.edit_outlined, size: 20, color: Tk.inkSoft),
          ),
        ],
      ),
    );
  }
}
