import 'package:flutter/material.dart';
import 'presentation/luxury.dart';
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
import 'services/appointment_scheduler.dart';

ThemeData clinicTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Tajawal',
  scaffoldBackgroundColor: const Color(0xffF8FAFC),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xff1E293B),
    primary: const Color(0xff1E293B),
    secondary: const Color(0xff94A3B8),
  ),
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white.withValues(alpha: .94),
    indicatorColor: const Color(0xffE2E8F0),
    height: 76,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xffF8FAFC),
    surfaceTintColor: Colors.transparent,
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shadowColor: const Color(0x151E293B),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: const BorderSide(color: Color(0xffCBD5E1)),
    ),
  ),
);
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
  Future<void> addPatient() async {
    final data = await formDialog(
      context,
      context.tr('ملف مريض جديد', 'New patient'),
      {
        'name': context.tr('الاسم', 'Name'),
        'age': context.tr('العمر', 'Age'),
        'phone': context.tr('الهاتف', 'Phone'),
        'allergies': context.tr('الحساسية', 'Allergies'),
        'critical': context.tr('ملاحظات حرجة', 'Critical notes'),
      },
      optional: {'age', 'phone', 'allergies', 'critical'},
    );
    if (data != null && mounted) {
      await context.guard(() => context.repo.addPatient(data));
    }
  }

  Future<void> editPatient(Map<String, dynamic> patient) async {
    final fields = {
      'name': context.tr('الاسم', 'Name'),
      'age': context.tr('العمر', 'Age'),
      'phone': context.tr('الهاتف', 'Phone'),
      'allergies': context.tr('الحساسية', 'Allergies'),
      'critical': context.tr('ملاحظات حرجة', 'Critical notes'),
    };
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
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset('assets/brand_icon.png'),
          ),
        ),
        title: Text(
          c.tr('د. أحمد طراف', 'Dr. Ahmad Tarraf'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => c.guard(
              () => controller.preferences(arabic: !controller.arabic),
            ),
            child: Text(controller.arabic ? 'EN' : 'عربي'),
          ),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: [
          for (var i = 0; i < 4; i++)
            if (!visited.contains(i))
              const SizedBox.shrink()
            else
              switch (i) {
                0 => patients(),
                1 => CalendarPage(reminders: widget.reminders),
                2 => const ReportsPage(),
                _ => SettingsPage(reminders: widget.reminders),
              },
        ],
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              onPressed: addPatient,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(c.tr('مريض جديد', 'New patient')),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) {
          tapFeedback();
          setState(() {
            tab = v;
            visited.add(v);
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            label: c.tr('المرضى', 'Patients'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month),
            label: c.tr('المواعيد', 'Calendar'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart),
            label: c.tr('التقارير', 'Reports'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            label: c.tr('الإعدادات', 'Settings'),
          ),
        ],
      ),
    );
  }

  Widget backupBanner() {
    final last = context.clinic.lastBackup;
    final days = last == null ? 0 : DateTime.now().difference(last).inDays;
    return Card(
      color: const Color(0xffFEF3C7),
      child: ListTile(
        leading: const Icon(Icons.shield_outlined, color: Color(0xffB45309)),
        title: Text(
          last == null
              ? context.tr('لا توجد نسخة احتياطية بعد', 'No backup yet')
              : context.tr(
                  'مرّ $days يوماً على آخر نسخة احتياطية',
                  '$days days since your last backup',
                ),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xff92400E),
          ),
        ),
        subtitle: Text(
          context.tr(
            'البيانات موجودة على هذا الهاتف فقط. اضغط للانتقال إلى الإعدادات.',
            'Data lives only on this phone. Tap to open Settings.',
          ),
        ),
        onTap: () => setState(() {
          tab = 3;
          visited.add(3);
        }),
      ),
    );
  }

  Widget patients() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: PageIntro(
          context.tr('مساحة العناية', 'Care workspace'),
          context.tr('ملفاتك السريرية في لمحة', 'Your practice at a glance'),
          Icons.spa_outlined,
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: context.tr('الاسم أو الهاتف', 'Name or phone'),
          ),
          onChanged: (v) => setState(() => search = v),
        ),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16),
          child: FilterChip(
            label: Text(context.tr('تنبيهات طبية', 'Clinical alerts')),
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
            final rows = s.data!
                .where(
                  (p) =>
                      '${p['name']} ${p['phone']}'.toLowerCase().contains(
                        search.toLowerCase(),
                      ) &&
                      (!critical ||
                          '${p['allergies'] ?? ''}${p['critical'] ?? ''}'
                              .isNotEmpty),
                )
                .toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                if (context.clinic.needsBackup && s.data!.isNotEmpty)
                  backupBanner(),
                for (final p in rows)
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        MedicalAlert(p),
                        const SizedBox(height: 8),
                        ListTile(
                          onTap: () => Navigator.push(
                            c,
                            MaterialPageRoute(
                              builder: (_) => PatientPage(patient: p),
                            ),
                          ),
                          leading: CircleAvatar(
                            child: Text(initialOf('${p['name']}')),
                          ),
                          title: Text('${p['name']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${p['age'] ?? ''} · ${p['phone'] ?? ''}'),
                              Text(
                                '${p['visit_count']} ${context.tr('زيارات', 'visits')} · ${p['last_procedure'] ?? context.tr('ملف جديد', 'New file')}',
                                style: const TextStyle(
                                  color: Color(0xff64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            tooltip: context.tr('تعديل الملف', 'Edit patient'),
                            onPressed: () => editPatient(p),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );
}
